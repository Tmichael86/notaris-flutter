package models

import "time"

type Sidebar struct {
	ID              uint       `gorm:"primaryKey;column:id" json:"id"`
	SidebarParentID *uint      `gorm:"column:sidebar_parent_id" json:"sidebar_parent_id"`
	SidebarNama     string     `gorm:"column:sidebar_nama" json:"sidebar_nama"`
	SidebarRoute    string     `gorm:"column:sidebar_route" json:"sidebar_route"`
	SidebarKode     string     `gorm:"column:sidebar_kode" json:"sidebar_kode"`
	SidebarIcon     string     `gorm:"column:sidebar_icon" json:"sidebar_icon"`
	SidebarIndex    int32      `gorm:"column:sidebar_index" json:"sidebar_index"`
	CreatedBy       *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy       *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt       *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt       *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status          int16      `gorm:"column:status" json:"status"`
}

func (Sidebar) TableName() string { return "sidebar" }
