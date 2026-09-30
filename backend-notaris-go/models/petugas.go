package models

import "time"

type Petugas struct {
	ID               uint       \`gorm:"primaryKey;column:id" json:"id"\`
	NIK              *string    \`gorm:"column:nik" json:"nik"\`
	Nama             string     \`gorm:"column:nama" json:"nama"\`
	Alamat           *string    \`gorm:"column:alamat" json:"alamat"\`
	TempatLahir      *string    \`gorm:"column:tempat_lahir" json:"tempat_lahir"\`
	TanggalLahir     *time.Time \`gorm:"column:tanggal_lahir" json:"tanggal_lahir"\`
	JenisKelamin     *uint      \`gorm:"column:jenis_kelamin" json:"jenis_kelamin"\`
	JenisKelaminNama string     \`gorm:"column:jenis_kelamin_nama;->" json:"jenis_kelamin_nama,omitempty"\`
	NoTelp           *string    \`gorm:"column:no_telp" json:"no_telp"\`
	Email            string     \`gorm:"column:email" json:"email"\`
	UserID           *uint      \`gorm:"column:user_id" json:"user_id"\`
	UserNama         string     \`gorm:"column:user_nama;->" json:"user_nama,omitempty"\`
	CreatedBy        *uint      \`gorm:"column:created_by" json:"created_by"\`
	UpdatedBy        *uint      \`gorm:"column:updated_by" json:"updated_by"\`
	CreatedAt        *time.Time \`gorm:"column:created_at" json:"created_at"\`
	UpdatedAt        *time.Time \`gorm:"column:updated_at" json:"updated_at"\`
	Status           int16      \`gorm:"column:status" json:"status"\`
}

func (Petugas) TableName() string {
	return "petugas"
}
