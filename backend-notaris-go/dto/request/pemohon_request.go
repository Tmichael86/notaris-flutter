package request

type CreatePemohonRequest struct {
	Nama         string  `json:"nama" binding:"required"`
	NIK          string  `json:"nik" binding:"required"`
	JenisKelamin int     `json:"jenis_kelamin" binding:"required"`
	NoTelp       *string `json:"no_telp" binding:"omitempty,numeric"`
	Alamat       *string `json:"alamat"`
}

type UpdatePemohonRequest struct {
	Nama         string  `json:"nama" binding:"required"`
	NIK          string  `json:"nik" binding:"required"`
	JenisKelamin int     `json:"jenis_kelamin" binding:"required"`
	NoTelp       *string `json:"no_telp" binding:"omitempty,numeric"`
	Alamat       *string `json:"alamat"`
}
