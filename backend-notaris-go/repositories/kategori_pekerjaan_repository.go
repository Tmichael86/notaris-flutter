package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type KategoriPekerjaanRepository struct {
	db *gorm.DB
}

func NewKategoriPekerjaanRepository() *KategoriPekerjaanRepository {
	return &KategoriPekerjaanRepository{db: database.DB}
}

func (r *KategoriPekerjaanRepository) FindAll() ([]models.KategoriPekerjaan, error) {
	var items []models.KategoriPekerjaan

	err := r.db.
		Where("status = ?", 1).
		Order("id ASC").
		Find(&items).Error

	return items, err
}

func (r *KategoriPekerjaanRepository) FindByID(id uint) (*models.KategoriPekerjaan, error) {
	var item models.KategoriPekerjaan

	err := r.db.First(&item, id).Error
	if err != nil {
		return nil, err
	}

	return &item, nil
}

func (r *KategoriPekerjaanRepository) Create(item *models.KategoriPekerjaan) error {
	return r.db.Create(item).Error
}

func (r *KategoriPekerjaanRepository) Update(item *models.KategoriPekerjaan) error {
	return r.db.Save(item).Error
}

func (r *KategoriPekerjaanRepository) Deactivate(item *models.KategoriPekerjaan) error {
	return r.db.Model(item).Updates(map[string]interface{}{
		"status":     0,
		"updated_by": item.UpdatedBy,
		"updated_at": item.UpdatedAt,
	}).Error
}
