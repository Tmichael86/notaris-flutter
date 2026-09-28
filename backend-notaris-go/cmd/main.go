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
	// 1. Load Konfigurasi .env
	cfg := config.LoadConfig()

	// 2. Koneksi ke Database PostgreSQL
	database.ConnectDB(cfg)

	// 3. Inisialisasi Service & Controller
	syncService := services.NewSyncService()
	syncController := controllers.NewSyncController(syncService)
	healthController := controllers.NewHealthController()
	groupController := controllers.NewGroupController()
	userController := controllers.NewUserController()

	// 4. Setup Router Gin
	r := routes.SetupRouter(healthController, syncController, groupController, userController)

	// 5. Jalankan Server
	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	fmt.Printf(" Server running on port %s\n", cfg.Port)
	if err := r.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
