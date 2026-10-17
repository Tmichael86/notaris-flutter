package controllers

import (
	"net/http"
	"strconv"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
)

type PemohonController struct {
	repository *repositories.PemohonRepository
}

func NewPemohonController() *PemohonController {
	return &PemohonController{repository: repositories.NewPemohonRepository()}
}

func (c *PemohonController) GetAll(ctx *gin.Context) {
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
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data pemohon", nil)
		return
	}

	response.Success(ctx, "Data pemohon berhasil diambil", gin.H{
		"items": items,
		"pagination": gin.H{
			"page":      page,
			"page_size": pageSize,
			"total":     total,
			"has_more":  int64(page*pageSize) < total,
		},
	})
}

func queryInt(ctx *gin.Context, key string, fallback int) (int, error) {
	raw := ctx.Query(key)
	if raw == "" {
		return fallback, nil
	}
	return strconv.Atoi(raw)
}
