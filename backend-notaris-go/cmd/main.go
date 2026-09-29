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
	database.ConnectDB(cfg)

	syncService := services.NewSyncService()
	syncController := controllers.NewSyncController(syncService)
	healthController := controllers.NewHealthController()
	groupController := controllers.NewGroupController()
	userController := controllers.NewUserController()
	authService := services.NewAuthService(cfg)
	authController := controllers.NewAuthController(authService)
	meController := controllers.NewMeController()
	sidebarService := services.NewSidebarService()
	sidebarController := controllers.NewSidebarController()
	sidebarAccessController := controllers.NewSidebarAccessController(sidebarService)

	r := routes.SetupRouter(cfg, healthController, syncController, groupController, userController, authController, meController, sidebarController, sidebarAccessController)

	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	fmt.Printf(" Server running on port %s\\n", cfg.Port)
	if err := r.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
