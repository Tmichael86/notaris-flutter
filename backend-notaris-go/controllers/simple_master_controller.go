package controllers

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/repositories"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type SimpleMasterController struct {
	repository *repositories.SimpleMasterRepository
	resource   string
}

func NewSimpleMasterController(tableName, resource string) *SimpleMasterController {
	return &SimpleMasterController{repository: repositories.NewSimpleMasterRepository(tableName), resource: resource}
}

type simpleMasterRequest struct {
	UUID string `json:"uuid"`
	Nama string `json:"nama"`
}

func (c *SimpleMasterController) GetAll(ctx *gin.Context) {
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
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil diambil", gin.H{
		"items":      items,
		"pagination": gin.H{"page": page, "page_size": pageSize, "total": total, "has_more": int64(page)*int64(pageSize) < total},
	})
}

func (c *SimpleMasterController) GetByID(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID tidak valid", nil)
		return
	}
	item, err := c.repository.FindActiveByID(ctx.Request.Context(), id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Data "+c.resource+" tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil diambil", item)
}

func (c *SimpleMasterController) Create(ctx *gin.Context) {
	var req simpleMasterRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "JSON request tidak valid", nil)
		return
	}
	req.Nama = strings.TrimSpace(req.Nama)
	if req.Nama == "" {
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"nama": "Nama wajib diisi"})
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	var item *repositories.SimpleMasterRecord
	var err error
	if strings.TrimSpace(req.UUID) != "" {
		item, err = c.repository.UpsertByUUID(ctx.Request.Context(), strings.TrimSpace(req.UUID), req.Nama, userID)
	} else {
		item, err = c.repository.Create(ctx.Request.Context(), req.Nama, userID)
	}
	if errors.Is(err, repositories.ErrDuplicateMasterName) {
		response.Error(ctx, http.StatusConflict, "Nama "+c.resource+" sudah digunakan", gin.H{"nama": "Nama harus unik di antara data aktif"})
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat data "+c.resource, nil)
		return
	}
	ctx.JSON(http.StatusCreated, response.APIResponse{Success: true, Message: "Data " + c.resource + " berhasil dibuat", Data: item})
}

func (c *SimpleMasterController) Update(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID tidak valid", nil)
		return
	}
	var req simpleMasterRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "JSON request tidak valid", nil)
		return
	}
	req.Nama = strings.TrimSpace(req.Nama)
	if req.Nama == "" {
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"nama": "Nama wajib diisi"})
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	item, err := c.repository.Update(ctx.Request.Context(), id, req.Nama, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Data "+c.resource+" tidak ditemukan", nil)
		return
	}
	if errors.Is(err, repositories.ErrDuplicateMasterName) {
		response.Error(ctx, http.StatusConflict, "Nama "+c.resource+" sudah digunakan", gin.H{"nama": "Nama harus unik di antara data aktif"})
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui data "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil diperbarui", item)
}

func (c *SimpleMasterController) Delete(ctx *gin.Context) {
	id, ok := parsePositiveID(ctx)
	if !ok {
		response.Error(ctx, http.StatusBadRequest, "ID tidak valid", nil)
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	err := c.repository.Deactivate(ctx.Request.Context(), id, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Data "+c.resource+" tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan data "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil dinonaktifkan", nil)
}

func parsePositiveID(ctx *gin.Context) (uint64, bool) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	return id, err == nil && id > 0
}

// SyncUpsert creates or updates a record using the stable client UUID.
func (c *SimpleMasterController) SyncUpsert(ctx *gin.Context) {
	uuid := strings.TrimSpace(ctx.Param("uuid"))
	if uuid == "" {
		response.Error(ctx, http.StatusBadRequest, "UUID tidak valid", nil)
		return
	}
	var req simpleMasterRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "JSON request tidak valid", nil)
		return
	}
	req.Nama = strings.TrimSpace(req.Nama)
	if req.Nama == "" {
		response.Error(ctx, http.StatusUnprocessableEntity, "Validasi data gagal", gin.H{"nama": "Nama wajib diisi"})
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	item, err := c.repository.UpsertByUUID(ctx.Request.Context(), uuid, req.Nama, userID)
	if errors.Is(err, repositories.ErrDuplicateMasterName) {
		response.Error(ctx, http.StatusConflict, "Nama "+c.resource+" sudah digunakan", gin.H{"nama": "Nama harus unik di antara data aktif"})
		return
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusConflict, "Data nonaktif tidak dapat disinkronkan ulang", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menyinkronkan data "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil disinkronkan", item)
}

func (c *SimpleMasterController) SyncDeactivate(ctx *gin.Context) {
	uuid := strings.TrimSpace(ctx.Param("uuid"))
	if uuid == "" {
		response.Error(ctx, http.StatusBadRequest, "UUID tidak valid", nil)
		return
	}
	userID, ok := getAuthenticatedUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "User tidak terautentikasi", nil)
		return
	}
	err := c.repository.DeactivateByUUID(ctx.Request.Context(), uuid, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Data "+c.resource+" tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menyinkronkan penghapusan "+c.resource, nil)
		return
	}
	response.Success(ctx, "Data "+c.resource+" berhasil dinonaktifkan", nil)
}
