package services

import (
	"backend-notaris-go/database"
	"context"
	"database/sql"
	"errors"
	"strconv"
)

// OfficeAmount is an exact unsigned integer serialized as a decimal string.
// JSON floating-point clients must not round authoritative reference amounts.
type OfficeAmount uint64

func (n OfficeAmount) MarshalJSON() ([]byte, error) {
	return []byte(`"` + strconv.FormatUint(uint64(n), 10) + `"`), nil
}

type OfficeConfiguration struct {
	ID                         int64         `json:"id"`
	Alamat                     *string       `json:"alamat"`
	TelpRumah                  *string       `json:"telp_rumah"`
	TelpPertama                *string       `json:"telp_pertama"`
	TelpKedua                  *string       `json:"telp_kedua"`
	Email                      *string       `json:"email"`
	NotarisBersangkutan        *string       `json:"notaris_bersangkutan"`
	PPATBersangkutan           *string       `json:"ppat_bersangkutan"`
	BesaranNilaiTidakKenaPajak *OfficeAmount `json:"besaran_nilai_tidak_kena_pajak"`
	Pengecekan                 *OfficeAmount `json:"pengecekan"`
	SKMHT                      *OfficeAmount `json:"surat_kuasa_membebankan_hak_tanggungan"`
	PlotingValidasi            *OfficeAmount `json:"ploting_validasi"`
	HargaBeliMaterai           *OfficeAmount `json:"harga_beli_materai"`
	HargaJualMaterai           *OfficeAmount `json:"harga_jual_materai"`
	DevelopmentData            bool          `json:"development_data"`
}

var ErrOfficeMissing = errors.New("configuration_missing")
var ErrOfficeAmbiguous = errors.New("configuration_ambiguous")
var ErrOfficeInvalid = errors.New("configuration_invalid")

// One SELECT observes cardinality and all fields in the same statement snapshot.
// Count inactive rows too: a second row must never silently become a fallback.
func ReadOfficeConfiguration(ctx context.Context) (*OfficeConfiguration, error) {
	rows, err := database.DB.WithContext(ctx).Raw(`SELECT id,status,alamat,telp_rumah,telp_pertama,telp_kedua,email,notaris_bersangkutan,ppat_bersangkutan,
 besaran_nilai_tidak_kena_pajak::text,pengecekan::text,surat_kuasa_membebankan_hak_tanggungan::text,ploting_validasi::text,harga_beli_materai::text,harga_jual_materai::text
 FROM konfigurasi_umum ORDER BY id LIMIT 2`).Rows()
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var result *OfficeConfiguration
	for rows.Next() {
		if result != nil {
			return nil, ErrOfficeAmbiguous
		}
		var id int64
		var status sql.NullInt64
		var texts [7]sql.NullString
		var amounts [6]sql.NullString
		err = rows.Scan(&id, &status, &texts[0], &texts[1], &texts[2], &texts[3], &texts[4], &texts[5], &texts[6], &amounts[0], &amounts[1], &amounts[2], &amounts[3], &amounts[4], &amounts[5])
		if err != nil {
			return nil, ErrOfficeInvalid
		}
		result = &OfficeConfiguration{ID: id}
		// Defer row validation until cardinality is established.
		if id != 1 || !status.Valid || status.Int64 != 1 {
			result.ID = 0
		}
		out := []**string{&result.Alamat, &result.TelpRumah, &result.TelpPertama, &result.TelpKedua, &result.Email, &result.NotarisBersangkutan, &result.PPATBersangkutan}
		for i, v := range texts {
			if v.Valid {
				s := v.String
				*out[i] = &s
			}
		}
		nums := []**OfficeAmount{&result.BesaranNilaiTidakKenaPajak, &result.Pengecekan, &result.SKMHT, &result.PlotingValidasi, &result.HargaBeliMaterai, &result.HargaJualMaterai}
		for i, v := range amounts {
			if v.Valid {
				n, e := strconv.ParseUint(v.String, 10, 64)
				if e != nil {
					return nil, ErrOfficeInvalid
				}
				value := OfficeAmount(n)
				*nums[i] = &value
			}
		}
		result.DevelopmentData = result.NotarisBersangkutan != nil && *result.NotarisBersangkutan == "NOTARISDEV SYNTHETIC v1"
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	if result == nil {
		return nil, ErrOfficeMissing
	}
	if result.ID != 1 {
		return nil, ErrOfficeInvalid
	}
	return result, nil
}
