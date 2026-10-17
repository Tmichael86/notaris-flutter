package controllers

import (
	"net/http"

	"backend-notaris-go/database"
	"backend-notaris-go/dto/response"

	"github.com/gin-gonic/gin"
)

type HealthController struct{}

func NewHealthController() *HealthController {
	return &HealthController{}
}

// Check reports readiness only when the API process and PostgreSQL are healthy.
func (h *HealthController) Check(c *gin.Context) {
	if err := database.Ping(c.Request.Context()); err != nil {
		response.Error(c, http.StatusServiceUnavailable, "Database is not ready", nil)
		return
	}

	response.Success(c, "API and database are ready", gin.H{
		"service":  "backend-notaris-go",
		"status":   "ok",
		"database": "connected",
	})
}
