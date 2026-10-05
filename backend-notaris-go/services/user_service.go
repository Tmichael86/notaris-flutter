package services

import (
	"time"

	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

type UserService struct {
	repository *repositories.UserRepository
}

func NewUserService() *UserService {
	return &UserService{
		repository: repositories.NewUserRepository(),
	}
}

func (s *UserService) GetAll() ([]models.User, error) {
	return s.repository.FindAll()
}

func (s *UserService) GetByID(id uint) (*models.User, error) {
	return s.repository.FindByID(id)
}

func (s *UserService) Create(user *models.User, userID uint) error {
	now := time.Now()
	createdBy := userID

	user.CreatedBy = &createdBy
	user.CreatedAt = &now
	user.Status = 1

	return s.repository.Create(user)
}

func (s *UserService) Update(user *models.User, userID uint) error {
	now := time.Now()
	updatedBy := userID

	user.UpdatedBy = &updatedBy
	user.UpdatedAt = &now
	user.Status = 1

	return s.repository.Update(user)
}

func (s *UserService) Deactivate(user *models.User, userID uint) error {
	now := time.Now()
	updatedBy := userID

	user.UpdatedBy = &updatedBy
	user.UpdatedAt = &now
	user.Status = 0

	return s.repository.Update(user)
}
