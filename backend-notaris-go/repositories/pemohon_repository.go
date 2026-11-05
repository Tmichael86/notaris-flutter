package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrDuplicatePemohonNIK = errors.New("active pemohon NIK already exists")

type PemohonRepository struct {
	db *gorm.DB
}

func NewPemohonRepository() *PemohonRepository {
	return &PemohonRepository{db: database.DB}
}

func (r *PemohonRepository) FindActive(ctx context.Context, page, pageSize int) ([]models.Pemohon, int64, error) {
	var items []models.Pemohon
	var total int64

	query := r.db.WithContext(ctx).Model(&models.Pemohon{}).Where("pemohon.status = ?", 1)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	err := r.db.WithContext(ctx).
		Model(&models.Pemohon{}).
		Select("pemohon.id, pemohon.uuid, pemohon.nama, pemohon.alamat, pemohon.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, pemohon.no_telp, pemohon.nik, pemohon.created_by, pemohon.updated_by, pemohon.created_at, pemohon.updated_at, pemohon.status, pemohon.is_dirty, pemohon.last_synced_at, pemohon.deleted_at").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = pemohon.jenis_kelamin").
		Where("pemohon.status = ?", 1).
		Order("pemohon.nama ASC, pemohon.id ASC").
		Limit(pageSize).
		Offset((page - 1) * pageSize).
		Find(&items).Error
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *PemohonRepository) FindActiveByID(ctx context.Context, id uint64) (*models.Pemohon, error) {
	var item models.Pemohon
	err := r.db.WithContext(ctx).
		Model(&models.Pemohon{}).
		Select("pemohon.id, pemohon.uuid, pemohon.nama, pemohon.alamat, pemohon.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, pemohon.no_telp, pemohon.nik, pemohon.created_by, pemohon.updated_by, pemohon.created_at, pemohon.updated_at, pemohon.status, pemohon.is_dirty, pemohon.last_synced_at, pemohon.deleted_at").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = pemohon.jenis_kelamin").
		Where("pemohon.id = ? AND pemohon.status = ?", id, 1).
		Take(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *PemohonRepository) FindJenisKelaminIDByName(ctx context.Context, name string) (int, error) {
	var id int
	err := r.db.WithContext(ctx).Table("jenis_kelamin").Select("id").
		Where("LOWER(TRIM(nama)) = LOWER(TRIM(?)) AND status = ?", name, 1).Take(&id).Error
	return id, err
}

func (r *PemohonRepository) JenisKelaminExists(ctx context.Context, id int) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Table("jenis_kelamin").Where("id = ?", id).Count(&count).Error
	return count > 0, err
}

func (r *PemohonRepository) UpsertByUUID(
	ctx context.Context,
	uuid string,
	input *models.Pemohon,
	userID uint,
) (*models.Pemohon, error) {
	var item models.Pemohon

	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Serialize requests for the same UUID, including first-time inserts.
		if err := tx.Exec(
			"SELECT pg_advisory_xact_lock(hashtext(?))",
			"pemohon:uuid:"+uuid,
		).Error; err != nil {
			return err
		}

		var current models.Pemohon
		findErr := tx.Table("pemohon").
			Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("uuid = ?", uuid).
			Take(&current).Error

		if findErr != nil && !errors.Is(findErr, gorm.ErrRecordNotFound) {
			return findErr
		}

		// Never silently resurrect a previously deactivated record.
		if findErr == nil && current.Status != 1 {
			return gorm.ErrRecordNotFound
		}

		if input.NIK != nil && strings.TrimSpace(*input.NIK) != "" {
			if err := lockPemohonNIK(tx, *input.NIK); err != nil {
				return err
			}

			query := tx.Table("pemohon").
				Where(
					"status = ? AND regexp_replace(nik, '[^0-9]', '', 'g') = ?",
					1,
					*input.NIK,
				)

			if findErr == nil {
				query = query.Where("uuid <> ?", uuid)
			}

			var count int64
			if err := query.Count(&count).Error; err != nil {
				return err
			}
			if count > 0 {
				return ErrDuplicatePemohonNIK
			}
		}

		now := time.Now()

		if errors.Is(findErr, gorm.ErrRecordNotFound) {
			item = models.Pemohon{
				UUID:         uuid,
				Nama:         input.Nama,
				Alamat:       input.Alamat,
				JenisKelamin: input.JenisKelamin,
				NoTelp:       input.NoTelp,
				NIK:          input.NIK,
				CreatedBy:    &userID,
				CreatedAt:    &now,
				UpdatedAt:    &now,
				Status:       1,
				IsDirty:      false,
				LastSyncedAt: &now,
			}

			return tx.Table("pemohon").Create(&item).Error
		}

		updates := map[string]interface{}{
			"nama":           input.Nama,
			"alamat":         input.Alamat,
			"jenis_kelamin":  input.JenisKelamin,
			"no_telp":        input.NoTelp,
			"nik":            input.NIK,
			"updated_by":     userID,
			"updated_at":     now,
			"is_dirty":       false,
			"last_synced_at": now,
		}

		if err := tx.Table("pemohon").
			Where("uuid = ? AND status = ?", uuid, 1).
			Updates(updates).Error; err != nil {
			return err
		}

		return tx.Table("pemohon").
			Where("uuid = ?", uuid).
			Take(&item).Error
	})

	if err != nil {
		return nil, err
	}

	return r.FindActiveByUUID(ctx, uuid)
}

