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
	sidebarController *controllers.SidebarController,
	sidebarAccessController *controllers.SidebarAccessController,
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
			users.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "users", middleware.PermissionRead), userController.GetAll)
			users.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "users", middleware.PermissionRead), userController.GetByID)
			users.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "users", middleware.PermissionCreate), userController.Create)
			users.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "users", middleware.PermissionUpdate), userController.Update)
			users.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "users", middleware.PermissionDelete), userController.Delete)
		}

		groups := v1.Group("/groups")
		{
			groups.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionRead), groupController.GetAll)
			groups.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionRead), groupController.GetByID)
			groups.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionCreate), groupController.Create)
			groups.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionUpdate), groupController.Update)
			groups.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionDelete), groupController.Delete)
			groups.GET("/:id/sidebar-access", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionRead), sidebarAccessController.GetByGroup)
			groups.PUT("/:id/sidebar-access", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "groups", middleware.PermissionUpdate), sidebarAccessController.Replace)
		}

		sidebars := v1.Group("/sidebars")
		{
			sidebars.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "sidebars", middleware.PermissionRead), sidebarController.GetAll)
			sidebars.GET("tree", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "sidebars", middleware.PermissionRead), sidebarController.GetTree)
			sidebars.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(middleware.NewSidebarAccessRepository(), "sidebars", middleware.PermissionRead), sidebarController.GetByID)
		}

		sync := v1.Group("/sync")
		{
			sync.POST("/push", syncController.Push)
			sync.GET("/pull", syncController.Pull)
		}
	}

	return r
}
