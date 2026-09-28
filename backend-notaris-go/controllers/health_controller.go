package controllers

import (
	"backend-notaris-go/dto/response"

	"github.com/gin-gonic/gin"
)

type HealthController struct{}

func NewHealthController() *HealthController {
	return &HealthController{}
}

func (h *HealthController) Check(c *gin.Context) {
	response.Success(c, "API is running", gin.H{
		"service": "backend-notaris-go",
		"status":  "ok",
	})
}
