package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type SidebarRepository struct { db *gorm.DB }

func NewSidebarRepository() *SidebarRepository {
	return &SidebarRepository{db: database.DB}
}

func (r *SidebarRepository) FindAllActive() ([]models.Sidebar, error) {
	var sidebars []models.Sidebar
	err := r.db.Where("status = ?", 1).
		Order("sidebar_parent_id ASC").
		Order("sidebar_index ASC").
		Order("id ASC").
		Find(&sidebars).Error
	return sidebars, err
}

func (r *SidebarRepository) FindByID(id uint) (*models.Sidebar, error) {
	var sidebar models.Sidebar
	err := r.db.First(&sidebar, id).Error
	if err != nil { return nil, err }
	return &sidebar, nil
}
