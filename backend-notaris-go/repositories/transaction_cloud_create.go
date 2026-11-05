package repositories

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"gorm.io/gorm"
	"math"
	"strings"
	"time"
)

var ErrTransactionCloudInvalid = errors.New("invalid transaction aggregate")
var ErrTransactionCloudReuse = errors.New("transaction mutation reused")
var ErrTransactionCloudConflict = errors.New("transaction UUID already accepted")
var ErrTransactionCloudCursor = errors.New("invalid transaction cursor")

type TransactionCloudHeader struct {
	Date           time.Time  `json:"date"`
	Due            *time.Time `json:"due"`
	Status         string     `json:"status"`
	Total          float64    `json:"total"`
	Discount       float64    `json:"discount"`
	InitialPayment float64    `json:"initial_payment"`
	Method         string     `json:"method"`
	Materai        int        `json:"materai"`
	Note           *string    `json:"note"`
}
type TransactionCloudProcess struct {
	UUID         string  `json:"uuid"`
	SourceID     *string `json:"source_id"`
	Name         string  `json:"name"`
	Status       *string `json:"status"`
	LegacyStatus *string `json:"legacy_status"`
	LegacyData   *string `json:"legacy_data"`
	Note         *string `json:"note"`
}
type TransactionCloudDetail struct {
	UUID            string                    `json:"uuid"`
	JobUUID         string                    `json:"job_uuid"`
	PriceUUID       string                    `json:"price_uuid"`
	CategoryUUID    string                    `json:"category_uuid"`
	Name            string                    `json:"name"`
	Category        string                    `json:"category"`
	Estimate        string                    `json:"estimate"`
	ServiceCost     float64                   `json:"service_cost"`
	OtherCost       float64                   `json:"other_cost"`
	Total           float64                   `json:"total"`
	ProcessSnapshot json.RawMessage           `json:"process_snapshot"`
	Processes       []TransactionCloudProcess `json:"processes"`
}
type TransactionCloudPayment struct {
	UUID        string    `json:"uuid"`
	Date        time.Time `json:"date"`
	Amount      float64   `json:"amount"`
	Method      string    `json:"method"`
	Description *string   `json:"description"`
	Order       int       `json:"order"`
}
type TransactionCloudCreate struct {
	MutationID       string                    `json:"mutation_id"`
	UUID             string                    `json:"uuid"`
	ExpectedRevision int64                     `json:"expected_revision"`
	PemohonUUID      string                    `json:"pemohon_uuid"`
	PetugasUUID      string                    `json:"petugas_uuid"`
	Header           TransactionCloudHeader    `json:"header"`
	Details          []TransactionCloudDetail  `json:"details"`
	Payments         []TransactionCloudPayment `json:"payments"`
}
type TransactionCloudAck struct {
	MutationID  string `json:"mutation_id"`
	UUID        string `json:"uuid"`
	ServerID    int64  `json:"server_id"`
	Revision    int64  `json:"revision"`
	FinalNumber string `json:"final_number"`
}
type TransactionCloudAggregate struct {
	TransactionCloudCreate
	FinalNumber string `json:"final_number"`
}
type TransactionCloudEvent struct {
	Sequence  int64                     `json:"sequence"`
	Aggregate TransactionCloudAggregate `json:"aggregate"`
	Revision  int64                     `json:"revision"`
	Operation string                    `json:"operation"`
}
type TransactionCloudPage struct {
	Changes    []TransactionCloudEvent `json:"changes"`
	NextCursor int64                   `json:"next_cursor"`
	HasMore    bool                    `json:"has_more"`
}
type TransactionCloudRepository struct{ db *gorm.DB }

