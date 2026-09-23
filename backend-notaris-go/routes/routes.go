package routes

import (
	"backend-notaris-go/controllers"

	"github.com/gin-gonic/gin"
)

func SetupRouter(syncController controllers.SyncController) *gin.Engine {
	r := gin.Default()

	// Grouping Endpoint /api/v1
	v1 := r.Group("/api/v1")
	{
		sync := v1.Group("/sync")
		{
			sync.POST("/push", syncController.Push)
			sync.GET("/pull", syncController.Pull)
		}
	}

	return r
}