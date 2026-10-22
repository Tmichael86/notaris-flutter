package controllers

import (
	"errors"
	"net/http"
	"net/mail"
	"strconv"
	"strings"
	"time"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type PetugasController struct {
	repository *repositories.PetugasRepository
}

func NewPetugasController() *PetugasController {
	return &PetugasController{repository: repositories.NewPetugasRepository()}
}

type petugasRequest struct {
	NIK          *string `json:"nik"`
	Nama         string  `json:"nama"`
	Alamat       *string `json:"alamat"`
	TempatLahir  *string `json:"tempat_lahir"`
	TanggalLahir *string `json:"tanggal_lahir"`
	JenisKelamin *uint   `json:"jenis_kelamin"`
	NoTelp       *string `json:"no_telp"`
	Email        string  `json:"email"`
	UserID       *uint   `json:"user_id"`
}

func (c *PetugasController) GetAll(ctx *gin.Context) {
	page, err := queryInt(ctx, "page", 1)
	if err != nil || page < 1 {
		response.Error(ctx, http.StatusBadRequest, "Parameter page harus bilangan bulat positif", nil)
		return
	}
	pageSize, err := queryInt(ctx, "page_size", 50)
	if err != nil || pageSize < 1 {
		response.Error(ctx, http.StatusBadRequest, "Parameter page_size harus bilangan bulat positif", nil)
		return
	}
	if pageSize > 100 {
		pageSize = 100
	}
	items, total, err := c.repository.FindActive(ctx.Request.Context(), page, pageSize)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data petugas", nil)
		return
	}
	response.Success(ctx, "Data petugas berhasil diambil", gin.H{
		"items": items,
		"pagination": gin.H{
			"page": page, "page_size": pageSize, "total": total,
			"has_more": int64(page)*int64(pageSize) < total,
		},
	})
}

func (c *PetugasController) GetByID(ctx *gin.Context) {
	id, ok := parsePetugasID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}
	item, err := c.repository.FindActiveByID(ctx.Request.Context(), id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data petugas", nil)
		return
	}
	response.Success(ctx, "Data petugas berhasil diambil", item)
}

func (c *PetugasController) Create(ctx *gin.Context) {
	input, ok := bindAndValidatePetugas(ctx)
	if !ok {
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	item := toPetugasModel(input)
	if err := c.repository.Create(ctx.Request.Context(), item, userID); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat data petugas", nil)
		return
	}
	ctx.JSON(http.StatusCreated, response.APIResponse{Success: true, Message: "Data petugas berhasil dibuat", Data: item})
}

func (c *PetugasController) Update(ctx *gin.Context) {
	id, ok := parsePetugasID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}
	input, ok := bindAndValidatePetugas(ctx)
	if !ok {
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	item, err := c.repository.Update(ctx.Request.Context(), id, toPetugasModel(input), userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui data petugas", nil)
		return
	}
	response.Success(ctx, "Data petugas berhasil diperbarui", item)
}

func (c *PetugasController) Delete(ctx *gin.Context) {
	id, ok := parsePetugasID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID petugas tidak valid", nil)
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	err := c.repository.Deactivate(ctx.Request.Context(), id, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Petugas tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan data petugas", nil)
		return
	}
	response.Success(ctx, "Data petugas berhasil dinonaktifkan", nil)
}

func bindAndValidatePetugas(ctx *gin.Context) (*petugasRequest, bool) {
	var input petugasRequest
	if err := ctx.ShouldBindJSON(&input); err != nil {
		response.Error(ctx, http.StatusBadRequest, "JSON request tidak valid", nil)
		return nil, false
	}
	input.Nama = strings.TrimSpace(input.Nama)
	input.Email = strings.TrimSpace(input.Email)
	if input.Nama == "" || input.Email == "" {
		errors := gin.H{}
		if input.Nama == "" {
			errors["nama"] = "Nama wajib diisi"
		}
		if input.Email == "" {
			errors["email"] = "Email wajib diisi"
		}
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", errors)
		return nil, false
	}
	address, err := mail.ParseAddress(input.Email)
	if err != nil || address.Address != input.Email {
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"email": "Format email tidak valid"})
		return nil, false
	}
	if input.TanggalLahir != nil {
		date := strings.TrimSpace(*input.TanggalLahir)
		if date == "" {
			input.TanggalLahir = nil
		} else if _, err := time.Parse("2006-01-02", date); err != nil {
			response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"tanggal_lahir": "Tanggal harus berformat YYYY-MM-DD"})
			return nil, false
		} else {
			input.TanggalLahir = &date
		}
	}
	return &input, true
}

func toPetugasModel(input *petugasRequest) *models.Petugas {
	return &models.Petugas{
		NIK: input.NIK, Nama: input.Nama, Alamat: input.Alamat,
		TempatLahir: input.TempatLahir, TanggalLahir: input.TanggalLahir,
		JenisKelamin: input.JenisKelamin, NoTelp: input.NoTelp,
		Email: input.Email, UserID: input.UserID,
	}
}

func parsePetugasID(ctx *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	return uint(id), err == nil && id > 0
}
