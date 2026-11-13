package controllers

import (
	"backend-notaris-go/database"
	"backend-notaris-go/dto/response"
	"github.com/gin-gonic/gin"
)

// Names are display labels only; this catalog defines no global canonical code.
func PetugasGenderCatalog(ctx *gin.Context) {
	var items []struct {
		ID     uint   `json:"id"`
		Nama   string `json:"nama"`
		Status int16  `json:"status"`
	}
	if err := database.DB.WithContext(ctx.Request.Context()).Table("jenis_kelamin").Select("id,nama,status").Where("status = ?", 1).Order("id").Find(&items).Error; err != nil {
		response.Error(ctx, 500, "Gagal membaca referensi", gin.H{"code": "reference_unavailable"})
		return
	}
	response.Success(ctx, "Referensi jenis kelamin", gin.H{"items": items})
}
