package models

import "time"

type SidebarAccess struct {
	ID        uint       `gorm:"primaryKey;column:id" json:"id"`
	SidebarID uint       `gorm:"column:sidebar_id" json:"sidebar_id"`
	GroupID   uint       `gorm:"column:group_id" json:"group_id"`
	Read      int16      `gorm:"column:read" json:"read"`
	Create   int16      `gorm:"column:create" json:"create"`
	Update   int16      `gorm:"column:update" json:"update"`
	Delete   int16      `gorm:"column:delete" json:"delete"`
	CreatedBy *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:updated_at" json:"updated_at"`
}

func (SidebarAccess) TableName() string { return "sidebar_akses" }
