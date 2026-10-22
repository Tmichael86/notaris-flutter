package main

import (
	"fmt"
	"log"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/routes"
	"backend-notaris-go/services"
)

func main() {
	cfg := config.LoadConfig()
	if err := database.ConnectDB(cfg); err != nil {
		log.Fatalf("Failed to initialize PostgreSQL: %v", err)
	}
	healthController := controllers.NewHealthController()
	pemohonController := controllers.NewPemohonController()
	petugasController := controllers.NewPetugasController()
	kategoriPekerjaanController := controllers.NewSimpleMasterController("pekerjaan_kategori", "kategori pekerjaan")
	jenisPengeluaranController := controllers.NewSimpleMasterController("pengeluaran_jenis", "jenis pengeluaran")
	groupController := controllers.NewGroupController()
	userController := controllers.NewUserController()
	authService := services.NewAuthService(cfg)
	authController := controllers.NewAuthController(authService)
	meController := controllers.NewMeController()
	sidebarService := services.NewSidebarService()
	sidebarController := controllers.NewSidebarController()
	sidebarAccessController := controllers.NewSidebarAccessController(sidebarService)

	r := routes.SetupRouter(cfg, healthController, pemohonController, petugasController, kategoriPekerjaanController, jenisPengeluaranController,
		groupController, userController, authController, meController, sidebarController, sidebarAccessController)
	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	fmt.Printf("Server running on port %s\n", cfg.Port)
	if err := r.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
