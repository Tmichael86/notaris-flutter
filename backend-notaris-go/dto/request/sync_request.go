package request

type PemohonSyncRequest struct {
	UUID   string  `json:"uuid" binding:"required"`
	Nama   string  `json:"nama" binding:"required"`
	NIK    *string `json:"nik"`
	Alamat *string `json:"alamat"`
}

type TransaksiSyncRequest struct {
	UUID        string  `json:"uuid" binding:"required"`
	NoAkta      string  `json:"no_akta" binding:"required"`
	Total       float64 `json:"total"`
	PemohonUUID *string `json:"pemohon_uuid"`
}

type SyncPushRequest struct {
	Pemohons   []PemohonSyncRequest   `json:"pemohons"`
	Transaksis []TransaksiSyncRequest `json:"transaksis"`
}
