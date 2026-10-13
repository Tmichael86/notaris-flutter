package controllers

import (
	"net/http"
	"time"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
)

type MeController struct {
	repository      *repositories.UserRepository
	groupRepository *repositories.GroupRepository
	sidebarService  *services.SidebarService
}

func NewMeController() *MeController {
	return &MeController{
		repository:      repositories.NewUserRepository(),
		groupRepository: repositories.NewGroupRepository(),
		sidebarService:  services.NewSidebarService(),
	}
}

func (c *MeController) authenticatedUser(ctx *gin.Context) (uint, bool) {
	value, exists := ctx.Get("user_id")
	if !exists {
		response.Error(ctx, http.StatusUnauthorized, "User belum terautentikasi", nil)
		return 0, false
	}

	userID, ok := value.(uint)
	if !ok || userID == 0 {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return 0, false
	}
	return userID, true
}

func (c *MeController) loadActiveUser(userID uint) (interface{}, uint, error) {
	user, err := c.repository.FindByID(userID)
	if err != nil {
		return nil, 0, err
	}
	if user.Status != 1 {
		return nil, 0, services.ErrInvalidCredentials
	}

	group, err := c.groupRepository.FindByID(user.GroupID)
	if err != nil {
		return nil, 0, err
	}
	if group.Status != 1 {
		return nil, 0, services.ErrInvalidCredentials
	}
	return user, user.GroupID, nil
}

func (c *MeController) Me(ctx *gin.Context) {
	userID, ok := c.authenticatedUser(ctx)
	if !ok {
		return
	}

	user, _, err := c.loadActiveUser(userID)
	if err != nil {
		response.Error(ctx, http.StatusUnauthorized, "User atau grup tidak ditemukan atau tidak aktif", nil)
		return
	}

	response.Success(ctx, "Data user aktif berhasil diambil", user)
}

// SidebarAccess returns the current user's latest sidebar permissions. The
// group is read from the current database record rather than trusting the
// potentially stale group_id claim in an existing JWT.
func (c *MeController) SidebarAccess(ctx *gin.Context) {
	userID, ok := c.authenticatedUser(ctx)
	if !ok {
		return
	}

	user, groupID, err := c.loadActiveUser(userID)
	if err != nil {
		response.Error(ctx, http.StatusUnauthorized, "User atau grup tidak ditemukan atau tidak aktif", nil)
		return
	}

	sidebars, err := c.sidebarService.GetGroupAccess(groupID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil hak akses sidebar", nil)
		return
	}

	response.Success(ctx, "Identitas dan hak akses berhasil diperbarui", gin.H{
		"user":                 user,
		"sidebars":             sidebars,
		"permissions_checked_at": time.Now().UTC(),
	})
}
