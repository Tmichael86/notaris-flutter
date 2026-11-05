package repositories

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"

	"gorm.io/gorm"
)

var ErrNotarisCloudRevision = errors.New("notaris aggregate revision conflict")

func mutationDigest(operation string, request any) (string, error) {
	body, err := json.Marshal(request)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(append([]byte(operation+":"), body...))
	return hex.EncodeToString(sum[:]), nil
}

func previousNotarisReceipt(tx *gorm.DB, mutationID string, actor int64, digest string, ack *NotarisCloudAck) (bool, error) {
	if err := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", mutationID).Error; err != nil {
		return false, err
	}
	var saved struct {
		ActorID         int64
		RequestHash     string
		Acknowledgement []byte
	}
	probe := tx.Raw("SELECT actor_id,request_hash,acknowledgement FROM pekerjaan_notaris_sync_mutation WHERE mutation_id=?::uuid", mutationID).Scan(&saved)
	if probe.Error != nil {
		return false, probe.Error
	}
	if probe.RowsAffected == 0 {
		return false, nil
	}
	if saved.ActorID != actor || saved.RequestHash != digest {
		return true, ErrNotarisCloudReuse
	}
	return true, json.Unmarshal(saved.Acknowledgement, ack)
}

func recordNotarisMutation(tx *gorm.DB, mutationID string, actor int64, digest string, ack NotarisCloudAck, payload any, operation string) error {
	ackBytes, _ := json.Marshal(ack)
	body, _ := json.Marshal(payload)
	if err := tx.Exec("INSERT INTO pekerjaan_notaris_sync_mutation(mutation_id,actor_id,request_hash,acknowledgement) VALUES(?::uuid,?,?,?::jsonb)", mutationID, actor, digest, string(ackBytes)).Error; err != nil {
		return err
	}
	return tx.Exec("INSERT INTO pekerjaan_notaris_sync_outbox(aggregate_uuid,payload,revision,operation) VALUES(?::uuid,?::jsonb,?,?)", ack.UUID, string(body), ack.Revision, operation).Error
}

