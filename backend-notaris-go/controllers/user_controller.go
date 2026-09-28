package controllers

import (
	"errors"
	"net/http"
	"strconv"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/models"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type UserController struct {
	service *services.UserService
}

func NewUserController() *UserController {
	return &UserController{
		service: services.NewUserService(),
	}
}

func (c *UserController) GetAll(ctx *gin.Context) {
	users, err := c.service.GetAll()
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data user", err.Error())
		return
	}

	response.Success(ctx, "Data user berhasil diambil", users)
}

func (c *UserController) GetByID(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID user tidak valid", nil)
		return
	}

	user, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "User tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data user", err.Error())
		return
	}

	response.Success(ctx, "Data user berhasil diambil", user)
}

func (c *UserController) Create(ctx *gin.Context) {
	var req request.CreateUserRequest

	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data user tidak valid", err.Error())
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengenkripsi password", err.Error())
		return
	}

	user := &models.User{
		GroupID:  req.GroupID,
		Username: req.Username,
		Password: string(passwordHash),
		Email:    req.Email,
		Nama:     req.Nama,
		NoTelp:   req.NoTelp,
		Alamat:   req.Alamat,
		Image:    req.Image,
		Status:   1,
	}

	if err := c.service.Create(user); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal membuat user", err.Error())
		return
	}

	response.Success(ctx, "User berhasil dibuat", user)
}

func (c *UserController) Update(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID user tidak valid", nil)
		return
	}

	user, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "User tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data user", err.Error())
		return
	}

	var req request.UpdateUserRequest

	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data user tidak valid", err.Error())
		return
	}

	user.GroupID = req.GroupID
	user.Username = req.Username
	user.Email = req.Email
	user.Nama = req.Nama
	user.NoTelp = req.NoTelp
	user.Alamat = req.Alamat
	if req.Image != nil {
		user.Image = req.Image
	}
	if req.Status != nil {
		user.Status = *req.Status
	}

	if req.Password != "" {
		passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			response.Error(ctx, http.StatusInternalServerError, "Gagal mengenkripsi password", err.Error())
			return
		}
		user.Password = string(passwordHash)
	}

	if err := c.service.Update(user); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal memperbarui user", err.Error())
		return
	}

	response.Success(ctx, "User berhasil diperbarui", user)
}

func (c *UserController) Delete(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 64)
	if err != nil {
		response.Error(ctx, http.StatusBadRequest, "ID user tidak valid", nil)
		return
	}

	user, err := c.service.GetByID(uint(id))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		response.Error(ctx, http.StatusNotFound, "User tidak ditemukan", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal mengambil data user", err.Error())
		return
	}

	if err := c.service.Deactivate(user); err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal menonaktifkan user", err.Error())
		return
	}

	response.Success(ctx, "User berhasil dinonaktifkan", nil)
}
