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
	petugasController *controllers.PetugasController,
	kategoriPekerjaanController *controllers.SimpleMasterController,
	jenisPengeluaranController *controllers.SimpleMasterController,
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
		pemohon := v1.Group("/pemohon")
		{
			pemohon.PUT(
				"/sync/:uuid",
				middleware.JWTAuth(cfg),
				middleware.RequirePermission(
					sidebarAccessRepository,
					"pemohon",
					middleware.PermissionUpdate,
				),
				pemohonController.SyncUpsert,
			)
			pemohon.DELETE(
				"/sync/:uuid",
				middleware.JWTAuth(cfg),
				middleware.RequirePermission(
					sidebarAccessRepository,
					"pemohon",
					middleware.PermissionDelete,
				),
				pemohonController.SyncDeactivate,
			)

			pemohon.GET("", middleware.JWTAuth(cfg),
				middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionRead),
				pemohonController.GetAll)
			pemohon.GET("/:id", middleware.JWTAuth(cfg),
				middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionRead),
				pemohonController.GetByID)
			pemohon.POST("", middleware.JWTAuth(cfg),
				middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionCreate),
				pemohonController.Create)
			pemohon.PUT("/:id", middleware.JWTAuth(cfg),
				middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionUpdate),
				pemohonController.Update)
			pemohon.DELETE("/:id", middleware.JWTAuth(cfg),
				middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionDelete),
				pemohonController.Delete)
		}

		petugas := v1.Group("/petugas")
		{
			petugas.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetAll)
			petugas.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetByID)
			petugas.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionCreate), petugasController.Create)
			petugas.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionUpdate), petugasController.Update)
			petugas.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionDelete), petugasController.Delete)
		}

		masterRoutes := []struct {
			path       string
			sidebarKey string
			controller *controllers.SimpleMasterController
		}{
			{"/kategori-pekerjaan", "kategori_pekerjaan", kategoriPekerjaanController},
			{"/jenis-pengeluaran", "jenis_pengeluaran", jenisPengeluaranController},
		}
		for _, master := range masterRoutes {
			group := v1.Group(master.path)
			group.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionRead), master.controller.GetAll)
			group.PUT("/sync/:uuid", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionUpdate), master.controller.SyncUpsert)
			group.DELETE("/sync/:uuid", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionDelete), master.controller.SyncDeactivate)
			group.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionRead), master.controller.GetByID)
			group.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionCreate), master.controller.Create)
			group.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionUpdate), master.controller.Update)
			group.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, master.sidebarKey, middleware.PermissionDelete), master.controller.Delete)
		}
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
			sidebars.GET("/tree", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "sidebars", middleware.PermissionRead), sidebarController.GetTree)
			sidebars.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "sidebars", middleware.PermissionRead), sidebarController.GetByID)
		}
	}
	return r
}
