package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"

	"github.com/gin-gonic/gin"
)

func SetupRouter(
	cfg config.Config,
	healthController *controllers.HealthController,
	pemohonController *controllers.PemohonController,
	groupController *controllers.GroupController,
	userController *controllers.UserController,
	authController *controllers.AuthController,
	meController *controllers.MeController,
	sidebarController *controllers.SidebarController,
	sidebarAccessController *controllers.SidebarAccessController,
) *gin.Engine {
	r := gin.Default()
	sidebarAccessRepository := repositories.NewSidebarAccessRepository()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", healthController.Check)

		auth := v1.Group("/auth")
		{
			auth.POST("/login", authController.Login)
			auth.GET("/me", middleware.JWTAuth(cfg), meController.Me)
			auth.GET("/me/sidebar-access", middleware.JWTAuth(cfg), meController.SidebarAccess)
		}

		// Read-only first server-data slice. Local SQLite remains the Flutter
		// source of truth; this endpoint only verifies authenticated reads.
		v1.GET("/pemohon",
			middleware.JWTAuth(cfg),
			middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionRead),
			pemohonController.GetAll,
		)

		users := v1.Group("/users")
		{
			users.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionRead), userController.GetAll)
			users.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionCreate), userController.Create)
			users.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionUpdate), userController.Update)
			users.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionDelete), userController.Delete)
		}

		groups := v1.Group("/groups")
		{
			groups.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionRead), groupController.GetAll)
			groups.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionCreate), groupController.Create)
			groups.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionUpdate), groupController.Update)
			groups.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionDelete), groupController.Delete)
			groups.GET("/:id/sidebar-access", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionRead), sidebarAccessController.GetByGroup)
			groups.PUT("/:id/sidebar-access", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionUpdate), sidebarAccessController.Replace)
		}

		sidebars := v1.Group("/sidebars")
		{
			sidebars.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "sidebars", middleware.PermissionRead), sidebarController.GetAll)
			sidebars.GET("tree", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "sidebars", middleware.PermissionRead), sidebarController.GetTree)
			sidebars.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "sidebars", middleware.PermissionRead), sidebarController.GetByID)
		}

		// Other master CRUD endpoints and local-first sync remain disabled until
		// their API contracts, authorization, and conflict rules are defined.
	}

	return r
}
