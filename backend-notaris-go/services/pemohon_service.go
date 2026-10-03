package services

import (
	"time"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

type PemohonService struct {
	repository *repositories.PemohonRepository
}

func NewPemohonService() *PemohonService {
	return &PemohonService{repository: repositories.NewPemohonRepository()}
}

func (s *PemohonService) GetAll() ([]models.Pemohon, error) {
	return s.repository.FindAll()
}

func (s *PemohonService) GetByID(id uint) (*models.Pemohon, error) {
	return s.repository.FindByID(id)
}

func (s *PemohonService) Create(req request.CreatePemohonRequest, userID uint) (*models.Pemohon, error) {
	createdBy := userID
	now := time.Now()
	item := &models.Pemohon{
		Nama:         req.Nama,
		NIK:          &req.NIK,
		JenisKelamin: &req.JenisKelamin,
		NoTelp:       req.NoTelp,
		Alamat:       req.Alamat,
		CreatedBy:    &createdBy,
		CreatedAt:    &now,
		Status:       1,
	}
	if err := s.repository.Create(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *PemohonService) Update(id uint, req request.UpdatePemohonRequest, userID uint) (*models.Pemohon, error) {
	item, err := s.repository.FindByID(id)
	if err != nil {
		return nil, err
	}

	updatedBy := userID
	now := time.Now()
	item.Nama = req.Nama
	item.NIK = &req.NIK
	item.JenisKelamin = &req.JenisKelamin
	item.NoTelp = req.NoTelp
	item.Alamat = req.Alamat
	item.UpdatedBy = &updatedBy
	item.UpdatedAt = &now
	item.Status = 1

	if err := s.repository.Update(item); err != nil {
		return nil, err
	}

	return s.repository.FindByID(id)
}

func (s *PemohonService) Deactivate(id, userID uint) error {
	item, err := s.repository.FindByID(id)
	if err != nil {
		return err
	}

	updatedBy := userID
	now := time.Now()
	item.UpdatedBy = &updatedBy
	item.UpdatedAt = &now

	return s.repository.Deactivate(item)
}

func (s *PemohonService) GetJenisKelamin() ([]models.JenisKelamin, error) {
	return s.repository.FindActiveJenisKelamin()
}
