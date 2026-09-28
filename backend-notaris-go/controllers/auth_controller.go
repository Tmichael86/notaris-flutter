package controllers

import (
	"errors"
	"net/http"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/dto/response"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
)

type AuthController struct {
	service *services.AuthService
}

func NewAuthController(service *services.AuthService) *AuthController {
	return &AuthController{service: service}
}

func (c *AuthController) Login(ctx *gin.Context) {
	var req request.LoginRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.Error(ctx, http.StatusBadRequest, "Data login tidak valid", err.Error())
		return
	}

	user, token, err := c.service.Login(req.Username, req.Password)
	if errors.Is(err, services.ErrInvalidCredentials) {
		response.Error(ctx, http.StatusUnauthorized, "Username atau password salah", nil)
		return
	}
	if err != nil {
		response.Error(ctx, http.StatusInternalServerError, "Gagal melakukan login", err.Error())
		return
	}

	response.Success(ctx, "Login berhasil", gin.H{
		"token": token,
		"user":  user,
	})
}
