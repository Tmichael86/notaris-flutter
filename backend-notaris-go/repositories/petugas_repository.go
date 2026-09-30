package repositories

import (
	"backend-notaris-go/database"
	"backend-notaris-go/models"

	"gorm.io/gorm"
)

type PetugasRepository struct {
	db *gorm.DB
}

func NewPetugasRepository() *PetugasRepository {
	return &PetugasRepository{db: database.DB}
}

func (r *PetugasRepository) FindAll() ([]models.Petugas, error) {
	var petugas []models.Petugas
	err := r.db.Table("petugas").
		Select("petugas.*, jenis_kelamin.nama AS jenis_kelamin_nama, users.nama AS user_nama").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = petugas.jenis_kelamin").
		Joins("LEFT JOIN users ON users.id = petugas.user_id").
		Where("petugas.status = ?", 1).
		Order("petugas.id ASC").
		Find(&petugas).Error
	return petugas, err
}

func (r *PetugasRepository) FindByID(id uint) (*models.Petugas, error) {
	var petugas models.Petugas
	err := r.db.Table("petugas").
		Select("petugas.*, jenis_kelamin.nama AS jenis_kelamin_nama, users.nama AS user_nama").
		Joins("LEFT JOIN jenis_kelamin ON jenis_kelamin.id = petugas.jenis_kelamin").
		Joins("LEFT JOIN users ON users.id = petugas.user_id").
		First(&petugas, id).Error
	if err != nil {
		return nil, err
	}
	return &petugas, nil
}

func (r *PetugasRepository) Create(petugas *models.Petugas) error {
	return r.db.Create(petugas).Error
}

func (r *PetugasRepository) Update(petugas *models.Petugas) error {
	return r.db.Save(petugas).Error
}

func (r *PetugasRepository) Deactivate(petugas *models.Petugas) error {
	return r.db.Model(petugas).Updates(map[string]interface{}{
		"status":     0,
		"updated_by": petugas.UpdatedBy,
		"updated_at": petugas.UpdatedAt,
	}).Error
}

func (r *PetugasRepository) FindActiveJenisKelamin() ([]models.JenisKelamin, error) {
	var items []models.JenisKelamin
	err := r.db.Where("status = ?", 1).Order("id ASC").Find(&items).Error
	return items, err
}

func (r *PetugasRepository) FindActiveUsers() ([]models.User, error) {
	var users []models.User
	err := r.db.Select("id, nama").
		Where("status = ?", 1).
		Order("id ASC").
		Find(&users).Error
	return users, err
}
