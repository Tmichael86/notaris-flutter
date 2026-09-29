package controllers

import (
	"errors"
	"net/http"
	"strconv"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
)

type SidebarAccessController struct{ service *services.SidebarService }

func NewSidebarAccessController(service *services.SidebarService) *SidebarAccessController {
	return &SidebarAccessController{service: service}
}

func (c *SidebarAccessController) GetByGroup(ctx *gin.Context) {
	groupID, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID group tidak valid", nil)
		return
	}
	access, err := c.service.GetGroupAccess(uint(groupID))
	if errors.Is(err, services.ErrInvalidSidebarAccess) {
		response.Error(ctx, http.StatusNotFound, "Group tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil hak akses sidebar", err.Error())
		return
	}
	response.Success(ctx, "Hak akses sidebar berhasil diambil", access)
}

func (c *SidebarAccessController) Replace(ctx *gin.Context) {
	groupID, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID group tidak valid", nil)
		return
	}
	var req request.UpdateSidebarAccessRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data hak akses sidebar tidak valid", err.Error())
		return
	}
	value, exists := ctx.Get("user_id")
	if !exists {
		response.Error(ctx, http.StatusUnauthorized, "User belum terautentikasi", nil)
		return
	}
	userID, ok := value.(uint)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}
	err = c.service.ReplaceGroupAccess(uint(groupID), userID, req.Access)
	if errors.Is(err, services.ErrInvalidSidebarAccess) {
		response.Error(ctx, http.StatusBadRequest, "Group atau sidebar tidak valid", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menyimpan hak akses sidebar", err.Error())
		return
	}
	response.Success(ctx, "Hak akses sidebar berhasil disimpan", nil)
}
