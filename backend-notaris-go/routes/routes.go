package routes

import (
	"backend-notaris-go/controllers"

	"github.com/gin-gonic/gin"
)

func SetupRouter(
	healthController *controllers.HealthController,
	syncController controllers.SyncController,
	groupController *controllers.GroupController,
) *gin.Engine {
	r := gin.Default()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", healthController.Check)

		groups := v1.Group("/groups")
		{
			groups.GET("", groupController.GetAll)
			groups.GET("/:id", groupController.GetByID)
			groups.POST("", groupController.Create)
			groups.PUT("/:id", groupController.Update)
		}

		sync := v1.Group("/sync")
		{
			sync.POST("/push", syncController.Push)
			sync.GET("/pull", syncController.Pull)
		}
	}

	return r
}
