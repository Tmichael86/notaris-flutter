package models

import "time"

type Transaksi struct {
	ID           uint       `gorm:"primaryKey;column:id" json:"id"`
	UUID         string     `gorm:"type:uuid;uniqueIndex;column:uuid" json:"uuid"`
	NoAkta       string     `gorm:"column:no_akta" json:"no_akta"`
	Total        float64    `gorm:"column:total" json:"total"`
	PemohonUUID  *string    `gorm:"column:pemohon_uuid" json:"pemohon_uuid"`
	IsDirty      bool       `gorm:"column:is_dirty;default:false" json:"is_dirty"`
	LastSyncedAt *time.Time `gorm:"column:last_synced_at" json:"last_synced_at"`
	UpdatedAt    time.Time  `gorm:"column:updated_at" json:"updated_at"`
	DeletedAt    *time.Time `gorm:"column:deleted_at" json:"deleted_at"`
}

func (Transaksi) TableName() string {
	return "transaksi"
}
