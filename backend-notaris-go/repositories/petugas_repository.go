package repositories

import (
	"context"
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
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
		Select("petugas.id, petugas.nik, petugas.nama, petugas.alamat, petugas.tempat_lahir, petugas.tanggal_lahir, petugas.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, petugas.no_telp, petugas.email, petugas.user_id, petugas.created_by, petugas.updated_by, petugas.created_at, petugas.updated_at, petugas.status").
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
		Select("petugas.id, petugas.nik, petugas.nama, petugas.alamat, petugas.tempat_lahir, petugas.tanggal_lahir, petugas.jenis_kelamin, jenis_kelamin.nama AS jenis_kelamin_nama, petugas.no_telp, petugas.email, petugas.user_id, petugas.created_by, petugas.updated_by, petugas.created_at, petugas.updated_at, petugas.status").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = petugas.jenis_kelamin").
		Where("petugas.id = ? AND petugas.status = ?", id, 1).
		Take(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *PetugasRepository) Create(ctx context.Context, item *models.Petugas, userID uint) error {
	now := time.Now()
	item.CreatedBy = &userID
	item.CreatedAt = &now
	item.Status = 1
	return r.db.WithContext(ctx).Table("petugas").Create(item).Error
}

func (r *PetugasRepository) Update(ctx context.Context, id uint, input *models.Petugas, userID uint) (*models.Petugas, error) {
	now := time.Now()
	updates := map[string]interface{}{
		"nik": input.NIK,
		"nama": input.Nama,
		"alamat": input.Alamat,
		"tempat_lahir": input.TempatLahir,
		"tanggal_lahir": input.TanggalLahir,
		"jenis_kelamin": input.JenisKelamin,
		"no_telp": input.NoTelp,
		"email": input.Email,
		"user_id": input.UserID,
		"updated_by": userID,
		"updated_at": now,
	}
	result := r.db.WithContext(ctx).Model(&models.Petugas{}).Where("id = ? AND status = ?", id, 1).Updates(updates)
	if result.Error != nil {
		return nil, result.Error
	}
	if result.RowsAffected == 0 {
		return nil, gorm.ErrRecordNotFound
	}
	return r.FindActiveByID(ctx, id)
}

func (r *PetugasRepository) Deactivate(ctx context.Context, id, userID uint) error {
	result := r.db.WithContext(ctx).Model(&models.Petugas{}).
		Where("id = ? AND status = ?", id, 1).
		Updates(map[string]interface{}{"status": 0, "updated_by": userID, "updated_at": time.Now()})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