func (r *PemohonRepository) FindActiveByUUID(
	ctx context.Context,
	uuid string,
) (*models.Pemohon, error) {
	var item models.Pemohon

	err := r.db.WithContext(ctx).
		Model(&models.Pemohon{}).
		Select("pemohon.id, pemohon.uuid, pemohon.nama, pemohon.alamat, pemohon.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, pemohon.no_telp, pemohon.nik, pemohon.created_by, pemohon.updated_by, pemohon.created_at, pemohon.updated_at, pemohon.status, pemohon.is_dirty, pemohon.last_synced_at, pemohon.deleted_at").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = pemohon.jenis_kelamin").
		Where("pemohon.uuid = ? AND pemohon.status = ?", uuid, 1).
		Take(&item).Error

	if err != nil {
		return nil, err
	}

	return &item, nil
}

func (r *PemohonRepository) DeactivateByUUID(
	ctx context.Context,
	uuid string,
	userID uint,
) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(
			"SELECT pg_advisory_xact_lock(hashtext(?))",
			"pemohon:uuid:"+uuid,
		).Error; err != nil {
			return err
		}

		var current models.Pemohon
		err := tx.Table("pemohon").
			Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("uuid = ?", uuid).
			Take(&current).Error

		if errors.Is(err, gorm.ErrRecordNotFound) {
			return gorm.ErrRecordNotFound
		}
		if err != nil {
			return err
		}

		// A repeated delete for an existing inactive record is successful.
		if current.Status != 1 {
			return nil
		}

		now := time.Now()
		return tx.Table("pemohon").
			Where("uuid = ? AND status = ?", uuid, 1).
			Updates(map[string]interface{}{
				"status":         0,
				"updated_by":     userID,
				"updated_at":     now,
				"deleted_at":     now,
				"is_dirty":       false,
				"last_synced_at": now,
			}).Error
	})
}

func (r *PemohonRepository) Create(ctx context.Context, item *models.Pemohon, userID uint) (*models.Pemohon, error) {
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if item.NIK != nil && strings.TrimSpace(*item.NIK) != "" {
			if err := lockPemohonNIK(tx, *item.NIK); err != nil {
				return err
			}
			var count int64
			if err := tx.Table("pemohon").Where("status = ? AND regexp_replace(nik, '[^0-9]', '', 'g') = ?", 1, *item.NIK).Count(&count).Error; err != nil {
				return err
			}
			if count > 0 {
				return ErrDuplicatePemohonNIK
			}
		}
		now := time.Now()
		item.CreatedBy = &userID
		item.CreatedAt = &now
		item.Status = 1
		return tx.Table("pemohon").Create(item).Error
	})
	if err != nil {
		return nil, err
	}
	return r.FindActiveByID(ctx, uint64(item.ID))
}

func (r *PemohonRepository) Update(ctx context.Context, id uint64, input *models.Pemohon, userID uint) (*models.Pemohon, error) {
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current models.Pemohon
		if err := tx.Table("pemohon").Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}

		if input.NIK != nil && strings.TrimSpace(*input.NIK) != "" {
			if err := lockPemohonNIK(tx, *input.NIK); err != nil {
				return err
			}
			var count int64
			if err := tx.Table("pemohon").
				Where("status = ? AND regexp_replace(nik, '[^0-9]', '', 'g') = ? AND id <> ?", 1, *input.NIK, id).
				Count(&count).Error; err != nil {
				return err
			}
			if count > 0 {
				return ErrDuplicatePemohonNIK
			}
		}

		now := time.Now()
		updates := map[string]interface{}{
			"nama":          input.Nama,
			"alamat":        input.Alamat,
			"jenis_kelamin": input.JenisKelamin,
			"no_telp":       input.NoTelp,
			"nik":           input.NIK,
			"updated_by":    userID,
			"updated_at":    now,
		}
		result := tx.Table("pemohon").Where("id = ? AND status = ?", id, 1).Updates(updates)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return r.FindActiveByID(ctx, id)
}

func (r *PemohonRepository) Deactivate(ctx context.Context, id uint64, userID uint) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current models.Pemohon
		if err := tx.Table("pemohon").Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}
		result := tx.Table("pemohon").Where("id = ? AND status = ?", id, 1).
			Updates(map[string]interface{}{"status": 0, "updated_by": userID, "updated_at": time.Now()})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
}

func lockPemohonNIK(tx *gorm.DB, nik string) error {
	key := fmt.Sprintf("pemohon:nik:%s", strings.TrimSpace(nik))
	return tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", key).Error
}
