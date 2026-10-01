package request

type CreateJenisPengeluaranRequest struct {
	Nama string `json:"nama" binding:"required"`
}

type UpdateJenisPengeluaranRequest struct {
	Nama string `json:"nama" binding:"required"`
}
