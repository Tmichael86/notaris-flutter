package controllers

import (
	"errors"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"unicode/utf8"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type SidebarController struct{ service *services.SidebarService }

func (c *SidebarController) Catalog(ctx *gin.Context) {
	q, queryError := url.ParseQuery(ctx.Request.URL.RawQuery)
	if queryError != nil {
		response.Error(ctx, 400, "Filter katalog tidak valid", nil)
		return
	}
	for key, values := range q {
		if !map[string]bool{"page": true, "page_size": true, "search": true, "status": true}[key] || len(values) != 1 {
			response.Error(ctx, 400, "Filter katalog tidak valid", nil)
			return
		}
	}
	parse := func(key string, fallback, max int) (int, bool) {
		raw, ok := q[key]
		if !ok {
			return fallback, true
		}
		n, e := strconv.Atoi(raw[0])
		return n, e == nil && n >= 1 && n <= max
	}
	page, ok := parse("page", 1, 1000000)
	size, valid := parse("page_size", 10, 50)
	status := ctx.DefaultQuery("status", "all")
	search := strings.TrimSpace(ctx.Query("search"))
	if !ok || !valid || !utf8.ValidString(search) || strings.ContainsRune(search, 0) || utf8.RuneCountInString(search) > 200 || (status != "all" && status != "active" && status != "inactive") {
		response.Error(ctx, 400, "Filter katalog tidak valid", nil)
		return
	}
	out, err := c.service.Catalog(ctx.Request.Context(), page, size, search, status)
	if err != nil {
		response.Error(ctx, 500, "Katalog Sidebars belum dapat dimuat", nil)
		return
	}
	ctx.Header("Cache-Control", "no-store")
	response.Success(ctx, "Katalog Sidebars", out)
}

func NewSidebarController() *SidebarController {
	return &SidebarController{service: services.NewSidebarService()}
}

func (c *SidebarController) GetAll(ctx *gin.Context) {
	sidebars, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data sidebar", nil)
		return
	}
	response.Success(ctx, "Data sidebar berhasil diambil", sidebars)
}

func (c *SidebarController) GetTree(ctx *gin.Context) {
	sidebars, err := c.service.GetTree()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil struktur sidebar", nil)
		return
	}
	response.Success(ctx, "Struktur sidebar berhasil diambil", sidebars)
}

func (c *SidebarController) GetByID(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID sidebar tidak valid", nil)
		return
	}
	sidebar, err := c.service.GetByID(uint(id))
	if errors.Is(err, services.ErrSidebarNotFound) || errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "Sidebar tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data sidebar", nil)
		return
	}
	response.Success(ctx, "Data sidebar berhasil diambil", sidebar)
}
