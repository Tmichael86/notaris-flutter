package controllers

import (
	"errors"
	"net/http"
	"strconv"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type KategoriPekerjaanController struct {
	service *services.KategoriPekerjaanService
}

func NewKategoriPekerjaanController() *KategoriPekerjaanController {
	return &KategoriPekerjaanController{
		service: services.NewKategoriPekerjaanService(),
	}
}

func (c *KategoriPekerjaanController) GetAll(ctx *gin.Context) {
	items, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data kategori pekerjaan", err.Error())
		return
	}

	response.Success(ctx, "Data kategori pekerjaan berhasil diambil", items)
}

func (c *KategoriPekerjaanController) GetByID(ctx *gin.Context) {
	id, err := parseKategoriPekerjaanID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID kategori pekerjaan tidak valid", nil)
		return
	}

	item, err := c.service.GetByID(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Kategori pekerjaan tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data kategori pekerjaan", err.Error())
		return
	}

	response.Success(ctx, "Data kategori pekerjaan berhasil diambil", item)
}

func (c *KategoriPekerjaanController) Create(ctx *gin.Context) {
	var req request.CreateKategoriPekerjaanRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data kategori pekerjaan tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedKategoriPekerjaanUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Create(req, userID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat kategori pekerjaan", err.Error())
		return
	}

	response.Success(ctx, "Kategori pekerjaan berhasil dibuat", item)
}

func (c *KategoriPekerjaanController) Update(ctx *gin.Context) {
	id, err := parseKategoriPekerjaanID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID kategori pekerjaan tidak valid", nil)
		return
	}

	var req request.UpdateKategoriPekerjaanRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data kategori pekerjaan tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedKategoriPekerjaanUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Update(id, req, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Kategori pekerjaan tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui kategori pekerjaan", err.Error())
		return
	}

	response.Success(ctx, "Kategori pekerjaan berhasil diperbarui", item)
}

func (c *KategoriPekerjaanController) Delete(ctx *gin.Context) {
	id, err := parseKategoriPekerjaanID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID kategori pekerjaan tidak valid", nil)
		return
	}

	userID, ok := authenticatedKategoriPekerjaanUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	if err := c.service.Deactivate(id, userID); errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Kategori pekerjaan tidak ditemukan", nil)
		return
	} else if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan kategori pekerjaan", err.Error())
		return
	}

	response.Success(ctx, "Kategori pekerjaan berhasil dinonaktifkan", nil)
}

func parseKategoriPekerjaanID(ctx *gin.Context) (uint, error) {
	value, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil || value == 0 {
		return 0, errors.New("invalid kategori pekerjaan id")
	}
	return uint(value), nil
}

func authenticatedKategoriPekerjaanUserID(ctx *gin.Context) (uint, bool) {
	value, exists := ctx.Get("user_id")
	if !exists {
		return 0, false
	}
	userID, ok := value.(uint)
	return userID, ok && userID > 0
}
