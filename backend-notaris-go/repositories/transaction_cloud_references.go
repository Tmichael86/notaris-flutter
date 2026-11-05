package repositories

import (
	"context"
	"errors"

	"gorm.io/gorm"
)

var ErrTransactionCloudReference = errors.New("transaction cloud reference unresolved or inactive")
var ErrTransactionCloudTransactionRequired = errors.New("transaction cloud operation requires an explicit database transaction")

// TransactionCloudReferences contains cloud UUIDs only, never device integer IDs.
// PriceUUID is explicit provenance of the selected price/category; labels are
// historical snapshots and cannot be used to infer this association.
type TransactionCloudReferences struct {
	PemohonUUID string
	PetugasUUID string
	Domain      string
	Jobs        []TransactionCloudJobReference
}
type TransactionCloudJobReference struct {
	JobUUID      string
	PriceUUID    string
	CategoryUUID string
}
type ResolvedTransactionCloudReferences struct {
	PemohonID int64
	PetugasID int64
	Jobs      []ResolvedTransactionCloudJob
}
type ResolvedTransactionCloudJob struct{ JobID, PriceID, CategoryID int64 }

// ResolveTransactionCloudReferences must run INSIDE the eventual aggregate write
// transaction. SHARE locks preserve active references until that transaction
// commits. This helper performs no writes and does not allocate business numbers.
// Authorization belongs to the authenticated service before calling it.
func ResolveTransactionCloudReferences(ctx context.Context, tx *gorm.DB, input TransactionCloudReferences) (*ResolvedTransactionCloudReferences, error) {
	if _, ok := tx.Statement.ConnPool.(gorm.TxCommitter); !ok {
		return nil, ErrTransactionCloudTransactionRequired
	}
	if input.Domain != "notaris" && input.Domain != "ppat" || len(input.Jobs) == 0 || len(input.Jobs) > 500 {
		return nil, ErrTransactionCloudReference
	}
	active := func(table, uuid string) (int64, error) {
		if !notarisCloudUUID.MatchString(uuid) {
			return 0, ErrTransactionCloudReference
		}
		var ids []int64
		if err := tx.WithContext(ctx).Raw("SELECT id FROM "+table+" WHERE uuid=?::uuid AND status=1 AND deleted_at IS NULL FOR SHARE", uuid).Scan(&ids).Error; err != nil {
			return 0, err
		}
		if len(ids) != 1 {
			return 0, ErrTransactionCloudReference
		}
		return ids[0], nil
	}
	result := &ResolvedTransactionCloudReferences{}
	var err error
	if result.PemohonID, err = active("pemohon", input.PemohonUUID); err != nil {
		return nil, err
	}
	if result.PetugasID, err = active("petugas", input.PetugasUUID); err != nil {
		return nil, err
	}
	for _, job := range input.Jobs {
		var row ResolvedTransactionCloudJob
		if row.JobID, err = active("pekerjaan_"+input.Domain, job.JobUUID); err != nil {
			return nil, err
		}
		if row.CategoryID, err = active("pekerjaan_kategori", job.CategoryUUID); err != nil {
			return nil, err
		}
		if !notarisCloudUUID.MatchString(job.PriceUUID) {
			return nil, ErrTransactionCloudReference
		}
		var ids []int64
		if err = tx.WithContext(ctx).Raw("SELECT id FROM pekerjaan_"+input.Domain+"_harga WHERE uuid=?::uuid AND pekerjaan_"+input.Domain+"_id=? AND kategori_pekerjaan_id=? AND status=1 AND deleted_at IS NULL FOR SHARE", job.PriceUUID, row.JobID, row.CategoryID).Scan(&ids).Error; err != nil {
			return nil, err
		}
		if len(ids) != 1 {
			return nil, ErrTransactionCloudReference
		}
		row.PriceID = ids[0]
		result.Jobs = append(result.Jobs, row)
	}
	return result, nil
}
