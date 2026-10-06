package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"
	"gorm.io/gorm"
)

type PekerjaanRepository struct{ db *gorm.DB }

func NewPekerjaanRepository() *PekerjaanRepository { return &PekerjaanRepository{db: database.DB} }
func (r *PekerjaanRepository) FindNotaris(id uint) (*models.PekerjaanNotaris, error) {
	var x models.PekerjaanNotaris
	e := r.db.First(&x, id).Error
	return &x, e
}
func (r *PekerjaanRepository) FindPPAT(id uint) (*models.PekerjaanPPAT, error) {
	var x models.PekerjaanPPAT
	e := r.db.First(&x, id).Error
	return &x, e
}
func (r *PekerjaanRepository) ListNotaris() ([]models.PekerjaanNotaris, error) {
	var x []models.PekerjaanNotaris
	e := r.db.Where("status=?", 1).Order("id ASC").Find(&x).Error
	return x, e
}
func (r *PekerjaanRepository) ListPPAT() ([]models.PekerjaanPPAT, error) {
	var x []models.PekerjaanPPAT
	e := r.db.Where("status=?", 1).Order("id ASC").Find(&x).Error
	return x, e
}
func (r *PekerjaanRepository) SaveNotaris(tx *gorm.DB, x *models.PekerjaanNotaris) error {
	return tx.Save(x).Error
}
func (r *PekerjaanRepository) SavePPAT(tx *gorm.DB, x *models.PekerjaanPPAT) error {
	return tx.Save(x).Error
}
func (r *PekerjaanRepository) CreateNotaris(tx *gorm.DB, x *models.PekerjaanNotaris) error {
	return tx.Create(x).Error
}
func (r *PekerjaanRepository) CreatePPAT(tx *gorm.DB, x *models.PekerjaanPPAT) error {
	return tx.Create(x).Error
}
func (r *PekerjaanRepository) DeleteNotarisChildren(tx *gorm.DB, id uint) error {
	for _, m := range []interface{}{&models.HargaPekerjaanNotaris{}, &models.ProsesPekerjaanNotaris{}, &models.AtributPekerjaanNotaris{}} {
		if e := tx.Where("pekerjaan_notaris_id=?", id).Delete(m).Error; e != nil {
			return e
		}
	}
	return nil
}
func (r *PekerjaanRepository) DeletePPATChildren(tx *gorm.DB, id uint) error {
	for _, m := range []interface{}{&models.HargaPekerjaanPPAT{}, &models.ProsesPekerjaanPPAT{}, &models.AtributPekerjaanPPAT{}} {
		if e := tx.Where("pekerjaan_ppat_id=?", id).Delete(m).Error; e != nil {
			return e
		}
	}
	return nil
}
func (r *PekerjaanRepository) DeactivateNotaris(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Model(&models.PekerjaanNotaris{}).Where("id=?", id).Updates(map[string]interface{}{"status": 0, "updated_by": user, "updated_at": now}).Error
}
func (r *PekerjaanRepository) DeactivatePPAT(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Model(&models.PekerjaanPPAT{}).Where("id=?", id).Updates(map[string]interface{}{"status": 0, "updated_by": user, "updated_at": now}).Error
}
func (r *PekerjaanRepository) DeactivateNotarisChildren(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_notaris_proses SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_notaris_id=?", user, now, id).Error
}
func (r *PekerjaanRepository) DeactivateNotarisHarga(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_notaris_harga SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_notaris_id=?", user, now, id).Error
}
func (r *PekerjaanRepository) DeactivateNotarisAtribut(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_notaris_atributs SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_notaris_id=?", user, now, id).Error
}
func (r *PekerjaanRepository) DeactivatePPATChildren(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_ppat_proses SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_ppat_id=?", user, now, id).Error
}
func (r *PekerjaanRepository) DeactivatePPATHarga(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_ppat_harga SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_ppat_id=?", user, now, id).Error
}
func (r *PekerjaanRepository) DeactivatePPATAtribut(tx *gorm.DB, id, user uint, now interface{}) error {
	return tx.Exec("UPDATE pekerjaan_ppat_atributs SET status=0,updated_by=?,updated_at=? WHERE pekerjaan_ppat_id=?", user, now, id).Error
}
