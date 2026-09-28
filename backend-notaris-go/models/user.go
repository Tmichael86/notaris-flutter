package models

import "time"

type User struct {
	ID        uint       `gorm:"primaryKey;column:id" json:"id"`
	GroupID   uint       `gorm:"column:group_id" json:"group_id"`
	Username  string     `gorm:"column:username" json:"username"`
	Password  string     `gorm:"column:password" json:"-"`
	Email     string     `gorm:"column:email" json:"email"`
	Nama      string     `gorm:"column:nama" json:"nama"`
	NoTelp    *string    `gorm:"column:no_telp" json:"no_telp"`
	Alamat    *string    `gorm:"column:alamat" json:"alamat"`
	Image     *string    `gorm:"column:image" json:"image"`
	CreatedBy *uint      `gorm:"column:created_by" json:"created_by"`
	UpdatedBy *uint      `gorm:"column:updated_by" json:"updated_by"`
	CreatedAt *time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:updated_at" json:"updated_at"`
	Status    int16      `gorm:"column:status" json:"status"`
}

func (User) TableName() string {
	return "users"
}
