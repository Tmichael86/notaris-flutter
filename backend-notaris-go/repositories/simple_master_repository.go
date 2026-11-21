package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend-notaris-go/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrDuplicateMasterName = errors.New("active master name already exists")

type SimpleMasterRecord struct {
	ID        uint64     `gorm:"column:id" json:"id"`
	UUID      string     `gorm:"column:uuid;default:gen_random_uuid()" json:"uuid"`
	Nama      string     `gorm:"column:nama" json:"nama"`
	CreatedBy *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status    int16      `gorm:"column:status" json:"status"`
}

type SimpleMasterRepository struct {
	db    *gorm.DB
	table string
}

func NewSimpleMasterRepository(table string) *SimpleMasterRepository {
	switch table {
	case "pekerjaan_kategori", "pengeluaran_jenis":
	default:
		panic("unsupported simple master table: " + table)
	}
	return &SimpleMasterRepository{db: database.DB, table: table}
}

func (r *SimpleMasterRepository) FindActive(ctx context.Context, page, pageSize int) ([]SimpleMasterRecord, int64, error) {
	var items []SimpleMasterRecord
	var total int64
	if err := r.db.WithContext(ctx).Table(r.table).Where("status = ?", 1).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := r.db.WithContext(ctx).Table(r.table).
		Select("id, uuid, nama, created_by, updated_by, created_at, updated_at, status").
		Where("status = ?", 1).Order("nama ASC, id ASC").
		Limit(pageSize).Offset((page - 1) * pageSize).Find(&items).Error
	return items, total, err
}

