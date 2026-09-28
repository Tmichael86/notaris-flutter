package database

import (
	"fmt"
	"log"

	"backend-notaris-go/config"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func ConnectDB(cfg config.Config) {
	// Ganti fmt.sprintf -> fmt.Sprintf
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=Asia/Jakarta",
		cfg.DBHost, cfg.DBUser, cfg.DBPass, cfg.DBName, cfg.DBPort)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to PostgreSQL database: ", err)
	}

	fmt.Println(" Connected to PostgreSQL Database!")
	DB = db
}
