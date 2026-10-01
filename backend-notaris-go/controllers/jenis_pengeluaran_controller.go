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

type JenisPengeluaranController struct {
	service *services.JenisPengeluaranService
}

func NewJenisPengeluaranController() *JenisPengeluaranController {
	return &JenisPengeluaranController{
		service: services.NewJenisPengeluaranService(),
	}
}

func (c *JenisPengeluaranController) GetAll(ctx *gin.Context) {
	items, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data jenis pengeluaran", err.Error())
		return
	}

	response.Success(ctx, "Data jenis pengeluaran berhasil diambil", items)
}

func (c *JenisPengeluaranController) Create(ctx *gin.Context) {
	var req request.CreateJenisPengeluaranRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data jenis pengeluaran tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedJenisPengeluaranUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Create(req, userID)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat jenis pengeluaran", err.Error())
		return
	}

	response.Success(ctx, "Jenis pengeluaran berhasil dibuat", item)
}

func (c *JenisPengeluaranController) Update(ctx *gin.Context) {
	id, err := parseJenisPengeluaranID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID jenis pengeluaran tidak valid", nil)
		return
	}

	var req request.UpdateJenisPengeluaranRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data jenis pengeluaran tidak valid", err.Error())
		return
	}

	userID, ok := authenticatedJenisPengeluaranUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	item, err := c.service.Update(id, req, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Jenis pengeluaran tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui jenis pengeluaran", err.Error())
		return
	}

	response.Success(ctx, "Jenis pengeluaran berhasil diperbarui", item)
}

func (c *JenisPengeluaranController) Delete(ctx *gin.Context) {
	id, err := parseJenisPengeluaranID(ctx)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID jenis pengeluaran tidak valid", nil)
		return
	}

	userID, ok := authenticatedJenisPengeluaranUserID(ctx)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	if err := c.service.Deactivate(id, userID); errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Jenis pengeluaran tidak ditemukan", nil)
	} else if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan jenis pengeluaran", err.Error())
	} else {
		response.Success(ctx, "Jenis pengeluaran berhasil dinonaktifkan", nil)
	}
}

func parseJenisPengeluaranID(ctx *gin.Context) (uint, error) {
	value, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil || value == 0 {
		return 0, errors.New("invalid jenis pengeluaran id")
	}
	return uint(value), nil
}

func authenticatedJenisPengeluaranUserID(ctx *gin.Context) (uint, bool) {
	value, exists := ctx.Get("user_id")
	if !exists {
		return 0, false
	}
	userID, ok := value.(uint)
	return userID, ok && userID > 0
}
