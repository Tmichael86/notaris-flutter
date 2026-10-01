package request

type CreateKategoriPekerjaanRequest struct {
	Nama string `json:"nama" binding:"required"`
}

type UpdateKategoriPekerjaanRequest struct {
	Nama string `json:"nama" binding:"required"`
}
