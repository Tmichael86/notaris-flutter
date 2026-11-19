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

// Unversioned writers are intentionally unavailable. All registered API writes
// use Administration with actor/version, revision, shared lock and atomic audit.
func (s *UserService) Create(value *models.User, actor uint) error {
	return adminError(503, "use_secured_administration")
}
func (s *UserService) Update(value *models.User, actor uint) error {
	return adminError(503, "use_secured_administration")
}
func (s *UserService) Deactivate(value *models.User, actor uint) error {
	return adminError(503, "use_secured_administration")
}
