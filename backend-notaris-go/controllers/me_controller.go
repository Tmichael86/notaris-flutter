package controllers

import (
	"net/http"

	"backend-notaris-go/dto/response"
	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
)

type MeController struct {
	repository *repositories.UserRepository
}

func NewMeController() *MeController {
	return &MeController{repository: repositories.NewUserRepository()}
}

func (c *MeController) Me(ctx *gin.Context) {
	value, exists := ctx.Get("user_id")
	if !exists {
		response.Error(ctx, http.StatusUnauthorized, "User belum terautentikasi", nil)
		return
	}

	userID, ok := value.(uint)
	if !ok {
		response.Error(ctx, http.StatusUnauthorized, "Identitas user tidak valid", nil)
		return
	}

	user, err := c.repository.FindByID(userID)
	if err != nil || user.Status != 1 {
		response.Error(ctx, http.StatusUnauthorized, "User tidak ditemukan atau tidak aktif", nil)
		return
	}

	response.Success(ctx, "Data user aktif berhasil diambil", user)
}
