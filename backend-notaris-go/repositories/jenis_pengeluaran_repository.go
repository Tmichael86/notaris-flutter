package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type JenisPengeluaranRepository struct {
	db *gorm.DB
}

func NewJenisPengeluaranRepository() *JenisPengeluaranRepository {
	return &JenisPengeluaranRepository{db: database.DB}
}

func (r *JenisPengeluaranRepository) FindAll() ([]models.JenisPengeluaran, error) {
	var items []models.JenisPengeluaran

	err := r.db.
		Where("status = ?", 1).
		Order("id ASC").
		Find(&items).Error

	return items, err
}

func (r *JenisPengeluaranRepository) FindByID(id uint) (*models.JenisPengeluaran, error) {
	var item models.JenisPengeluaran

	err := r.db.First(&item, id).Error
	if err != nil {
		return nil, err
	}

	return &item, nil
}

func (r *JenisPengeluaranRepository) Create(item *models.JenisPengeluaran) error {
	return r.db.Create(item).Error
}

func (r *JenisPengeluaranRepository) Update(item *models.JenisPengeluaran) error {
	return r.db.Save(item).Error
}

func (r *JenisPengeluaranRepository) Deactivate(item *models.JenisPengeluaran) error {
	return r.db.Model(item).Updates(map[string]interface{}{
		"status":     0,
		"updated_by": item.UpdatedBy,
		"updated_at": item.UpdatedAt,
	}).Error
}
