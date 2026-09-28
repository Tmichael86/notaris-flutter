package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type GroupRepository struct {
	db *gorm.DB
}

func NewGroupRepository() *GroupRepository {
	return &GroupRepository{
		db: database.DB,
	}
}

func (r *GroupRepository) FindAll() ([]models.Group, error) {
	var groups []models.Group

	err := r.db.
		Where("status = ?", 1).
		Order("id ASC").
		Find(&groups).Error

	return groups, err
}

func (r *GroupRepository) FindByID(id uint) (*models.Group, error) {
	var group models.Group

	err := r.db.First(&group, id).Error
	if err != nil {
		return nil, err
	}

	return &group, nil
}

func (r *GroupRepository) Create(group *models.Group) error {
	return r.db.Create(group).Error
}

func (r *GroupRepository) Update(group *models.Group) error {
	return r.db.Save(group).Error
}

func (r *GroupRepository) Deactivate(group *models.Group) error {
	return r.db.Model(group).Update("status", 0).Error
}
