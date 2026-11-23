package repositories

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"gorm.io/gorm"
	"reflect"
	"sort"
	"strings"
	"time"
)

var ErrTransactionCloudRevision = errors.New("transaction revision conflict")
var ErrTransactionCloudPayment = errors.New("committed payment history cannot be changed by aggregate update")
var ErrTransactionCloudAudit = errors.New("process transition requires verified cloud actor provenance")

type TransactionCloudDelete struct {
	Domain           string `json:"domain,omitempty"`
	MutationID       string `json:"mutation_id"`
	UUID             string `json:"uuid"`
	ExpectedRevision int64  `json:"expected_revision"`
}

func (r *TransactionCloudRepository) Update(ctx context.Context, m TransactionCloudCreate, actor int64) (*TransactionCloudAck, error) {
	copy := m
	copy.ExpectedRevision = 0
	if actor < 1 || !r.validDomain(m.Domain) || m.ExpectedRevision < 1 || copy.validate() != nil {
		return nil, ErrTransactionCloudInvalid
	}
	return r.mutate(ctx, "update", m.MutationID, m.UUID, m.ExpectedRevision, actor, m, &m)
}
func (r *TransactionCloudRepository) Delete(ctx context.Context, m TransactionCloudDelete, actor int64) (*TransactionCloudAck, error) {
	if actor < 1 || !r.validDomain(m.Domain) || m.ExpectedRevision < 1 || !notarisCloudUUID.MatchString(m.MutationID) || !notarisCloudUUID.MatchString(m.UUID) {
		return nil, ErrTransactionCloudInvalid
	}
	return r.mutate(ctx, "delete", m.MutationID, m.UUID, m.ExpectedRevision, actor, m, nil)
}
func sameTransactionPayments(a, b []TransactionCloudPayment) bool {
	a = append([]TransactionCloudPayment{}, a...)
	b = append([]TransactionCloudPayment{}, b...)
	sort.Slice(a, func(i, j int) bool { return a[i].UUID < a[j].UUID })
	sort.Slice(b, func(i, j int) bool { return b[i].UUID < b[j].UUID })
	// time.Time may have different location objects after jsonb round trips.
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return string(x) == string(y)
}
func (r *TransactionCloudRepository) mutate(ctx context.Context, op, mutation, uuid string, expected, actor int64, request any, update *TransactionCloudCreate) (*TransactionCloudAck, error) {
	body, _ := json.Marshal(request)
	hash := sha256.Sum256(append([]byte(op+":"), body...))
	digest := hex.EncodeToString(hash[:])
	var ack TransactionCloudAck
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", "transaction-mutation:"+strings.ToLower(mutation)).Error; e != nil {
			return e
		}
		var receipt struct {
			ActorID         int64
			RequestHash     string
			Acknowledgement []byte
		}
		probe := tx.Raw("SELECT actor_id,request_hash,acknowledgement FROM transaction_cloud_mutation WHERE mutation_id=?::uuid", mutation).Scan(&receipt)
		if probe.Error != nil {
			return probe.Error
		}
		if probe.RowsAffected > 0 {
			if receipt.ActorID != actor || receipt.RequestHash != digest {
				return ErrTransactionCloudReuse
			}
			return json.Unmarshal(receipt.Acknowledgement, &ack)
		}
		var parent struct {
			ID, Revision int64
			FinalNumber  string
			DeletedAt    *time.Time
			Domain       string
		}
		locked := tx.Raw("SELECT id,revision,final_number,deleted_at,domain FROM transaction_cloud WHERE uuid=?::uuid FOR UPDATE", uuid).Scan(&parent)
		if locked.Error != nil {
			return locked.Error
		}
		if locked.RowsAffected != 1 || parent.Domain != r.domain || parent.DeletedAt != nil || parent.Revision != expected {
			return ErrTransactionCloudRevision
		}
		var saved []byte
		if e := tx.Raw("SELECT payload FROM transaction_cloud_outbox WHERE aggregate_uuid=?::uuid AND revision=?", uuid, expected).Row().Scan(&saved); e != nil {
			return e
		}
		var aggregate TransactionCloudAggregate
		if e := json.Unmarshal(saved, &aggregate); e != nil {
			return e
		}
		if update != nil {
			if !sameTransactionPayments(aggregate.Payments, update.Payments) {
				return ErrTransactionCloudPayment
			}
			refs := TransactionCloudReferences{PemohonUUID: update.PemohonUUID, PetugasUUID: update.PetugasUUID, Domain: r.domain}
			for _, d := range update.Details {
				refs.Jobs = append(refs.Jobs, TransactionCloudJobReference{JobUUID: d.JobUUID, PriceUUID: d.PriceUUID, CategoryUUID: d.CategoryUUID})
			}
			resolved, e := ResolveTransactionCloudReferences(ctx, tx, refs)
			if e != nil {
				return e
			}
			oldProcesses := map[string]TransactionCloudProcess{}
			for _, d := range aggregate.Details {
				for _, p := range d.Processes {
					oldProcesses[p.UUID] = p
				}
			}
			retainedProcesses := map[string]bool{}
			for _, d := range update.Details {
				for _, p := range d.Processes {
					old, known := oldProcesses[p.UUID]
					if (!known && p.Status != nil) || (known && !reflect.DeepEqual(old.Status, p.Status)) {
						return ErrTransactionCloudAudit
					}
					retainedProcesses[p.UUID] = true
				}
			}
			for id, p := range oldProcesses {
				if p.Status != nil && !retainedProcesses[id] {
					return ErrTransactionCloudAudit
				}
			}
			header, _ := json.Marshal(update.Header)
			if e = tx.Exec("UPDATE transaction_cloud SET header=?::jsonb,pemohon_id=?,petugas_id=? WHERE id=?", string(header), resolved.PemohonID, resolved.PetugasID, parent.ID).Error; e != nil {
				return e
			}
			// Retain removed children as tombstones. Payment rows are never rewritten.
			if e = tx.Exec("UPDATE transaction_cloud_detail SET deleted_at=clock_timestamp() WHERE transaction_id=? AND deleted_at IS NULL", parent.ID).Error; e != nil {
				return e
			}
			if e = tx.Exec("UPDATE transaction_cloud_process SET deleted_at=clock_timestamp() WHERE detail_uuid IN (SELECT uuid FROM transaction_cloud_detail WHERE transaction_id=?) AND deleted_at IS NULL", parent.ID).Error; e != nil {
				return e
			}
			for i, d := range update.Details {
				snapshot, _ := json.Marshal(d)
				ref := resolved.Jobs[i]
				jobColumn, priceColumn := r.jobColumns()
				result := tx.Exec(`INSERT INTO transaction_cloud_detail(uuid,transaction_id,`+jobColumn+`,`+priceColumn+`,kategori_id,snapshot,domain)
     VALUES(?::uuid,?,?,?,?,?::jsonb,?) ON CONFLICT(uuid) DO UPDATE SET `+jobColumn+`=EXCLUDED.`+jobColumn+`,`+priceColumn+`=EXCLUDED.`+priceColumn+`,kategori_id=EXCLUDED.kategori_id,snapshot=EXCLUDED.snapshot,deleted_at=NULL WHERE transaction_cloud_detail.transaction_id=EXCLUDED.transaction_id AND transaction_cloud_detail.domain=EXCLUDED.domain`, d.UUID, parent.ID, ref.JobID, ref.PriceID, ref.CategoryID, string(snapshot), r.domain)
				if result.Error != nil {
					return result.Error
				}
				if result.RowsAffected != 1 {
					return ErrTransactionCloudInvalid
				}
				for _, p := range d.Processes {
					snapshot, _ := json.Marshal(p)
					result = tx.Exec(`INSERT INTO transaction_cloud_process(uuid,detail_uuid,snapshot) VALUES(?::uuid,?::uuid,?::jsonb)
     ON CONFLICT(uuid) DO UPDATE SET snapshot=EXCLUDED.snapshot,deleted_at=NULL WHERE transaction_cloud_process.detail_uuid=EXCLUDED.detail_uuid`, p.UUID, d.UUID, string(snapshot))
					if result.Error != nil {
						return result.Error
					}
					if result.RowsAffected != 1 {
						return ErrTransactionCloudInvalid
					}
				}
			}
			aggregate.TransactionCloudCreate = *update
			aggregate.Domain = r.domain
		} else {
			// Existing local delete is unconditional soft deletion; no payment/audit erasure.
			if e := tx.Raw("UPDATE transaction_cloud SET deleted_at=clock_timestamp() WHERE id=? RETURNING deleted_at", parent.ID).Row().Scan(&aggregate.DeletedAt); e != nil {
				return e
			}
			if e := tx.Exec("UPDATE transaction_cloud_detail SET deleted_at=COALESCE(deleted_at,clock_timestamp()) WHERE transaction_id=?", parent.ID).Error; e != nil {
				return e
			}
			if e := tx.Exec("UPDATE transaction_cloud_process SET deleted_at=COALESCE(deleted_at,clock_timestamp()) WHERE detail_uuid IN (SELECT uuid FROM transaction_cloud_detail WHERE transaction_id=?)", parent.ID).Error; e != nil {
				return e
			}
			aggregate.MutationID = mutation
			aggregate.Domain = r.domain
			aggregate.ExpectedRevision = expected
		}
		if e := tx.Exec("UPDATE transaction_cloud SET revision=revision+1 WHERE id=?", parent.ID).Error; e != nil {
			return e
		}
		ack = TransactionCloudAck{MutationID: mutation, UUID: uuid, ServerID: parent.ID, Revision: expected + 1, FinalNumber: parent.FinalNumber, DeletedAt: aggregate.DeletedAt}
		receiptBytes, _ := json.Marshal(ack)
		event, _ := json.Marshal(aggregate)
		if e := tx.Exec("INSERT INTO transaction_cloud_mutation(mutation_id,actor_id,request_hash,acknowledgement) VALUES(?::uuid,?,?,?::jsonb)", mutation, actor, digest, string(receiptBytes)).Error; e != nil {
			return e
		}
		return tx.Exec("INSERT INTO transaction_cloud_outbox(aggregate_uuid,payload,revision,operation) VALUES(?::uuid,?::jsonb,?,?)", uuid, string(event), expected+1, op).Error
	})
	if err != nil {
		return nil, err
	}
	return &ack, nil
}
