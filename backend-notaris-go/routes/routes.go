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
	syncController controllers.SyncController,
	groupController *controllers.GroupController,
	userController *controllers.UserController,
	authController *controllers.AuthController,
	meController *controllers.MeController,
	sidebarController *controllers.SidebarController,
	sidebarAccessController *controllers.SidebarAccessController,
	petugasController *controllers.PetugasController,
	kategoriPekerjaanController *controllers.KategoriPekerjaanController,
	jenisPengeluaranController *controllers.JenisPengeluaranController,
	pemohonController *controllers.PemohonController,
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
		}

		users := v1.Group("/users")
		{
			users.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionRead), userController.GetAll)
			users.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionRead), userController.GetByID)
			users.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionCreate), userController.Create)
			users.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionUpdate), userController.Update)
			users.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "users", middleware.PermissionDelete), userController.Delete)
		}

		groups := v1.Group("/groups")
		{
			groups.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionRead), groupController.GetAll)
			groups.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "groups", middleware.PermissionRead), groupController.GetByID)
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

		petugas := v1.Group("/petugas")
		{
			petugas.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetAll)
			petugas.GET("/jenis-kelamin", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetJenisKelamin)
			petugas.GET("/users", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetUsers)
			petugas.GET("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionRead), petugasController.GetByID)
			petugas.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionCreate), petugasController.Create)
			petugas.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionUpdate), petugasController.Update)
			petugas.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "petugas", middleware.PermissionDelete), petugasController.Delete)
		}

		kategoriPekerjaan := v1.Group("/kategori-pekerjaan")
		{
			kategoriPekerjaan.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "kategori_pekerjaan", middleware.PermissionRead), kategoriPekerjaanController.GetAll)
			kategoriPekerjaan.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "kategori_pekerjaan", middleware.PermissionCreate), kategoriPekerjaanController.Create)
			kategoriPekerjaan.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "kategori_pekerjaan", middleware.PermissionUpdate), kategoriPekerjaanController.Update)
			kategoriPekerjaan.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "kategori_pekerjaan", middleware.PermissionDelete), kategoriPekerjaanController.Delete)
		}

		pemohon := v1.Group("/pemohon")
		{
			pemohon.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionRead), pemohonController.GetAll)
			pemohon.GET("/jenis-kelamin", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionRead), pemohonController.GetJenisKelamin)
			pemohon.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionCreate), pemohonController.Create)
			pemohon.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionUpdate), pemohonController.Update)
			pemohon.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "pemohon", middleware.PermissionDelete), pemohonController.Delete)
		}

		jenisPengeluaran := v1.Group("/jenis-pengeluaran")
		{
			jenisPengeluaran.GET("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "jenis_pengeluaran", middleware.PermissionRead), jenisPengeluaranController.GetAll)
			jenisPengeluaran.POST("", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "jenis_pengeluaran", middleware.PermissionCreate), jenisPengeluaranController.Create)
			jenisPengeluaran.PUT("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "jenis_pengeluaran", middleware.PermissionUpdate), jenisPengeluaranController.Update)
			jenisPengeluaran.DELETE("/:id", middleware.JWTAuth(cfg), middleware.RequirePermission(sidebarAccessRepository, "jenis_pengeluaran", middleware.PermissionDelete), jenisPengeluaranController.Delete)
		}

		sync := v1.Group("/sync")
		{
			sync.POST("/push", syncController.Push)
			sync.GET("/pull", syncController.Pull)
		}
	}

	return r
}
