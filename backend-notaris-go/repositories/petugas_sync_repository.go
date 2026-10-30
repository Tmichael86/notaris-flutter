package repositories

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"backend-notaris-go/models"
	"backend-notaris-go/synccontract"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	ErrMutationReuse     = errors.New("mutation_id already used with another request or actor")
	ErrPetugasReference  = errors.New("petugas reference does not exist")
	ErrPetugasConstraint = errors.New("petugas database constraint violation")
)

// PetugasVersionConflict is intended to become HTTP 409 at the transport layer.
// Current is nil for an expected update whose UUID does not exist.
type PetugasVersionConflict struct{ Current *models.Petugas }

func (e *PetugasVersionConflict) Error() string { return "petugas row version conflict" }

// PetugasSyncRepository is deliberately not wired into the legacy controllers.
// All writes, mutation receipts and unpublished snapshots commit together.
type PetugasSyncRepository struct{ db *gorm.DB }

func NewPetugasSyncRepository(db *gorm.DB) *PetugasSyncRepository {
	return &PetugasSyncRepository{db: db}
}

var syncUUID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func preparePetugasMutation(m synccontract.PetugasMutation, actor uint) (synccontract.PetugasMutation, string, error) {
	if err := m.Validate(); err != nil {
		return m, "", err
	}
	if actor == 0 || !syncUUID.MatchString(m.MutationID) || !syncUUID.MatchString(m.PetugasUUID) {
		return m, "", synccontract.ErrInvalidMutation
	}
	m.MutationID = strings.ToLower(m.MutationID)
	m.PetugasUUID = strings.ToLower(m.PetugasUUID)
	// Include the authenticated actor so another actor cannot replay a receipt.
	b, err := json.Marshal(struct {
		Actor    uint
		Mutation synccontract.PetugasMutation
	}{actor, m})
	if err != nil {
		return m, "", err
	}
	h := sha256.Sum256(b)
	return m, hex.EncodeToString(h[:]), nil
}