// Update replaces the active aggregate set while preserving UUIDs and rows for
// retained children. Removed children become inactive in the same transaction.
func (r *NotarisCloudRepository) Update(ctx context.Context, m NotarisCloudUpdate, actor int64) (*NotarisCloudAck, error) {
	if actor <= 0 || m.ExpectedRevision < 1 || m.NotarisCloudCreate.validate() != nil {
		return nil, ErrNotarisCloudInvalid
	}
	digest, err := mutationDigest("update", m)
	if err != nil {
		return nil, err
	}
	var ack NotarisCloudAck
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		found, err := previousNotarisReceipt(tx, m.MutationID, actor, digest, &ack)
		if err != nil || found {
			return err
		}
		var parent struct {
			ID         int64
			RowVersion int64
			Status     int16
		}
		probe := tx.Raw("SELECT id,row_version,status FROM pekerjaan_notaris WHERE uuid=?::uuid FOR UPDATE", m.UUID).Scan(&parent)
		if probe.Error != nil {
			return probe.Error
		}
		if probe.RowsAffected == 0 || parent.Status != 1 || parent.RowVersion != m.ExpectedRevision {
			return ErrNotarisCloudRevision
		}
		// Deactivation is reversible within this transaction. UUID ownership is
		// enforced by the conflict WHERE clauses; another aggregate cannot steal it.
		if err := tx.Exec("UPDATE pekerjaan_notaris_harga SET status=0 WHERE pekerjaan_notaris_id=?", parent.ID).Error; err != nil {
			return err
		}
		if err := tx.Exec("UPDATE pekerjaan_notaris_proses SET status=0 WHERE pekerjaan_notaris_id=?", parent.ID).Error; err != nil {
			return err
		}
		if err := tx.Exec("UPDATE pekerjaan_notaris_sync_atribut SET status=0 WHERE proses_uuid IN (SELECT uuid FROM pekerjaan_notaris_proses WHERE pekerjaan_notaris_id=?)", parent.ID).Error; err != nil {
			return err
		}
		for _, h := range m.Harga {
			var categoryID int64
			if err := tx.Raw("SELECT id FROM pekerjaan_kategori WHERE uuid=?::uuid AND status=1", h.CategoryUUID).Row().Scan(&categoryID); err != nil {
				return ErrNotarisCloudInvalid
			}
			result := tx.Exec(`INSERT INTO pekerjaan_notaris_harga(uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu,status) VALUES(?::uuid,?,?,?,?,1)
				ON CONFLICT(uuid) DO UPDATE SET kategori_pekerjaan_id=excluded.kategori_pekerjaan_id,harga=excluded.harga,estimasi_waktu=excluded.estimasi_waktu,status=1
				WHERE pekerjaan_notaris_harga.pekerjaan_notaris_id=excluded.pekerjaan_notaris_id`, h.UUID, parent.ID, categoryID, h.Harga, h.EstimasiWaktu)
			if result.Error != nil {
				return result.Error
			}
			if result.RowsAffected != 1 {
				return ErrNotarisCloudInvalid
			}
		}
		for _, p := range m.Proses {
			result := tx.Exec(`INSERT INTO pekerjaan_notaris_proses(uuid,pekerjaan_notaris_id,nama,detail,status) VALUES(?::uuid,?,?,?,1)
				ON CONFLICT(uuid) DO UPDATE SET nama=excluded.nama,detail=excluded.detail,status=1
				WHERE pekerjaan_notaris_proses.pekerjaan_notaris_id=excluded.pekerjaan_notaris_id`, p.UUID, parent.ID, p.Nama, p.Detail)
			if result.Error != nil {
				return result.Error
			}
			if result.RowsAffected != 1 {
				return ErrNotarisCloudInvalid
			}
			for _, a := range p.Atribut {
				result := tx.Exec(`INSERT INTO pekerjaan_notaris_sync_atribut(uuid,proses_uuid,atribut,status) VALUES(?::uuid,?::uuid,?,1)
					ON CONFLICT(uuid) DO UPDATE SET atribut=excluded.atribut,status=1
					WHERE pekerjaan_notaris_sync_atribut.proses_uuid=excluded.proses_uuid`, a.UUID, p.UUID, a.Value)
				if result.Error != nil {
					return result.Error
				}
				if result.RowsAffected != 1 {
					return ErrNotarisCloudInvalid
				}
			}
		}
		ack = NotarisCloudAck{MutationID: m.MutationID, UUID: m.UUID, ServerID: parent.ID, Revision: parent.RowVersion + 1}
		if err := tx.Exec("UPDATE pekerjaan_notaris SET nama=?,row_version=? WHERE id=?", m.Nama, ack.Revision, parent.ID).Error; err != nil {
			return err
		}
		return recordNotarisMutation(tx, m.MutationID, actor, digest, ack, m.NotarisCloudCreate, "update")
	})
	if err != nil {
		return nil, err
	}
	return &ack, nil
}

func (r *NotarisCloudRepository) Delete(ctx context.Context, m NotarisCloudDelete, actor int64) (*NotarisCloudAck, error) {
	if actor <= 0 || m.ExpectedRevision < 1 || !notarisCloudUUID.MatchString(m.MutationID) || !notarisCloudUUID.MatchString(m.UUID) {
		return nil, ErrNotarisCloudInvalid
	}
	digest, err := mutationDigest("delete", m)
	if err != nil {
		return nil, err
	}
	var ack NotarisCloudAck
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		found, err := previousNotarisReceipt(tx, m.MutationID, actor, digest, &ack)
		if err != nil || found {
			return err
		}
		var parent struct {
			ID         int64
			RowVersion int64
			Status     int16
		}
		probe := tx.Raw("SELECT id,row_version,status FROM pekerjaan_notaris WHERE uuid=?::uuid FOR UPDATE", m.UUID).Scan(&parent)
		if probe.Error != nil {
			return probe.Error
		}
		if probe.RowsAffected == 0 || parent.Status != 1 || parent.RowVersion != m.ExpectedRevision {
			return ErrNotarisCloudRevision
		}
		ack = NotarisCloudAck{MutationID: m.MutationID, UUID: m.UUID, ServerID: parent.ID, Revision: parent.RowVersion + 1}
		if err := tx.Exec("UPDATE pekerjaan_notaris SET status=0,deleted_at=clock_timestamp(),row_version=? WHERE id=?", ack.Revision, parent.ID).Error; err != nil {
			return err
		}
		return recordNotarisMutation(tx, m.MutationID, actor, digest, ack, m, "delete")
	})
	if err != nil {
		return nil, err
	}
	return &ack, nil
}