func (r *SimpleMasterRepository) FindActiveByID(ctx context.Context, id uint64) (*SimpleMasterRecord, error) {
	var item SimpleMasterRecord
	err := r.db.WithContext(ctx).Table(r.table).Where("id = ? AND status = ?", id, 1).Take(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *SimpleMasterRepository) FindActiveByUUID(ctx context.Context, uuid string) (*SimpleMasterRecord, error) {
	var item SimpleMasterRecord
	err := r.db.WithContext(ctx).Table(r.table).Where("uuid = ? AND status = ?", uuid, 1).Take(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

// Sync keeps the existing UUID upsert wire contract, but authorizes the actual
// operation while holding both the UUID and administrative permission locks.
func (r *SimpleMasterRepository) UpsertByUUID(ctx context.Context, uuid, nama string, userID uint) (*SimpleMasterRecord, error) {
	return r.writeUUID(ctx, uuid, nama, userID, false)
}

// POST is CREATE-only, including when the client supplies a UUID.
func (r *SimpleMasterRepository) CreateByUUID(ctx context.Context, uuid, nama string, userID uint) (*SimpleMasterRecord, error) {
	return r.writeUUID(ctx, uuid, nama, userID, true)
}

func (r *SimpleMasterRepository) permissionCode() string {
	if r.table == "pekerjaan_kategori" {
		return "kategori_pekerjaan"
	}
	if r.table == "pengeluaran_jenis" {
		return "jenis_pengeluaran"
	}
	return ""
}

func (r *SimpleMasterRepository) writeUUID(ctx context.Context, uuid, nama string, userID uint, createOnly bool) (*SimpleMasterRecord, error) {
	uuid = strings.ToLower(strings.TrimSpace(uuid))
	nama = strings.TrimSpace(nama)
	if !mutationUUIDPattern.MatchString(uuid) {
		return nil, ErrInvalidMutationInput
	}
	var item SimpleMasterRecord
	err := authorizedMasterMutation(ctx, r.db, userID, r.permissionCode(), func(tx *gorm.DB, access *mutationAccess) error {
		if err := tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", r.table+":uuid:"+uuid).Error; err != nil {
			return err
		}
		var current SimpleMasterRecord
		findErr := tx.Table(r.table).Clauses(clause.Locking{Strength: "UPDATE"}).Where("uuid = ?", uuid).Take(&current).Error
		if findErr != nil && !errors.Is(findErr, gorm.ErrRecordNotFound) {
			return findErr
		}
		exists := findErr == nil
		equal := exists && current.Nama == nama
		initialOwn := exists && current.CreatedBy != nil && *current.CreatedBy == userID && current.UpdatedBy == nil
		if !exists || createOnly {
			if err := access.require("create"); err != nil {
				return err
			}
		} else if err := access.existing(equal, initialOwn); err != nil {
			return err
		}
		if exists {
			if current.Status != 1 {
				if createOnly {
					return ErrMasterUUIDConflict
				}
				return gorm.ErrRecordNotFound
			}
			if createOnly && !(equal && initialOwn) {
				return ErrMasterUUIDConflict
			}
			if equal {
				item = current
				return nil
			}
		}
		if nama == "" {
			return ErrInvalidMutationInput
		}
		if err := lockMasterName(tx, r.table, nama); err != nil {
			return err
		}
		query := tx.Table(r.table).Where("status = 1 AND lower(btrim(nama)) = lower(btrim(?))", nama)
		if exists {
			query = query.Where("id <> ?", current.ID)
		}
		var count int64
		if err := query.Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return ErrDuplicateMasterName
		}
		now := time.Now()
		if !exists {
			item = SimpleMasterRecord{UUID: uuid, Nama: nama, CreatedBy: &userID, CreatedAt: &now, Status: 1}
			return tx.Table(r.table).Create(&item).Error
		}
		if err := tx.Table(r.table).Where("id = ?", current.ID).Updates(map[string]interface{}{"nama": nama, "updated_by": userID, "updated_at": now}).Error; err != nil {
			return err
		}
		return tx.Table(r.table).Where("id = ?", current.ID).Take(&item).Error
	})
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *SimpleMasterRepository) DeactivateByUUID(ctx context.Context, uuid string, userID uint) error {
	db := r.db.WithContext(ctx)
	result := db.Table(r.table).Where("uuid = ? AND status = ?", uuid, 1).
		Updates(map[string]interface{}{"status": 0, "updated_by": userID, "updated_at": time.Now()})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected > 0 {
		return nil
	}

	// Treat a retry for an already-inactive UUID as success.
	var exists int64
	if err := db.Table(r.table).Where("uuid = ?", uuid).Count(&exists).Error; err != nil {
		return err
	}
	if exists > 0 {
		return nil
	}
	return gorm.ErrRecordNotFound
}

func (r *SimpleMasterRepository) Create(ctx context.Context, nama string, userID uint) (*SimpleMasterRecord, error) {
	var item SimpleMasterRecord
	err := authorizedMasterMutation(ctx, r.db, userID, r.permissionCode(), func(tx *gorm.DB, access *mutationAccess) error {
		if err := access.require("create"); err != nil {
			return err
		}
		if strings.TrimSpace(nama) == "" {
			return ErrInvalidMutationInput
		}
		if err := lockMasterName(tx, r.table, nama); err != nil {
			return err
		}
		var count int64
		if err := tx.Table(r.table).Where("status = ? AND lower(btrim(nama)) = lower(btrim(?))", 1, nama).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return ErrDuplicateMasterName
		}
		now := time.Now()
		item = SimpleMasterRecord{Nama: nama, CreatedBy: &userID, CreatedAt: &now, Status: 1}
		return tx.Table(r.table).Create(&item).Error
	})
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *SimpleMasterRepository) Update(ctx context.Context, id uint64, nama string, userID uint) (*SimpleMasterRecord, error) {
	var item SimpleMasterRecord
	err := authorizedMasterMutation(ctx, r.db, userID, r.permissionCode(), func(tx *gorm.DB, access *mutationAccess) error {
		if err := access.require("update"); err != nil {
			return err
		}
		if strings.TrimSpace(nama) == "" {
			return ErrInvalidMutationInput
		}
		var current SimpleMasterRecord
		if err := tx.Table(r.table).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}
		if err := lockMasterName(tx, r.table, nama); err != nil {
			return err
		}
		var count int64
		if err := tx.Table(r.table).Where("status = ? AND lower(btrim(nama)) = lower(btrim(?)) AND id <> ?", 1, nama, id).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return ErrDuplicateMasterName
		}
		now := time.Now()
		if err := tx.Table(r.table).Where("id = ? AND status = ?", id, 1).Updates(map[string]interface{}{"nama": nama, "updated_by": userID, "updated_at": now}).Error; err != nil {
			return err
		}
		return tx.Table(r.table).Where("id = ?", id).Take(&item).Error
	})
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *SimpleMasterRepository) Deactivate(ctx context.Context, id uint64, userID uint) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current SimpleMasterRecord
		if err := tx.Table(r.table).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND status = ?", id, 1).Take(&current).Error; err != nil {
			return err
		}
		result := tx.Table(r.table).Where("id = ? AND status = ?", id, 1).Updates(map[string]interface{}{"status": 0, "updated_by": userID, "updated_at": time.Now()})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
}

func lockMasterName(tx *gorm.DB, table, nama string) error {
	key := fmt.Sprintf("%s:%s", table, strings.ToLower(strings.TrimSpace(nama)))
	return tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", key).Error
}
