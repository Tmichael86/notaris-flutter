package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type PemohonRepository struct {
	db *gorm.DB
}

func NewPemohonRepository() *PemohonRepository {
	return &PemohonRepository{db: database.DB}
}

func (r *PemohonRepository) FindAll() ([]models.Pemohon, error) {
	var items []models.Pemohon
	err := r.db.Table("pemohon").
		Select("pemohon.*, jenis_kelamin.nama AS jenis_kelamin_nama").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = pemohon.jenis_kelamin").
		Where("pemohon.status = ?", 1).
		Order("pemohon.id ASC").
		Find(&items).Error
	return items, err
}

func (r *PemohonRepository) FindByID(id uint) (*models.Pemohon, error) {
	var item models.Pemohon
	err := r.db.Table("pemohon").
		Select("pemohon.*, jenis_kelamin.nama AS jenis_kelamin_nama").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = pemohon.jenis_kelamin").
		First(&item, id).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *PemohonRepository) Create(item *models.Pemohon) error {
	return r.db.Create(item).Error
}

func (r *PemohonRepository) Update(item *models.Pemohon) error {
	return r.db.Model(&models.Pemohon{}).
		Where("id = ?", item.ID).
		Updates(map[string]interface{}{
			"nama":          item.Nama,
			"nik":           item.NIK,
			"jenis_kelamin": item.JenisKelamin,
			"no_telp":       item.NoTelp,
			"alamat":        item.Alamat,
			"updated_by":    item.UpdatedBy,
			"updated_at":    item.UpdatedAt,
			"status":        1,
		}).Error
}

func (r *PemohonRepository) Deactivate(item *models.Pemohon) error {
	return r.db.Model(&models.Pemohon{}).
		Where("id = ?", item.ID).
		Updates(map[string]interface{}{
			"status":     0,
			"updated_by": item.UpdatedBy,
			"updated_at": item.UpdatedAt,
		}).Error
}

func (r *PemohonRepository) FindActiveJenisKelamin() ([]models.JenisKelamin, error) {
	var items []models.JenisKelamin
	err := r.db.Where("status = ?", 1).Order("id ASC").Find(&items).Error
	return items, err
}
