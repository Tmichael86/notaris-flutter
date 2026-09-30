package services

import (
	"errors"
	"fmt"
	"time"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

var ErrInvalidPetugasDate = errors.New("tanggal lahir tidak valid")

type PetugasService struct {
	repository *repositories.PetugasRepository
}

func NewPetugasService() *PetugasService {
	return &PetugasService{
		repository: repositories.NewPetugasRepository(),
	}
}

func (s *PetugasService) GetAll() ([]models.Petugas, error) {
	return s.repository.FindAll()
}

func (s *PetugasService) GetByID(id uint) (*models.Petugas, error) {
	return s.repository.FindByID(id)
}

func (s *PetugasService) Create(req request.CreatePetugasRequest, userID uint) (*models.Petugas, error) {
	tanggalLahir, err := parseTanggalLahir(req.TanggalLahir)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPetugasDate, err)
	}

	createdBy := userID
	now := time.Now()
	petugas := &models.Petugas{
		NIK:          stringPtr(req.NIK),
		Nama:         req.Nama,
		Alamat:       req.Alamat,
		TempatLahir:  stringPtr(req.TempatLahir),
		TanggalLahir: &tanggalLahir,
		JenisKelamin: uintPtr(req.JenisKelamin),
		NoTelp:       req.NoTelp,
		Email:        req.Email,
		UserID:       uintPtr(req.UserID),
		CreatedBy:    &createdBy,
		CreatedAt:    &now,
		Status:       1,
	}

	if err := s.repository.Create(petugas); err != nil {
		return nil, err
	}

	return petugas, nil
}

func (s *PetugasService) Update(id uint, req request.UpdatePetugasRequest, userID uint) (*models.Petugas, error) {
	petugas, err := s.repository.FindByID(id)
	if err != nil {
		return nil, err
	}

	tanggalLahir, err := parseTanggalLahir(req.TanggalLahir)
	if err != nil {
		return nil, err
	}

	updatedBy := userID
	now := time.Now()

	petugas.NIK = stringPtr(req.NIK)
	petugas.UserID = uintPtr(req.UserID)
	petugas.Nama = req.Nama
	petugas.Alamat = req.Alamat
	petugas.TempatLahir = stringPtr(req.TempatLahir)
	petugas.TanggalLahir = &tanggalLahir
	petugas.JenisKelamin = uintPtr(req.JenisKelamin)
	petugas.NoTelp = req.NoTelp
	petugas.Email = req.Email
	petugas.UpdatedBy = &updatedBy
	petugas.UpdatedAt = &now
	petugas.Status = 1

	if err := s.repository.Update(petugas); err != nil {
		return nil, err
	}

	return petugas, nil
}

func (s *PetugasService) Deactivate(id, userID uint) error {
	petugas, err := s.repository.FindByID(id)
	if err != nil {
		return err
	}

	updatedBy := userID
	now := time.Now()
	petugas.UpdatedBy = &updatedBy
	petugas.UpdatedAt = &now

	return s.repository.Deactivate(petugas)
}

func (s *PetugasService) GetJenisKelamin() ([]models.JenisKelamin, error) {
	return s.repository.FindActiveJenisKelamin()
}

func (s *PetugasService) GetUsers() ([]models.User, error) {
	return s.repository.FindActiveUsers()
}

func parseTanggalLahir(value string) (time.Time, error) {
	return time.Parse("02/01/2006", value)
}

func stringPtr(value string) *string {
	return &value
}

func uintPtr(value uint) *uint {
	return &value
}
