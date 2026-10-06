package request
type PekerjaanHargaRequest struct { ID *uint `json:"id"`; PekerjaanHargaID *uint `json:"pekerjaan_harga_id"`; Harga string `json:"harga" binding:"required"`; KategoriPekerjaanID uint `json:"kategori_pekerjaan_id" binding:"required"`; EstimasiWaktu string `json:"estimasi_waktu" binding:"required"` }
func(r PekerjaanHargaRequest) ExistingID()*uint{if r.ID!=nil{return r.ID};return r.PekerjaanHargaID}
type PekerjaanAtributRequest struct { ID *uint `json:"id"`; PekerjaanAtributID *uint `json:"proses_pekerjaan_atribut_id"`; Atribut string `json:"atribut"` }
func(r PekerjaanAtributRequest) ExistingID()*uint{if r.ID!=nil{return r.ID};return r.PekerjaanAtributID}
type PekerjaanProsesRequest struct { ID *uint `json:"id"`; ProsesID *uint `json:"proses_id"`; Nama string `json:"nama" binding:"required"`; Detail string `json:"detail" binding:"required"`; Atribut []PekerjaanAtributRequest `json:"atribut"` }
func(r PekerjaanProsesRequest) ExistingID()*uint{if r.ID!=nil{return r.ID};return r.ProsesID}
type PekerjaanRequest struct { Nama string `json:"nama" binding:"required"`; Harga []PekerjaanHargaRequest `json:"harga"`; Proses []PekerjaanProsesRequest `json:"proses"` }
