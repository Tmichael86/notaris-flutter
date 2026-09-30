package request

type CreatePetugasRequest struct {
	NIK          string  `json:"nik" binding:"required"`
	UserID       uint    `json:"user_id" binding:"required"`
	Nama         string  `json:"nama" binding:"required"`
	TempatLahir  string  `json:"tempat_lahir" binding:"required"`
	TanggalLahir string  `json:"tanggal_lahir" binding:"required"`
	JenisKelamin uint    `json:"jenis_kelamin" binding:"required"`
	NoTelp       *string `json:"no_telp" binding:"omitempty,numeric"`
	Email        string  `json:"email" binding:"required,email"`
	Alamat       *string `json:"alamat"`
}

type UpdatePetugasRequest struct {
	NIK          string  `json:"nik" binding:"required"`
	UserID       uint    `json:"user_id" binding:"required"`
	Nama         string  `json:"nama" binding:"required"`
	TempatLahir  string  `json:"tempat_lahir" binding:"required"`
	TanggalLahir string  `json:"tanggal_lahir" binding:"required"`
	JenisKelamin uint    `json:"jenis_kelamin" binding:"required"`
	NoTelp       *string `json:"no_telp" binding:"omitempty,numeric"`
	Email        string  `json:"email" binding:"required,email"`
	Alamat       *string `json:"alamat"`
}
