package services

import (
	"context"
	"errors"
	"sort"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"

	"gorm.io/gorm"
)

var ErrSidebarNotFound = errors.New("sidebar not found")

func (s *SidebarService) Catalog(ctx context.Context, page, size int, search, status string) (response.SidebarCatalogPage, error) {
	return s.sidebarRepository.Catalog(ctx, page, size, search, status)
}

var ErrInvalidSidebarAccess = errors.New("invalid sidebar access")

type SidebarService struct {
	sidebarRepository *repositories.SidebarRepository
	accessRepository  *repositories.SidebarAccessRepository
	groupRepository   *repositories.GroupRepository
}

func NewSidebarService() *SidebarService {
	return &SidebarService{
		sidebarRepository: repositories.NewSidebarRepository(),
		accessRepository:  repositories.NewSidebarAccessRepository(),
		groupRepository:   repositories.NewGroupRepository(),
	}
}

func (s *SidebarService) GetAll() ([]models.Sidebar, error) {
	return s.sidebarRepository.FindAllActive()
}

func (s *SidebarService) GetByID(id uint) (*models.Sidebar, error) {
	sidebar, err := s.sidebarRepository.FindByID(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrSidebarNotFound
	}
	return sidebar, err
}

func (s *SidebarService) GetTree() ([]response.SidebarTree, error) {
	sidebars, err := s.GetAll()
	if err != nil {
		return nil, err
	}
	roots := make(map[uint]*response.SidebarTree)
	for _, sidebar := range sidebars {
		if sidebar.SidebarParentID == nil || *sidebar.SidebarParentID == 0 {
			item := response.SidebarTree{Sidebar: sidebar}
			roots[sidebar.ID] = &item
		}
	}
	for _, sidebar := range sidebars {
		if sidebar.SidebarParentID == nil || *sidebar.SidebarParentID == 0 {
			continue
		}
		if parent := roots[*sidebar.SidebarParentID]; parent != nil {
			parent.Childs = append(parent.Childs, sidebar)
		}
	}
	result := make([]response.SidebarTree, 0, len(roots))
	for _, item := range roots {
		result = append(result, *item)
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].Sidebar.SidebarIndex < result[j].Sidebar.SidebarIndex })
	return result, nil
}

func (s *SidebarService) GetGroupAccess(groupID uint) ([]response.SidebarAccessResponse, error) {
	group, err := s.groupRepository.FindByID(groupID)
	if errors.Is(err, gorm.ErrRecordNotFound) || (err == nil && group.Status != 1) {
		return nil, ErrInvalidSidebarAccess
	}
	if err != nil {
		return nil, err
	}

	sidebars, err := s.GetAll()
	if err != nil {
		return nil, err
	}
	access, err := s.accessRepository.FindByGroupID(groupID)
	if err != nil {
		return nil, err
	}
	bySidebar := make(map[uint]models.SidebarAccess, len(access))
	for _, item := range access {
		if _, exists := bySidebar[item.SidebarID]; exists {
			return nil, ErrInvalidSidebarAccess
		}
		bySidebar[item.SidebarID] = item
	}
	result := make([]response.SidebarAccessResponse, 0, len(sidebars))
	for _, sidebar := range sidebars {
		item := response.SidebarAccessResponse{SidebarID: sidebar.ID, Sidebar: sidebar}
		if saved, ok := bySidebar[sidebar.ID]; ok {
			item.Read = saved.Read
			item.Create = saved.Create
			item.Update = saved.Update
			item.Delete = saved.Delete
		}
		result = append(result, item)
	}
	return result, nil
}

func (s *SidebarService) ReplaceGroupAccess(groupID, userID uint, items []request.SidebarAccessItem) error {
	return adminError(503, "use_secured_administration")
}
