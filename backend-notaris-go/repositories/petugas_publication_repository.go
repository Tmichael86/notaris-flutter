package repositories

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"backend-notaris-go/models"
	"backend-notaris-go/synccontract"
	"gorm.io/gorm"
)

var ErrPetugasCursorExpired = errors.New("petugas cursor expired: full resync required")
var ErrPetugasPull = errors.New("invalid petugas pull cursor or limit")

type PetugasPublicationRepository struct{ db *gorm.DB }

func NewPetugasPublicationRepository(db *gorm.DB) *PetugasPublicationRepository {
	return &PetugasPublicationRepository{db: db}
}

// Publish commits event assignment and counter advancement together. The singleton
// row lock is held until commit, serializing every publisher including retries.
func (r *PetugasPublicationRepository) Publish(ctx context.Context, limit int) (int, error) {
	if limit < 1 || limit > 500 {
		return 0, ErrPetugasPull
	}
	count := 0
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var err error
		count, err = publishPetugasBatch(tx, limit)
		return err
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return 0, err
	}
	return count, nil
}

// Internal transaction helper also permits integration tests to inject rollback
// at the exact pre-commit boundary, executing the real publisher statements.
func publishPetugasBatch(tx *gorm.DB, limit int) (int, error) {
	var last int64
	if err := tx.Raw("SELECT last_seq FROM petugas_sync_publication WHERE id = 1 FOR UPDATE").Row().Scan(&last); err != nil {
		return 0, err
	}
	var rows []struct{ ID int64 }
	// READ COMMITTED: only committed outbox rows are visible. No SKIP LOCKED:
	// holding the counter lock already serializes publishers through commit.
	if err := tx.Raw("SELECT id FROM petugas_sync_outbox WHERE publication_seq IS NULL ORDER BY id LIMIT ? FOR UPDATE", limit).Scan(&rows).Error; err != nil {
		return 0, err
	}
	for _, row := range rows {
		// PostgreSQL detects bigint overflow, rolling the whole batch back.
		if err := tx.Raw("UPDATE petugas_sync_publication SET last_seq = last_seq + 1 WHERE id = 1 RETURNING last_seq").Row().Scan(&last); err != nil {
			return 0, err
		}
		if err := tx.Exec("UPDATE petugas_sync_outbox SET publication_seq = ?, published_at = clock_timestamp() WHERE id = ? AND publication_seq IS NULL", last, row.ID).Error; err != nil {
			return 0, err
		}
	}
	return len(rows), nil
}

type PetugasPullPage struct {
	Changes    []synccontract.PetugasChange `json:"changes"`
	NextCursor int64                        `json:"next_cursor"`
	HasMore    bool                         `json:"has_more"`
}

func (r *PetugasPublicationRepository) Pull(ctx context.Context, request synccontract.PetugasPullRequest) (*PetugasPullPage, error) {
	if request.Validate() != nil {
		return nil, ErrPetugasPull
	}
	page := &PetugasPullPage{Changes: make([]synccontract.PetugasChange, 0), NextCursor: request.Cursor}
	// Counter bounds and event selection must observe one consistent snapshot,
	// including when retention is implemented later.
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var bounds struct {
			LastSeq   int64
			MinCursor int64
		}
		if err := tx.Raw("SELECT last_seq,min_cursor FROM petugas_sync_publication WHERE id = 1").Row().Scan(&bounds.LastSeq, &bounds.MinCursor); err != nil {
			return err
		}
		if request.Cursor < bounds.MinCursor {
			return ErrPetugasCursorExpired
		}
		if request.Cursor > bounds.LastSeq {
			return ErrPetugasPull
		}
		var events []struct {
			PetugasUUID    string
			RowVersion     int64
			Tombstone      bool
			Payload        string
			PublicationSeq int64
		}
		if err := tx.Raw("SELECT petugas_uuid::text, row_version, tombstone, payload::text, publication_seq FROM petugas_sync_outbox WHERE publication_seq > ? ORDER BY publication_seq LIMIT ?", request.Cursor, request.Limit+1).Scan(&events).Error; err != nil {
			return err
		}
		page.HasMore = len(events) > request.Limit
		if page.HasMore {
			events = events[:request.Limit]
		}
		for _, event := range events {
			var row models.Petugas
			if err := json.Unmarshal([]byte(event.Payload), &row); err != nil {
				return err
			}
			if row.UUID == nil || *row.UUID != event.PetugasUUID || row.RowVersion != event.RowVersion || row.ID == 0 || event.Tombstone != (row.Status != 1 || row.DeletedAt != nil) {
				return fmt.Errorf("invalid petugas outbox snapshot at publication %d", event.PublicationSeq)
			}
			change := synccontract.PetugasChange{PublicationSequence: event.PublicationSeq, PetugasUUID: event.PetugasUUID, ServerID: row.ID, RowVersion: event.RowVersion, Tombstone: event.Tombstone}
			if !event.Tombstone {
				// PostgreSQL date scanned into the legacy model may include time/zone.
				date := row.TanggalLahir
				if date != nil && len(*date) >= 10 {
					value := (*date)[:10]
					date = &value
				}
				change.Payload = &synccontract.PetugasPayload{NIK: row.NIK, Nama: row.Nama, Alamat: row.Alamat, TempatLahir: row.TempatLahir, TanggalLahir: date, JenisKelaminID: row.JenisKelamin, NoTelp: row.NoTelp, Email: row.Email, UserID: row.UserID}
			}
			page.Changes = append(page.Changes, change)
			page.NextCursor = event.PublicationSeq
		}
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if err != nil {
		return nil, err
	}
	return page, nil
}
