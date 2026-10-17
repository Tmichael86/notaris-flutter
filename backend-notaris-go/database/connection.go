package database

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"time"

	"backend-notaris-go/config"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// ConnectDB opens the GORM connection and verifies PostgreSQL is reachable.
// It deliberately does not run AutoMigrate: the existing PostgreSQL schema is
// managed separately and must not be changed by application startup.
func ConnectDB(cfg config.Config) error {
	query := url.Values{}
	query.Set("sslmode", cfg.DBSSLMode)
	query.Set("TimeZone", "Asia/Jakarta")

	dsnURL := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(cfg.DBUser, cfg.DBPass),
		Host:     net.JoinHostPort(cfg.DBHost, cfg.DBPort),
		Path:     cfg.DBName,
		RawQuery: query.Encode(),
	}

	db, err := gorm.Open(postgres.Open(dsnURL.String()), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("open PostgreSQL connection: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("initialize PostgreSQL pool: %w", err)
	}
	sqlDB.SetMaxOpenConns(20)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		return fmt.Errorf("ping PostgreSQL: %w", err)
	}

	DB = db
	return nil
}

// Ping checks database readiness without exposing connection details to callers.
func Ping(ctx context.Context) error {
	if DB == nil {
		return fmt.Errorf("database connection is not initialized")
	}

	sqlDB, err := DB.DB()
	if err != nil {
		return fmt.Errorf("get PostgreSQL connection pool: %w", err)
	}
	if err := sqlDB.PingContext(ctx); err != nil {
		return fmt.Errorf("PostgreSQL is not reachable: %w", err)
	}
	return nil
}
