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

type PetugasController struct {
	service *services.PetugasService
}

func NewPetugasController() *PetugasController {
	return &PetugasController{
		service: services.NewPetugasService(),
	}
}

func (c *PetugasController) GetAll(ctx *gin.Context) {
	petugas, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data petugas", err.Error())
		return
	}
	response.Success(ctx, "Data petugas berhasil diambil", petugas)
}

func (c *PetugasController) GetByID(ctx *gin.Context) {
	id, err := parsePetugasID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}

	petugas, err := c.service.GetByID(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data petugas", err.Error())
		return
	}
	response.Success(ctx, "Data petugas berhasil diambil", petugas)
}

func (c *PetugasController) Create(ctx *gin.Context) {
	var req request.CreatePetugasRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data petugas tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	petugas, err := c.service.Create(req, userID)
	if errors.Is(err, services.ErrInvalidPetugasDate) {
		response.Error(ctx, http.StatusBadRequest, "Tanggal lahir tidak valid, gunakan format DD/MM/YYYY", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat petugas", err.Error())
		return
	}

	created, err := c.service.GetByID(petugas.ID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Petugas berhasil dibuat tetapi gagal mengambil data", err.Error())
		return
	}

	response.Success(ctx, "Petugas berhasil dibuat", created)
}

func (c *PetugasController) Update(ctx *gin.Context) {
	id, err := parsePetugasID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}

	var req request.UpdatePetugasRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data petugas tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	petugas, err := c.service.Update(id, req, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	}
	if errors.Is(err, services.ErrInvalidPetugasDate) {
		response.Error(ctx, http.StatusBadRequest, "Tanggal lahir tidak valid, gunakan format DD/MM/YYYY", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui petugas", err.Error())
		return
	}

	response.Success(ctx, "Petugas berhasil diperbarui", petugas)
}

func (c *PetugasController) Delete(ctx *gin.Context) {
	id, err := parsePetugasID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}

	userID, ok := authenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	if err := c.service.Deactivate(id, userID); errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	} else if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan petugas", err.Error())
		return
	}

	response.Success(ctx, "Petugas berhasil dinonaktifkan", nil)
}

func (c *PetugasController) GetJenisKelamin(ctx *gin.Context) {
	items, err := c.service.GetJenisKelamin()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil jenis kelamin", err.Error())
		return
	}

	type option struct {
		ID   uint   \`json:"id"\`
		Text string \`json:"text"\`
	}

	data := make([]option, 0, len(items))
	for _, item := range items {
		data = append(data, option{ID: item.ID, Text: item.Nama})
	}

	response.Success(ctx, "Data jenis kelamin berhasil diambil", data)
}

func (c *PetugasController) GetUsers(ctx *gin.Context) {
	items, err := c.service.GetUsers()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data user", err.Error())
		return
	}

	type option struct {
		ID   uint   \`json:"id"\`
		Text string \`json:"text"\`
	}

	data := make([]option, 0, len(items))
	for _, item := range items {
		data = append(data, option{ID: item.ID, Text: item.Nama})
	}

	response.Success(ctx, "Data user berhasil diambil", data)
}

func parsePetugasID(ctx *gin.Context) (uint, error) {
	value, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil || value == 0 {
		return 0, errors.New("invalid petugas id")
	}
	return uint(value), nil
}

func authenticatedUserID(ctx *gin.Context) (uint, bool) {
	value, exists := ctx.Get("user_id")
	if !exists {
		return 0, false
	}
	userID, ok := value.(uint)
	return userID, ok && userID > 0
}
