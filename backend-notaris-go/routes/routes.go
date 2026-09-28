package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/middleware"

	"github.com/gin-gonic/gin"
)

func SetupRouter(
	cfg config.Config,
	healthController *controllers.HealthController,
	syncController controllers.SyncController,
	groupController *controllers.GroupController,
	userController *controllers.UserController,
	authController *controllers.AuthController,
	meController *controllers.MeController,
) *gin.Engine {
	r := gin.Default()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", healthController.Check)

		auth := v1.Group("/auth")
		{
			auth.POST("/login", authController.Login)
			auth.GET("/me", middleware.JWTAuth(cfg), meController.Me)
		}

		users := v1.Group("/users")
		{
			users.GET("", userController.GetAll)
			users.GET("/:id", userController.GetByID)
			users.POST("", userController.Create)
			users.PUT("/:id", userController.Update)
			users.DELETE("/:id", userController.Delete)
		}

		groups := v1.Group("/groups")
		{
			groups.GET("", groupController.GetAll)
			groups.GET("/:id", groupController.GetByID)
			groups.POST("", groupController.Create)
			groups.PUT("/:id", groupController.Update)
			groups.DELETE("/:id", groupController.Delete)
		}

		sync := v1.Group("/sync")
		{
			sync.POST("/push", syncController.Push)
			sync.GET("/pull", syncController.Pull)
		}
	}

	return r
}
