package models

import "time"

type JenisKelamin struct {
	ID        uint       `gorm:"primaryKey;column:id" json:"id"`
	Nama      string     `gorm:"column:nama" json:"nama"`
	CreatedBy *uint      `gorm:"column:created_by" json:"created_by,omitempty"`
	UpdatedBy *uint      `gorm:"column:updated_by" json:"updated_by,omitempty"`
	CreatedAt *time.Time `gorm:"column:created_at" json:"created_at,omitempty"`
	UpdatedAt *time.Time `gorm:"column:updated_at" json:"updated_at,omitempty"`
	Status    int16      `gorm:"column:status" json:"status"`
}

func (JenisKelamin) TableName() string {
	return "jenis_kelamin"
}
