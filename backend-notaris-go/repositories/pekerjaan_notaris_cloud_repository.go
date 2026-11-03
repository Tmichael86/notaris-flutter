package repositories

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"regexp"
	"strings"

	"gorm.io/gorm"
)

var ErrNotarisCloudInvalid = errors.New("invalid notaris aggregate or reference")
var ErrNotarisCloudReuse = errors.New("mutation ID reused with different content or actor")
var ErrNotarisCloudConflict = errors.New("aggregate UUID already exists")
var ErrNotarisCloudCursor = errors.New("invalid publication cursor")
var notarisCloudUUID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

type NotarisCloudAtribut struct {
	UUID  string `json:"uuid"`
	Value string `json:"atribut"`
}
type NotarisCloudProses struct {
	UUID    string                `json:"uuid"`
	Nama    string                `json:"nama"`
	Detail  string                `json:"detail"`
	Atribut []NotarisCloudAtribut `json:"atribut"`
}
type NotarisCloudHarga struct {
	UUID          string `json:"uuid"`
	CategoryUUID  string `json:"category_uuid"`
	Harga         string `json:"harga"`
	EstimasiWaktu string `json:"estimasi_waktu"`
}
type NotarisCloudCreate struct {
	MutationID string               `json:"mutation_id"`
	UUID       string               `json:"uuid"`
	Nama       string               `json:"nama"`
	Harga      []NotarisCloudHarga  `json:"harga"`
	Proses     []NotarisCloudProses `json:"proses"`
}
type NotarisCloudAck struct {
	MutationID string `json:"mutation_id"`
	UUID       string `json:"uuid"`
	ServerID   int64  `json:"server_id"`
	Revision   int64  `json:"revision"`
}
type NotarisCloudEvent struct {
	Sequence  int64              `json:"sequence"`
	Aggregate NotarisCloudCreate `json:"aggregate"`
	Revision  int64              `json:"revision"`
}
type NotarisCloudPage struct {
	Changes    []NotarisCloudEvent `json:"changes"`
	NextCursor int64               `json:"next_cursor"`
	HasMore    bool                `json:"has_more"`
}
type NotarisCloudRepository struct{ db *gorm.DB }

func NewNotarisCloudRepository(db *gorm.DB) *NotarisCloudRepository {
	return &NotarisCloudRepository{db: db}
}

func (m NotarisCloudCreate) validate() error {
	if !notarisCloudUUID.MatchString(m.MutationID) || !notarisCloudUUID.MatchString(m.UUID) || strings.TrimSpace(m.Nama) == "" || len(m.Harga) == 0 || len(m.Proses) == 0 || len(m.Harga) > 100 || len(m.Proses) > 100 {
		return ErrNotarisCloudInvalid
	}
	seen := map[string]bool{m.UUID: true}
	for _, h := range m.Harga {
		if !notarisCloudUUID.MatchString(h.UUID) || !notarisCloudUUID.MatchString(h.CategoryUUID) || strings.TrimSpace(h.Harga) == "" || strings.TrimSpace(h.EstimasiWaktu) == "" || seen[h.UUID] {
			return ErrNotarisCloudInvalid
		}
		seen[h.UUID] = true
	}
	for _, p := range m.Proses {
		if !notarisCloudUUID.MatchString(p.UUID) || strings.TrimSpace(p.Nama) == "" || strings.TrimSpace(p.Detail) == "" || len(p.Atribut) > 100 || seen[p.UUID] {
			return ErrNotarisCloudInvalid
		}
		seen[p.UUID] = true
		for _, a := range p.Atribut {
			if !notarisCloudUUID.MatchString(a.UUID) || strings.TrimSpace(a.Value) == "" || seen[a.UUID] {
				return ErrNotarisCloudInvalid
			}
			seen[a.UUID] = true
		}
	}
	return nil
}

