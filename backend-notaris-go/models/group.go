package models

import "time"

type Group struct {
	ID         uint       `gorm:"primaryKey;column:id" json:"id"`
	GroupNama  string     `gorm:"column:group_nama" json:"group_nama"`
	GroupJenis string     `gorm:"column:group_jenis" json:"group_jenis"`
	CreatedBy  *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy  *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt  *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt  *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status     int16      `gorm:"column:status" json:"status"`
}

func (Group) TableName() string {
	return "groups"
}
