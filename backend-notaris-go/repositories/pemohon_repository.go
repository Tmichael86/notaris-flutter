package repositories

import (
	"context"

	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type PemohonRepository struct {
	db *gorm.DB
}

func NewPemohonRepository() *PemohonRepository {
	return &PemohonRepository{db: database.DB}
}

func (r *PemohonRepository) FindActive(ctx context.Context, page, pageSize int) ([]models.Pemohon, int64, error) {
	var items []models.Pemohon
	var total int64

	query := r.db.WithContext(ctx).Model(&models.Pemohon{}).Where("status = ?", 1)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := r.db.WithContext(ctx).
		Model(&models.Pemohon{}).
		Select("id, nama, alamat, jenis_kelamin, no_telp, nik, created_by, updated_by, created_at, updated_at, status").
		Where("status = ?", 1).
		Order("nama ASC, id ASC").
		Limit(pageSize).
		Offset(offset).
		Find(&items).Error
	if err != nil {
		return nil, 0, err
	}

	return items, total, nil
}
