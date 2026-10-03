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

type PemohonController struct {
	service *services.PemohonService
}

func NewPemohonController() *PemohonController {
	return &PemohonController{service: services.NewPemohonService()}
}

func (c *PemohonController) GetAll(ctx *gin.Context) {
	items, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data pemohon", err.Error())
		return
	}
	response.Success(ctx, "Data pemohon berhasil diambil", items)
}

func (c *PemohonController) GetByID(ctx *gin.Context) {
	id, err := parsePemohonID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}

	item, err := c.service.GetByID(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data pemohon", err.Error())
		return
	}
	response.Success(ctx, "Data pemohon berhasil diambil", item)
}

func (c *PemohonController) Create(ctx *gin.Context) {
	var req request.CreatePemohonRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data pemohon tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Create(req, userID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat pemohon", err.Error())
		return
	}

	created, err := c.service.GetByID(item.ID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Pemohon berhasil dibuat tetapi gagal mengambil data", err.Error())
		return
	}

	response.Success(ctx, "Pemohon berhasil dibuat", created)
}

func (c *PemohonController) Update(ctx *gin.Context) {
	id, err := parsePemohonID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}

	var req request.UpdatePemohonRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data pemohon tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Update(id, req, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui pemohon", err.Error())
		return
	}

	response.Success(ctx, "Pemohon berhasil diperbarui", item)
}

func (c *PemohonController) Delete(ctx *gin.Context) {
	id, err := parsePemohonID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID pemohon tidak valid", nil)
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	err = c.service.Deactivate(id, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Pemohon tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan pemohon", err.Error())
		return
	}

	response.Success(ctx, "Pemohon berhasil dinonaktifkan", nil)
}

func (c *PemohonController) GetJenisKelamin(ctx *gin.Context) {
	items, err := c.service.GetJenisKelamin()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil jenis kelamin", err.Error())
		return
	}

	type option struct {
		ID   uint   `json:"id"`
		Text string `json:"text"`
	}

	data := make([]option, 0, len(items)+1)
	data = append(data, option{ID: 0, Text: "--pilih--"})
	for _, item := range items {
		data = append(data, option{ID: item.ID, Text: item.Nama})
	}

	response.Success(ctx, "Data jenis kelamin berhasil diambil", data)
}

func parsePemohonID(ctx *gin.Context) (uint, error) {
	value, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil || value == 0 {
		return 0, errors.New("invalid pemohon id")
	}
	return uint(value), nil
}
