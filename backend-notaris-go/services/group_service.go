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

func (s *GroupService) Create(group *models.Group) error {
	return s.repository.Create(group)
}

func (s *GroupService) Update(group *models.Group) error {
	return s.repository.Update(group)
}

func (s *GroupService) Deactivate(group *models.Group) error {
	return s.repository.Deactivate(group)
}
