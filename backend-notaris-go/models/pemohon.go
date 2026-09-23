package models

import "time"

type Pemohon struct {
	ID           uint       `gorm:"primaryKey;column:id" json:"id"`
	UUID         string     `gorm:"type:uuid;uniqueIndex;column:uuid" json:"uuid"`
	Nama         string     `gorm:"column:nama" json:"nama"`
	NIK          *string    `gorm:"column:nik" json:"nik"`
	Alamat       *string    `gorm:"column:alamat" json:"alamat"`
	JenisKelamin *int       `gorm:"column:jenis_kelamin" json:"jenis_kelamin"`
	Status       *int       `gorm:"column:status" json:"status"`
	IsDirty      bool       `gorm:"column:is_dirty;default:false" json:"is_dirty"`
	LastSyncedAt *time.Time `gorm:"column:last_synced_at" json:"last_synced_at"`
	UpdatedAt    time.Time  `gorm:"column:updated_at" json:"updated_at"`
	DeletedAt    *time.Time `gorm:"column:deleted_at" json:"deleted_at"`
}

func (Pemohon) TableName() string {
	return "pemohon"
}