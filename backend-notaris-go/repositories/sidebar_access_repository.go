package repositories

import (
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type SidebarAccessRepository struct { db *gorm.DB }

func NewSidebarAccessRepository() *SidebarAccessRepository {
	return &SidebarAccessRepository{db: database.DB}
}

func (r *SidebarAccessRepository) FindByGroupID(groupID uint) ([]models.SidebarAccess, error) {
	var access []models.SidebarAccess
	err := r.db.Where("group_id = ?", groupID).
		Order("sidebar_id ASC").
		Find(&access).Error
	return access, err
}

func (r *SidebarAccessRepository) ReplaceForGroup(tx *gorm.DB, groupID, userID uint, items []request.SidebarAccessItem) error {
	if err := tx.Where("group_id = ?", groupID).Delete(&models.SidebarAccess{}).Error; err != nil {
		return err
	}
	if len(items) == 0 { return nil }

	now := time.Now()
	access := make([]models.SidebarAccess, 0, len(items))
	for _, item := range items {
		uid := userID
		access = append(access, models.SidebarAccess{
			SidebarID: item.SidebarID,
			GroupID: groupID,
			Read: item.Read,
			Create: item.Create,
			Update: item.Update,
			Delete: item.Delete,
			CreatedBy: &uid,
			UpdatedBy: &uid,
			CreatedAt: &now,
			UpdatedAt: &now,
		})
	}
	return tx.Create(&access).Error
}
