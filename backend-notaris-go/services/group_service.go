package services

import (
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
)

type GroupService struct {
	repository *repositories.GroupRepository
}

func NewGroupService() *GroupService {
	return &GroupService{
		repository: repositories.NewGroupRepository(),
	}
}

func (s *GroupService) GetAll() ([]models.Group, error) {
	return s.repository.FindAll()
}

func (s *GroupService) GetByID(id uint) (*models.Group, error) {
	return s.repository.FindByID(id)
}

// Unversioned writers are intentionally unavailable. All registered API writes
// use Administration with actor/version, revision, shared lock and atomic audit.
func (s *GroupService) Create(value *models.Group, actor uint) error {
	return adminError(503, "use_secured_administration")
}
func (s *GroupService) Update(value *models.Group, actor uint) error {
	return adminError(503, "use_secured_administration")
}
func (s *GroupService) Deactivate(value *models.Group, actor uint) error {
	return adminError(503, "use_secured_administration")
}