func NewTransactionCloudRepository(db *gorm.DB) *TransactionCloudRepository {
	return &TransactionCloudRepository{db}
}
func (m TransactionCloudCreate) validate() error {
	seen := map[string]bool{}
	identity := func(s string) bool {
		s = strings.ToLower(s)
		if !notarisCloudUUID.MatchString(s) || seen[s] {
			return false
		}
		seen[s] = true
		return true
	}
	validMoney := func(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) && v >= 0 }
	if !notarisCloudUUID.MatchString(m.MutationID) || !identity(m.UUID) || m.ExpectedRevision != 0 || len(m.Details) == 0 || len(m.Details) > 100 || len(m.Payments) > 100 || m.Header.Date.IsZero() || strings.TrimSpace(m.Header.Status) == "" || strings.TrimSpace(m.Header.Method) == "" || m.Header.Materai < 0 {
		return ErrTransactionCloudInvalid
	}
	total := 0.0
	for _, d := range m.Details {
		if !identity(d.UUID) || strings.TrimSpace(d.Name) == "" || !validMoney(d.ServiceCost) || !validMoney(d.OtherCost) || !validMoney(d.Total) || math.Abs(d.ServiceCost+d.OtherCost-d.Total) > 0.000001 || len(d.Processes) > 500 {
			return ErrTransactionCloudInvalid
		}
		var snapshot []map[string]any
		if len(d.ProcessSnapshot) > 0 && string(d.ProcessSnapshot) != "null" {
			if json.Unmarshal(d.ProcessSnapshot, &snapshot) != nil {
				return ErrTransactionCloudInvalid
			}
		}
		for _, p := range d.Processes {
			if !identity(p.UUID) || strings.TrimSpace(p.Name) == "" {
				return ErrTransactionCloudInvalid
			}
		}
		total += d.Total
	}
	paid := 0.0
	orders := map[int]bool{}
	for _, p := range m.Payments {
		if !identity(p.UUID) || !validMoney(p.Amount) || p.Amount == 0 || p.Date.IsZero() || strings.TrimSpace(p.Method) == "" || p.Order < 1 || orders[p.Order] {
			return ErrTransactionCloudInvalid
		}
		orders[p.Order] = true
		paid += p.Amount
	}
	if !validMoney(total) || !validMoney(m.Header.Total) || !validMoney(m.Header.Discount) || !validMoney(m.Header.InitialPayment) || m.Header.Discount > total || math.Abs(total-m.Header.Discount-m.Header.Total) > 0.000001 || math.Abs(paid-m.Header.InitialPayment) > 0.000001 || paid > m.Header.Total {
		return ErrTransactionCloudInvalid
	}
	return nil
}
func (r *TransactionCloudRepository) Create(ctx context.Context, m TransactionCloudCreate, actor int64) (*TransactionCloudAck, error) {
	if actor < 1 || m.validate() != nil {
		return nil, ErrTransactionCloudInvalid
	}
	body, _ := json.Marshal(m)
	hash := sha256.Sum256(body)
	digest := hex.EncodeToString(hash[:])
	var ack TransactionCloudAck
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", "transaction-mutation:"+m.MutationID).Error; e != nil {
			return e
		}
		var saved struct {
			ActorID         int64
			RequestHash     string
			Acknowledgement []byte
		}
		probe := tx.Raw("SELECT actor_id,request_hash,acknowledgement FROM transaction_cloud_mutation WHERE mutation_id=?::uuid", m.MutationID).Scan(&saved)
		if probe.Error != nil {
			return probe.Error
		}
		if probe.RowsAffected > 0 {
			if saved.ActorID != actor || saved.RequestHash != digest {
				return ErrTransactionCloudReuse
			}
			return json.Unmarshal(saved.Acknowledgement, &ack)
		}
		if e := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", "transaction-uuid:"+m.UUID).Error; e != nil {
			return e
		}
		var count int64
		if e := tx.Raw("SELECT count(*) FROM transaction_cloud WHERE uuid=?::uuid", m.UUID).Row().Scan(&count); e != nil {
			return e
		}
		if count != 0 {
			return ErrTransactionCloudConflict
		}
		refs := TransactionCloudReferences{PemohonUUID: m.PemohonUUID, PetugasUUID: m.PetugasUUID, Domain: "notaris"}
		for _, d := range m.Details {
			refs.Jobs = append(refs.Jobs, TransactionCloudJobReference{JobUUID: d.JobUUID, PriceUUID: d.PriceUUID, CategoryUUID: d.CategoryUUID})
		}
		resolved, e := ResolveTransactionCloudReferences(ctx, tx, refs)
		if e != nil {
			return e
		}
		number, e := allocateTransactionNumber(ctx, tx, "notaris")
		if e != nil {
			return e
		}
		header, _ := json.Marshal(m.Header)
		if e = tx.Raw("INSERT INTO transaction_cloud(uuid,final_number,revision,pemohon_id,petugas_id,header) VALUES(?::uuid,?,1,?,?,?::jsonb) RETURNING id", m.UUID, number, resolved.PemohonID, resolved.PetugasID, string(header)).Row().Scan(&ack.ServerID); e != nil {
			return e
		}
		for i, d := range m.Details {
			snapshot, _ := json.Marshal(d)
			ref := resolved.Jobs[i]
			if e = tx.Exec("INSERT INTO transaction_cloud_detail(uuid,transaction_id,pekerjaan_notaris_id,harga_id,kategori_id,snapshot) VALUES(?::uuid,?,?,?,?,?::jsonb)", d.UUID, ack.ServerID, ref.JobID, ref.PriceID, ref.CategoryID, string(snapshot)).Error; e != nil {
				return e
			}
			for _, p := range d.Processes {
				snapshot, _ := json.Marshal(p)
				if e = tx.Exec("INSERT INTO transaction_cloud_process(uuid,detail_uuid,snapshot) VALUES(?::uuid,?::uuid,?::jsonb)", p.UUID, d.UUID, string(snapshot)).Error; e != nil {
					return e
				}
			}
		}
		for _, p := range m.Payments {
			snapshot, _ := json.Marshal(p)
			if e = tx.Exec("INSERT INTO transaction_cloud_payment(uuid,transaction_id,nominal,snapshot) VALUES(?::uuid,?,?,?::jsonb)", p.UUID, ack.ServerID, p.Amount, string(snapshot)).Error; e != nil {
				return e
			}
		}
		ack = TransactionCloudAck{MutationID: m.MutationID, UUID: m.UUID, ServerID: ack.ServerID, Revision: 1, FinalNumber: number}
		receipt, _ := json.Marshal(ack)
		event, _ := json.Marshal(TransactionCloudAggregate{TransactionCloudCreate: m, FinalNumber: number})
		if e = tx.Exec("INSERT INTO transaction_cloud_mutation(mutation_id,actor_id,request_hash,acknowledgement) VALUES(?::uuid,?,?,?::jsonb)", m.MutationID, actor, digest, string(receipt)).Error; e != nil {
			return e
		}
		return tx.Exec("INSERT INTO transaction_cloud_outbox(aggregate_uuid,payload) VALUES(?::uuid,?::jsonb)", m.UUID, string(event)).Error
	})
	if err != nil {
		return nil, err
	}
	return &ack, nil
}
func (r *TransactionCloudRepository) Publish(ctx context.Context, limit int) (int, error) {
	if limit < 1 || limit > 500 {
		return 0, ErrTransactionCloudInvalid
	}
	count := 0
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var seq int64
		if e := tx.Raw("SELECT last_seq FROM transaction_cloud_publication WHERE id=1 FOR UPDATE").Row().Scan(&seq); e != nil {
			return e
		}
		var ids []int64
		if e := tx.Raw("SELECT id FROM transaction_cloud_outbox WHERE publication_seq IS NULL ORDER BY id LIMIT ? FOR UPDATE", limit).Scan(&ids).Error; e != nil {
			return e
		}
		for _, id := range ids {
			seq++
			if e := tx.Exec("UPDATE transaction_cloud_outbox SET publication_seq=?,published_at=clock_timestamp() WHERE id=?", seq, id).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec("UPDATE transaction_cloud_publication SET last_seq=? WHERE id=1", seq).Error; e != nil {
			return e
		}
		count = len(ids)
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	return count, err
}
func (r *TransactionCloudRepository) Pull(ctx context.Context, cursor int64, limit int) (*TransactionCloudPage, error) {
	if cursor < 0 || limit < 1 || limit > 500 {
		return nil, ErrTransactionCloudCursor
	}
	page := &TransactionCloudPage{Changes: []TransactionCloudEvent{}, NextCursor: cursor}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var last, min int64
		if e := tx.Raw("SELECT last_seq,min_cursor FROM transaction_cloud_publication WHERE id=1").Row().Scan(&last, &min); e != nil {
			return e
		}
		if cursor < min || cursor > last {
			return ErrTransactionCloudCursor
		}
		var rows []struct {
			PublicationSeq int64
			Payload        []byte
		}
		if e := tx.Raw("SELECT publication_seq,payload FROM transaction_cloud_outbox WHERE publication_seq>? ORDER BY publication_seq LIMIT ?", cursor, limit+1).Scan(&rows).Error; e != nil {
			return e
		}
		page.HasMore = len(rows) > limit
		if page.HasMore {
			rows = rows[:limit]
		}
		for _, row := range rows {
			var a TransactionCloudAggregate
			if e := json.Unmarshal(row.Payload, &a); e != nil {
				return e
			}
			page.Changes = append(page.Changes, TransactionCloudEvent{Sequence: row.PublicationSeq, Aggregate: a, Revision: 1, Operation: "create"})
			page.NextCursor = row.PublicationSeq
		}
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	return page, err
}
