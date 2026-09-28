package controllers

import (
	"errors"
	"net/http"
	"strconv"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type GroupController struct {
	service *services.GroupService
}

func NewGroupController() *GroupController {
	return &GroupController{
		service: services.NewGroupService(),
	}
}

func (c *GroupController) GetAll(ctx *gin.Context) {
	groups, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data group", err.Error())
		return
	}

	response.Success(ctx, "Data group berhasil diambil", groups)
}

func (c *GroupController) GetByID(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID group tidak valid", nil)
		return
	}

	group, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Group tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data group", err.Error())
		return
	}

	response.Success(ctx, "Data group berhasil diambil", group)
}

func (c *GroupController) Create(ctx *gin.Context) {
	var req request.CreateGroupRequest

	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data group tidak valid", err.Error())
		return
	}

	group := &models.Group{
		GroupNama:  req.GroupNama,
		GroupJenis: req.GroupJenis,
		Status:     1,
	}

	if err := c.service.Create(group); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat group", err.Error())
		return
	}

	response.Success(ctx, "Group berhasil dibuat", group)
}

func (c *GroupController) Update(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID group tidak valid", nil)
		return
	}

	group, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Group tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data group", err.Error())
		return
	}

	var req request.UpdateGroupRequest

	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data group tidak valid", err.Error())
		return
	}

	group.GroupNama = req.GroupNama
	group.GroupJenis = req.GroupJenis

	if req.Status != nil {
		group.Status = *req.Status
	}

	if err := c.service.Update(group); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui group", err.Error())
		return
	}

	response.Success(ctx, "Group berhasil diperbarui", group)
}

func (c *GroupController) Delete(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID group tidak valid", nil)
		return
	}

	group, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Group tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data group", err.Error())
		return
	}

	if err := c.service.Deactivate(group); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan group", err.Error())
		return
	}

	response.Success(ctx, "Group berhasil dinonaktifkan", nil)
}
