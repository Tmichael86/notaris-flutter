package services

import (
	"time"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

type JenisPengeluaranService struct {
	repository *repositories.JenisPengeluaranRepository
}

func NewJenisPengeluaranService() *JenisPengeluaranService {
	return &JenisPengeluaranService{
		repository: repositories.NewJenisPengeluaranRepository(),
	}
}

func (s *JenisPengeluaranService) GetAll() ([]models.JenisPengeluaran, error) {
	return s.repository.FindAll()
}

func (s *JenisPengeluaranService) Create(req request.CreateJenisPengeluaranRequest, userID uint) (*models.JenisPengeluaran, error) {
	now := time.Now()
	createdBy := userID

	item := &models.JenisPengeluaran{
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

func (s *JenisPengeluaranService) Update(id uint, req request.UpdateJenisPengeluaranRequest, userID uint) (*models.JenisPengeluaran, error) {
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

func (s *JenisPengeluaranService) Deactivate(id, userID uint) error {
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
