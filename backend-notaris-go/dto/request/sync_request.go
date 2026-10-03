package request

type TransaksiSyncRequest struct {
	UUID        string  `json:"uuid" binding:"required"`
	NoAkta      string  `json:"no_akta" binding:"required"`
	Total       float64 `json:"total"`
	PemohonUUID *string `json:"pemohon_uuid"`
}

type SyncPushRequest struct {
	Transaksis []TransaksiSyncRequest `json:"transaksis"`
}
