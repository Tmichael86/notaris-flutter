package controllers

import (
	"errors"
	"net/http"

	"backend-notaris-go/repositories"
	"github.com/gin-gonic/gin"
)

func masterMutationError(ctx *gin.Context, err error) bool {
	var denied *repositories.MutationAccessError
	if errors.As(err, &denied) {
		ctx.JSON(denied.Status, gin.H{"success": false, "code": denied.Code, "message": "Identitas atau izin tindakan tidak valid"})
		return true
	}
	if errors.Is(err, repositories.ErrMasterUUIDConflict) {
		ctx.JSON(http.StatusConflict, gin.H{"success": false, "code": "uuid_conflict", "message": "UUID sudah digunakan dengan data berbeda"})
		return true
	}
	if errors.Is(err, repositories.ErrInvalidMutationInput) {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Data atau UUID tidak valid"})
		return true
	}
	return false
}
