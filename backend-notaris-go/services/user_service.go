package services

import (
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

func (s *UserService) Create(user *models.User) error {
	return s.repository.Create(user)
}

func (s *UserService) Update(user *models.User) error {
	return s.repository.Update(user)
}

func (s *UserService) Deactivate(user *models.User) error {
	return s.repository.Deactivate(user)
}
