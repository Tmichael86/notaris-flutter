package models

import "time"

type JenisPengeluaran struct {
	ID        uint       `gorm:"primaryKey;column:id" json:"id"`
	Nama      string     `gorm:"column:nama" json:"nama"`
	CreatedBy *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status    int16      `gorm:"column:status" json:"status"`
}

func (JenisPengeluaran) TableName() string {
	return "pengeluaran_jenis"
}
