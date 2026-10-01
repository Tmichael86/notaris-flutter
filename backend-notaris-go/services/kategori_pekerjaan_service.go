package services

import (
	"time"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

type KategoriPekerjaanService struct {
	repository *repositories.KategoriPekerjaanRepository
}

func NewKategoriPekerjaanService() *KategoriPekerjaanService {
	return &KategoriPekerjaanService{
		repository: repositories.NewKategoriPekerjaanRepository(),
	}
}

func (s *KategoriPekerjaanService) GetAll() ([]models.KategoriPekerjaan, error) {
	return s.repository.FindAll()
}

func (s *KategoriPekerjaanService) GetByID(id uint) (*models.KategoriPekerjaan, error) {
	return s.repository.FindByID(id)
}

func (s *KategoriPekerjaanService) Create(req request.CreateKategoriPekerjaanRequest, userID uint) (*models.KategoriPekerjaan, error) {
	now := time.Now()
	createdBy := userID

	item := &models.KategoriPekerjaan{
		Nama:      req.Nama,
		CreatedBy: &createdBy,
		CreatedAt: &now,
		Status:    1,
	}

	if err := s.repository.Create(item); err != nil {
		return nil, err
	}

	return item, nil
}

func (s *KategoriPekerjaanService) Update(id uint, req request.UpdateKategoriPekerjaanRequest, userID uint) (*models.KategoriPekerjaan, error) {
	item, err := s.repository.FindByID(id)
	if err != nil {
		return nil, err
	}

	updatedBy := userID
	now := time.Now()

	item.Nama = req.Nama
	item.UpdatedBy = &updatedBy
	item.UpdatedAt = &now
	item.Status = 1

	if err := s.repository.Update(item); err != nil {
		return nil, err
	}

	return item, nil
}

func (s *KategoriPekerjaanService) Deactivate(id, userID uint) error {
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