// Create is the only accepted mutation in this slice. A receipt is committed
// with every parent/child write and one complete aggregate outbox event.
func (r *NotarisCloudRepository) Create(ctx context.Context, m NotarisCloudCreate, actor int64) (*NotarisCloudAck, error) {
	if actor <= 0 || m.validate() != nil {
		return nil, ErrNotarisCloudInvalid
	}
	body, _ := json.Marshal(m)
	hash := sha256.Sum256(body)
	digest := hex.EncodeToString(hash[:])
	var ack NotarisCloudAck
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Serializes receipt probes and create attempts for the same immutable ID.
		if err := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", m.MutationID).Error; err != nil {
			return err
		}
		var saved struct {
			ActorID         int64
			RequestHash     string
			Acknowledgement []byte
		}
		probe := tx.Raw("SELECT actor_id,request_hash,acknowledgement FROM pekerjaan_notaris_sync_mutation WHERE mutation_id=?::uuid", m.MutationID).Scan(&saved)
		if probe.Error != nil {
			return probe.Error
		}
		if probe.RowsAffected > 0 {
			if saved.ActorID != actor || saved.RequestHash != digest {
				return ErrNotarisCloudReuse
			}
			return json.Unmarshal(saved.Acknowledgement, &ack)
		}
		var existing int64
		if err := tx.Raw("SELECT count(*) FROM pekerjaan_notaris WHERE uuid=?::uuid", m.UUID).Row().Scan(&existing); err != nil {
			return err
		}
		if existing != 0 {
			return ErrNotarisCloudConflict
		}
		if err := tx.Raw("INSERT INTO pekerjaan_notaris(uuid,nama,status,row_version) VALUES(?::uuid,?,1,1) RETURNING id", m.UUID, m.Nama).Row().Scan(&ack.ServerID); err != nil {
			return err
		}
		for _, h := range m.Harga {
			var categoryID int64
			if err := tx.Raw("SELECT id FROM pekerjaan_kategori WHERE uuid=?::uuid AND status=1", h.CategoryUUID).Row().Scan(&categoryID); err != nil {
				return ErrNotarisCloudInvalid
			}
			if err := tx.Exec("INSERT INTO pekerjaan_notaris_harga(uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu,status) VALUES(?::uuid,?,?,?,?,1)", h.UUID, ack.ServerID, categoryID, h.Harga, h.EstimasiWaktu).Error; err != nil {
				return err
			}
		}
		for _, p := range m.Proses {
			if err := tx.Exec("INSERT INTO pekerjaan_notaris_proses(uuid,pekerjaan_notaris_id,nama,detail,status) VALUES(?::uuid,?,?,?,1)", p.UUID, ack.ServerID, p.Nama, p.Detail).Error; err != nil {
				return err
			}
			for _, a := range p.Atribut {
				if err := tx.Exec("INSERT INTO pekerjaan_notaris_sync_atribut(uuid,proses_uuid,atribut) VALUES(?::uuid,?::uuid,?)", a.UUID, p.UUID, a.Value).Error; err != nil {
					return err
				}
			}
		}
		ack = NotarisCloudAck{MutationID: m.MutationID, UUID: m.UUID, ServerID: ack.ServerID, Revision: 1}
		ackBytes, _ := json.Marshal(ack)
		if err := tx.Exec("INSERT INTO pekerjaan_notaris_sync_mutation(mutation_id,actor_id,request_hash,acknowledgement) VALUES(?::uuid,?,?,?::jsonb)", m.MutationID, actor, digest, string(ackBytes)).Error; err != nil {
			return err
		}
		if err := tx.Exec("INSERT INTO pekerjaan_notaris_sync_outbox(aggregate_uuid,payload) VALUES(?::uuid,?::jsonb)", m.UUID, string(body)).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &ack, nil
}

// Publish advances a locked counter only after reading committed outbox rows.
func (r *NotarisCloudRepository) Publish(ctx context.Context, limit int) (int, error) {
	if limit < 1 || limit > 500 {
		return 0, ErrNotarisCloudInvalid
	}
	count := 0
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var seq int64
		if err := tx.Raw("SELECT last_seq FROM pekerjaan_notaris_sync_publication WHERE id=1 FOR UPDATE").Row().Scan(&seq); err != nil {
			return err
		}
		var rows []struct{ ID int64 }
		if err := tx.Raw("SELECT id FROM pekerjaan_notaris_sync_outbox WHERE publication_seq IS NULL ORDER BY id LIMIT ? FOR UPDATE", limit).Scan(&rows).Error; err != nil {
			return err
		}
		for _, row := range rows {
			if err := tx.Raw("UPDATE pekerjaan_notaris_sync_publication SET last_seq=last_seq+1 WHERE id=1 RETURNING last_seq").Row().Scan(&seq); err != nil {
				return err
			}
			if err := tx.Exec("UPDATE pekerjaan_notaris_sync_outbox SET publication_seq=?,published_at=clock_timestamp() WHERE id=?", seq, row.ID).Error; err != nil {
				return err
			}
		}
		count = len(rows)
		return nil
	})
	return count, err
}

func (r *NotarisCloudRepository) Pull(ctx context.Context, cursor int64, limit int) (*NotarisCloudPage, error) {
	if cursor < 0 || limit < 1 || limit > 500 {
		return nil, ErrNotarisCloudCursor
	}
	page := &NotarisCloudPage{Changes: []NotarisCloudEvent{}, NextCursor: cursor}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var last, min int64
		if err := tx.Raw("SELECT last_seq,min_cursor FROM pekerjaan_notaris_sync_publication WHERE id=1").Row().Scan(&last, &min); err != nil {
			return err
		}
		if cursor < min || cursor > last {
			return ErrNotarisCloudCursor
		}
		var rows []struct {
			PublicationSeq int64
			Payload        []byte
		}
		if err := tx.Raw("SELECT publication_seq,payload FROM pekerjaan_notaris_sync_outbox WHERE publication_seq>? ORDER BY publication_seq LIMIT ?", cursor, limit+1).Scan(&rows).Error; err != nil {
			return err
		}
		page.HasMore = len(rows) > limit
		if page.HasMore {
			rows = rows[:limit]
		}
		for _, row := range rows {
			var aggregate NotarisCloudCreate
			if err := json.Unmarshal(row.Payload, &aggregate); err != nil {
				return err
			}
			page.Changes = append(page.Changes, NotarisCloudEvent{Sequence: row.PublicationSeq, Aggregate: aggregate, Revision: 1})
			page.NextCursor = row.PublicationSeq
		}
		return nil
	})
	return page, err
}
