package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/internal/backendstartup"
	"backend-notaris-go/repositories"
	"backend-notaris-go/routes"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	cfg, err := config.LoadConfig()
	if err != nil {
		return err
	} // Configuration rejection precedes ALL database access.
	acceptance := os.Getenv("NOTARIS_UI_ACCEPTANCE_PLAN") != ""
	if acceptance && (cfg.HTTPHost != "127.0.0.1" || cfg.DBHost != "127.0.0.1" || cfg.DBPort != "5432" || cfg.DBName != "notarisdev" || cfg.Port != "8081" || cfg.PetugasPublisherEnabled) {
		return errors.New("acceptance requires the exact development target and publisher disabled")
	}
	if err := database.ConnectDB(cfg); err != nil {
		return errors.New("failed to initialize PostgreSQL")
	}
	pool, err := database.DB.DB()
	if err != nil {
		return err
	}
	defer pool.Close()
	readinessCtx, readinessCancel := context.WithTimeout(context.Background(), 10*time.Second)
	listener, err := backendstartup.Open(readinessCtx, cfg, database.DB, net.Listen)
	readinessCancel()
	if err != nil {
		return err
	}
	defer listener.Close()
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	var workers sync.WaitGroup
	if cfg.PetugasPublisherEnabled {
		worker, err := services.NewPetugasPublicationWorker(repositories.NewPetugasPublicationRepository(database.DB), services.PublicationWorkerOptions{BatchSize: cfg.PetugasPublisherBatch, Interval: cfg.PetugasPublisherInterval, AttemptTimeout: cfg.PetugasPublisherTimeout, MaxBackoff: cfg.PetugasPublisherMaxBackoff}, log.Default())
		if err != nil {
			return err
		}
		workers.Add(1)
		go func() { defer workers.Done(); worker.Run(ctx) }()
		log.Print("petugas publication worker enabled")
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

	gin.SetMode(gin.ReleaseMode) // GIN_MODE never selects or bypasses the security policy.
	r := routes.SetupRouter(cfg, healthController, pemohonController, petugasController, kategoriPekerjaanController, jenisPengeluaranController,
		groupController, userController, authController, meController, sidebarController, sidebarAccessController)
	fmt.Printf("Backend security ready: environment=%s deployment=%s\n", cfg.Environment, cfg.DeploymentID)
	server := &http.Server{Addr: cfg.ListenAddress(), Handler: r}
	finished := make(chan error, 1)
	go func() { finished <- server.Serve(listener) }()
	var serveErr error
	select {
	case <-ctx.Done():
	case serveErr = <-finished:
		cancel()
	}
	cancel()
	shutdownCtx, stop := context.WithTimeout(context.Background(), 15*time.Second)
	defer stop()
	if err := server.Shutdown(shutdownCtx); err != nil {
		_ = server.Close()
		log.Print("HTTP graceful shutdown deadline reached")
	}
	workers.Wait()
	if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
		return serveErr
	}
	return nil
}
