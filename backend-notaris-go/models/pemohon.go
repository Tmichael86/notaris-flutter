package models

import (
	"time"

	"github.com/google/uuid"
)

type Pemohon struct {
	ID               uint       `gorm:"primaryKey;column:id" json:"id"`
	Nama             string     `gorm:"column:nama" json:"nama"`
	Alamat           *string    `gorm:"column:alamat" json:"alamat"`
	JenisKelamin     *int       `gorm:"column:jenis_kelamin" json:"jenis_kelamin"`
	JenisKelaminNama string     `gorm:"column:jenis_kelamin_nama;->" json:"jenis_kelamin_nama,omitempty"`
	NoTelp           *string    `gorm:"column:no_telp" json:"no_telp"`
	NIK              *string    `gorm:"column:nik" json:"nik"`
	CreatedBy        *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy        *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt        *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt        *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status           int16      `gorm:"column:status" json:"status"`
	UUID             *uuid.UUID `gorm:"type:uuid;column:uuid" json:"uuid,omitempty"`
	IsDirty          *bool      `gorm:"column:is_dirty" json:"is_dirty,omitempty"`
	LastSyncedAt     *time.Time `gorm:"column:last_synced_at" json:"last_synced_at,omitempty"`
	DeletedAt        *time.Time `gorm:"column:deleted_at" json:"deleted_at,omitempty"`
}

func (Pemohon) TableName() string {
	return "pemohon"
}
