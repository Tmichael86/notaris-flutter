package controllers

import (
	"net/http"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/services"

	"github.com/gin-gonic/gin"
)

type SyncController interface {
	Push(c *gin.Context)
	Pull(c *gin.Context)
}

type syncController struct {
	syncService services.SyncService
}

func NewSyncController(syncService services.SyncService) SyncController {
	return &syncController{syncService}
}

func (h *syncController) Push(c *gin.Context) {
	var req request.SyncPushRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"message": "Invalid payload format",
			"error":   err.Error(),
		})
		return
	}

	syncedAt, err := h.syncService.PushSync(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"message": "Failed to sync data",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    "success",
		"message":   "Sync push successful",
		"synced_at": syncedAt,
	})
}

func (h *syncController) Pull(c *gin.Context) {
	pemohons, transaksis, err := h.syncService.PullSync()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"message": "Failed to pull data",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":     "success",
		"pemohons":   pemohons,
		"transaksis": transaksis,
	})
}
