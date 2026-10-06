package controllers

import (
	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/services"
	"errors"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http"
	"strconv"
)

type PekerjaanController struct{ service *services.PekerjaanService }

func NewPekerjaanController() *PekerjaanController {
	return &PekerjaanController{service: services.NewPekerjaanService()}
}
func (c *PekerjaanController) GetAllNotaris(x *gin.Context) { c.getAll(x, "notaris") }
func (c *PekerjaanController) GetAllPPAT(x *gin.Context)    { c.getAll(x, "ppat") }
func (c *PekerjaanController) GetByNotaris(x *gin.Context)  { c.getByID(x, "notaris") }
func (c *PekerjaanController) GetByPPAT(x *gin.Context)     { c.getByID(x, "ppat") }
func (c *PekerjaanController) CreateNotaris(x *gin.Context) { c.create(x, "notaris") }
func (c *PekerjaanController) CreatePPAT(x *gin.Context)    { c.create(x, "ppat") }
func (c *PekerjaanController) UpdateNotaris(x *gin.Context) { c.update(x, "notaris") }
func (c *PekerjaanController) UpdatePPAT(x *gin.Context)    { c.update(x, "ppat") }
func (c *PekerjaanController) DeleteNotaris(x *gin.Context) { c.delete(x, "notaris") }
func (c *PekerjaanController) DeletePPAT(x *gin.Context)    { c.delete(x, "ppat") }
func (c *PekerjaanController) getAll(x *gin.Context, k string) {
	d, e := c.service.GetAll(k)
	if e != nil {
		response.Error(x, 500, "Gagal mengambil data pekerjaan", e.Error())
		return
	}
	response.Success(x, "Data pekerjaan berhasil diambil", d)
}
func (c *PekerjaanController) getByID(x *gin.Context, k string) {
	id, e := parsePekerjaanID(x)
	if e != nil {
		response.Error(x, 400, "ID pekerjaan tidak valid", nil)
		return
	}
	d, e := c.service.GetByID(k, id)
	if errors.Is(e, gorm.ErrRecordNotFound) {
		response.Error(x, 404, "Pekerjaan tidak ditemukan", nil)
		return
	}
	if e != nil {
		response.Error(x, 500, "Gagal mengambil data pekerjaan", e.Error())
		return
	}
	response.Success(x, "Data pekerjaan berhasil diambil", d)
}
func (c *PekerjaanController) create(x *gin.Context, k string) {
	var q request.PekerjaanRequest
	if e := x.ShouldBindJSON(&q); e != nil {
		response.Error(x, 400, "Data pekerjaan tidak valid", e.Error())
		return
	}
	u, ok := authenticatedUserID(x)
	if !ok {
		response.Error(x, 401, "Identitas user tidak valid", nil)
		return
	}
	d, e := c.service.Create(k, q, u)
	if errors.Is(e, services.ErrDuplicatePekerjaanKategori) {
		response.Error(x, 400, e.Error(), nil)
		return
	}
	if e != nil {
		response.Error(x, 500, "Gagal membuat pekerjaan", e.Error())
		return
	}
	response.Success(x, "Pekerjaan berhasil dibuat", d)
}
func (c *PekerjaanController) update(x *gin.Context, k string) {
	id, e := parsePekerjaanID(x)
	if e != nil {
		response.Error(x, 400, "ID pekerjaan tidak valid", nil)
		return
	}
	var q request.PekerjaanRequest
	if e = x.ShouldBindJSON(&q); e != nil {
		response.Error(x, 400, "Data pekerjaan tidak valid", e.Error())
		return
	}
	u, ok := authenticatedUserID(x)
	if !ok {
		response.Error(x, 401, "Identitas user tidak valid", nil)
		return
	}
	d, e := c.service.Update(k, id, q, u)
	if errors.Is(e, gorm.ErrRecordNotFound) {
		response.Error(x, 404, "Pekerjaan tidak ditemukan", nil)
		return
	}
	if errors.Is(e, services.ErrDuplicatePekerjaanKategori) {
		response.Error(x, 400, e.Error(), nil)
		return
	}
	if e != nil {
		response.Error(x, 500, "Gagal memperbarui pekerjaan", e.Error())
		return
	}
	response.Success(x, "Pekerjaan berhasil diperbarui", d)
}
func (c *PekerjaanController) delete(x *gin.Context, k string) {
	id, e := parsePekerjaanID(x)
	if e != nil {
		response.Error(x, 400, "ID pekerjaan tidak valid", nil)
		return
	}
	u, ok := authenticatedUserID(x)
	if !ok {
		response.Error(x, 401, "Identitas user tidak valid", nil)
		return
	}
	e = c.service.Delete(k, id, u)
	if errors.Is(e, gorm.ErrRecordNotFound) {
		response.Error(x, 404, "Pekerjaan tidak ditemukan", nil)
	} else if e != nil {
		response.Error(x, 500, "Gagal menonaktifkan pekerjaan", e.Error())
	} else {
		response.Success(x, "Pekerjaan berhasil dinonaktifkan", nil)
	}
}
func parsePekerjaanID(x *gin.Context) (uint, error) {
	v, e := strconv.ParseUint(x.Param("id"), 10, 64)
	if e != nil || v == 0 {
		return 0, errors.New("invalid pekerjaan id")
	}
	return uint(v), nil
}
