package repositories

import (
	"context"
	"encoding/json"
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PetugasRepository struct {
	db *gorm.DB
}

func NewPetugasRepository() *PetugasRepository {
	return &PetugasRepository{db: database.DB}
}

func (r *PetugasRepository) FindActive(ctx context.Context, page, pageSize int) ([]models.Petugas, int64, error) {
	var items []models.Petugas
	var total int64

	query := r.db.WithContext(ctx).Model(&models.Petugas{}).Where("petugas.status = ?", 1)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	err := r.db.WithContext(ctx).
		Model(&models.Petugas{}).
		Select("petugas.id, petugas.uuid, petugas.row_version, petugas.deleted_at, petugas.nik, petugas.nama, petugas.alamat, petugas.tempat_lahir, petugas.tanggal_lahir, petugas.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, petugas.no_telp, petugas.email, petugas.user_id, petugas.created_by, petugas.updated_by, petugas.created_at, petugas.updated_at, petugas.status").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = petugas.jenis_kelamin").
		Where("petugas.status = ?", 1).
		Order("petugas.nama ASC, petugas.id ASC").
		Limit(pageSize).
		Offset((page - 1) * pageSize).
		Find(&items).Error
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *PetugasRepository) FindActiveByID(ctx context.Context, id uint) (*models.Petugas, error) {
	var item models.Petugas
	err := r.db.WithContext(ctx).
		Model(&models.Petugas{}).
		Select("petugas.id, petugas.uuid, petugas.row_version, petugas.deleted_at, petugas.nik, petugas.nama, petugas.alamat, petugas.tempat_lahir, petugas.tanggal_lahir, petugas.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, petugas.no_telp, petugas.email, petugas.user_id, petugas.created_by, petugas.updated_by, petugas.created_at, petugas.updated_at, petugas.status").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = petugas.jenis_kelamin").
		Where("petugas.id = ? AND petugas.status = ?", id, 1).
		Take(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *PetugasRepository) Create(ctx context.Context, item *models.Petugas, userID uint) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		item.CreatedBy = &userID
		item.CreatedAt = &now
		item.Status = 1
		item.RowVersion = 1
		item.DeletedAt = nil
		// The legacy request has no UUID field. Always allocate server identity here.
		var uuid string
		if err := tx.Raw("SELECT gen_random_uuid()::text").Row().Scan(&uuid); err != nil {
			return err
		}
		item.UUID = &uuid
		if err := tx.Create(item).Error; err != nil {
			return err
		}
		return recordLegacyPetugasEvent(tx, item.ID)
	})
}

func (r *PetugasRepository) Update(ctx context.Context, id uint, input *models.Petugas, userID uint) (*models.Petugas, error) {
	var resultItem *models.Petugas
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current models.Petugas
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}
		now := time.Now()
		updates := map[string]interface{}{
			"nik":           input.NIK,
			"nama":          input.Nama,
			"alamat":        input.Alamat,
			"tempat_lahir":  input.TempatLahir,
			"tanggal_lahir": input.TanggalLahir,
			"jenis_kelamin": input.JenisKelamin,
			"no_telp":       input.NoTelp,
			"email":         input.Email,
			"user_id":       input.UserID,
			"updated_by":    userID,
			"updated_at":    now,
			"row_version":   gorm.Expr("row_version + 1"),
			"uuid":          gorm.Expr("COALESCE(uuid, gen_random_uuid())"),
		}
		result := tx.Model(&models.Petugas{}).Where("id = ? AND status = ?", id, 1).Updates(updates)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		if err := recordLegacyPetugasEvent(tx, id); err != nil {
			return err
		}
		var err error
		resultItem, err = (&PetugasRepository{db: tx}).FindActiveByID(ctx, id)
		return err
	})
	if err != nil {
		return nil, err
	}
	return resultItem, nil
}

func (r *PetugasRepository) Deactivate(ctx context.Context, id, userID uint) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current models.Petugas
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}
		now := time.Now()
		result := tx.Model(&models.Petugas{}).
			Where("id = ? AND status = ?", id, 1).
			Updates(map[string]interface{}{"status": 0, "updated_by": userID, "updated_at": now, "deleted_at": now, "row_version": gorm.Expr("row_version + 1"), "uuid": gorm.Expr("COALESCE(uuid, gen_random_uuid())")})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return recordLegacyPetugasEvent(tx, id)
	})
}

// Read the canonical database row inside the writer's transaction; no mutable
// latest-row lookup is needed later by publisher or pull.
func recordLegacyPetugasEvent(tx *gorm.DB, id uint) error {
	var row models.Petugas
	if err := tx.Where("id = ?", id).Take(&row).Error; err != nil {
		return err
	}
	payload, err := json.Marshal(row)
	if err != nil {
		return err
	}
	return tx.Exec("INSERT INTO petugas_sync_outbox (petugas_uuid,row_version,tombstone,payload) VALUES (?::uuid,?,?,?::jsonb)", row.UUID, row.RowVersion, row.Status != 1 || row.DeletedAt != nil, string(payload)).Error
}
