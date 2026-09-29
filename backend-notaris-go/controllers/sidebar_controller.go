package controllers

import (
    "errors"
    "net/http"
    "strconv"

    "backend-notaris-go/dto/response"
    "backend-notaris-go/services"

    "github.com/gin-gonic/gin"
    "gorm.io/gorm"
 )

type SidebarController struct { service *services.SidebarService }

func NewSidebarController() *SidebarController { return &SidebarController{service: services.NewSidebarService()} }

func (c *SidebarController) GetAll(ctx *gin.Context) {
    sidebars, err := c.service.GetAll()
    if err != nil { response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data sidebar", err.Error()); return }
    response.Success(ctx, "Data sidebar berhasil diambil", sidebars)
}

func (c *SidebarController) GetTree(ctx *gin.Context) {
    sidebars, err := c.service.GetTree()
    if err != nil { response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil struktur sidebar", err.Error()); return }
    response.Success(ctx, "Struktur sidebar berhasil diambil", sidebars)
}

func (c *SidebarController) GetByID(ctx *gin.Context) {
    id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
    if err != nil { response.Error(ctx, http.StatusBadRequest, "ID sidebar tidak valid", nil); return }
    sidebar, err := c.service.GetByID(uint(id))
    if errors.Is(err, services.ErrSidebarNotFound) || errors.Is(err, gorm.ErrRecordNotFound) { response.Error(ctx, http.StatusNotFound, "Sidebar tidak ditemukan", nil); return }
    if err != nil { response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data sidebar", err.Error()); return }
    response.Success(ctx, "Data sidebar berhasil diambil", sidebar)
}