func (r *PetugasSyncRepository) Apply(ctx context.Context, mutation synccontract.PetugasMutation, actor uint) (*synccontract.PetugasAcknowledgement, error) {
	m, hash, err := preparePetugasMutation(mutation, actor)
	if err != nil {
		return nil, err
	}
	var ack synccontract.PetugasAcknowledgement
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Lock mutation identity first, then record identity, consistently. UUID
		// advisory locking covers the absent-row case; row locking also protects
		// against existing legacy writers. Hash collisions only add contention.
		for _, key := range []string{"petugas:mutation:" + m.MutationID, "petugas:uuid:" + m.PetugasUUID} {
			if err := tx.Exec("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", key).Error; err != nil {
				return err
			}
		}
		var receipt struct {
			RequestHash     string
			Acknowledgement string
		}
		result := tx.Raw("SELECT request_hash, acknowledgement::text FROM petugas_sync_mutations WHERE mutation_id = ?::uuid", m.MutationID).Scan(&receipt)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 0 {
			if receipt.RequestHash != hash {
				return ErrMutationReuse
			}
			return json.Unmarshal([]byte(receipt.Acknowledgement), &ack)
		}

		var current models.Petugas
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("uuid = ?::uuid", m.PetugasUUID).Take(&current).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		exists := err == nil
		if err := checkPetugasVersion(m, exists, &current); err != nil {
			return err
		}

		changed := true
		now := time.Now().UTC()
		if m.Operation == synccontract.PetugasDelete {
			if current.Status != 1 || current.DeletedAt != nil {
				changed = false // New mutation, current tombstone version: receipt only.
			} else {
				current.Status = 0
				current.DeletedAt = &now
			}
		} else {
			if err := validatePetugasReferences(tx, m.Payload); err != nil {
				return err
			}
			p := m.Payload
			current.NIK, current.Nama, current.Alamat = p.NIK, p.Nama, p.Alamat
			current.TempatLahir, current.TanggalLahir = p.TempatLahir, p.TanggalLahir
			current.JenisKelamin, current.NoTelp, current.Email, current.UserID = p.JenisKelaminID, p.NoTelp, p.Email, p.UserID
			current.Status = 1
		}
		if changed {
			current.UpdatedAt, current.UpdatedBy = &now, &actor
			if exists {
				current.RowVersion++
				// Select all persisted fields to include explicit NULL and zero values.
				if err := tx.Model(&models.Petugas{}).Where("id = ?", current.ID).Select("*").Omit("id", "created_at", "created_by", "jenis_kelamin_nama").Updates(&current).Error; err != nil {
					return err
				}
			} else {
				current.UUID, current.RowVersion, current.CreatedAt, current.CreatedBy = &m.PetugasUUID, 1, &now, &actor
				if err := tx.Omit("jenis_kelamin_nama").Create(&current).Error; err != nil {
					return err
				}
			}
			// Re-read database canonical values (e.g. date columns and triggers).
			if err := tx.Where("id = ?", current.ID).Take(&current).Error; err != nil {
				return err
			}
			payload, err := json.Marshal(current)
			if err != nil {
				return err
			}
			if err := tx.Exec(`INSERT INTO petugas_sync_outbox (petugas_uuid, row_version, tombstone, payload) VALUES (?::uuid, ?, ?, ?::jsonb)`, m.PetugasUUID, current.RowVersion, current.Status != 1 || current.DeletedAt != nil, string(payload)).Error; err != nil {
				return err
			}
		}
		ack = synccontract.PetugasAcknowledgement{MutationID: m.MutationID, PetugasUUID: m.PetugasUUID, ServerID: current.ID, RowVersion: current.RowVersion, Tombstone: current.Status != 1 || current.DeletedAt != nil}
		encoded, err := json.Marshal(ack)
		if err != nil {
			return err
		}
		return tx.Exec(`INSERT INTO petugas_sync_mutations (mutation_id, petugas_uuid, request_hash, acknowledgement) VALUES (?::uuid, ?::uuid, ?, ?::jsonb)`, m.MutationID, m.PetugasUUID, hash, string(encoded)).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		var state interface{ SQLState() string }
		if errors.As(err, &state) && strings.HasPrefix(state.SQLState(), "23") {
			return nil, fmt.Errorf("%w: %w", ErrPetugasConstraint, err)
		}
		return nil, err
	}
	return &ack, nil
}

func checkPetugasVersion(m synccontract.PetugasMutation, exists bool, current *models.Petugas) error {
	if !exists {
		if m.ExpectedRowVersion != nil || m.Operation == synccontract.PetugasDelete {
			return &PetugasVersionConflict{}
		}
		return nil
	}
	if m.ExpectedRowVersion == nil || *m.ExpectedRowVersion != current.RowVersion ||
		(m.Operation == synccontract.PetugasUpsert && (current.Status != 1 || current.DeletedAt != nil)) {
		return &PetugasVersionConflict{Current: current}
	}
	return nil
}

func validatePetugasReferences(tx *gorm.DB, p *synccontract.PetugasPayload) error {
	for _, ref := range []struct {
		table string
		id    *uint
	}{{"jenis_kelamin", p.JenisKelaminID}, {"users", p.UserID}} {
		if ref.id == nil {
			continue
		}
		var row struct{ ID uint }
		// Hold a key-share lock until commit so a concurrent delete cannot invalidate
		// validation even when the deployed legacy schema lacks a foreign key.
		result := tx.Table(ref.table).Select("id").Where("id = ?", *ref.id).Clauses(clause.Locking{Strength: "KEY SHARE"}).Take(&row)
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return fmt.Errorf("%w: %s", ErrPetugasReference, ref.table)
		}
		if result.Error != nil {
			return result.Error
		}
	}
	return nil
}
