package config

import (
	"log"
	"os"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	Port             string `mapstructure:"PORT"`
	DBHost           string `mapstructure:"DB_HOST"`
	DBPort           string `mapstructure:"DB_PORT"`
	DBUser           string `mapstructure:"DB_USER"`
	DBPass           string `mapstructure:"DB_PASSWORD"`
	DBName           string `mapstructure:"DB_NAME"`
	DBSSLMode        string `mapstructure:"DB_SSLMODE"`
	JWTSecret        string `mapstructure:"JWT_SECRET"`
	JWTExpireMinutes int    `mapstructure:"JWT_EXPIRE_MINUTES"`
}

// LoadConfig reads .env when present and always permits environment variables
// to override it, which is suitable for local development and deployment.
func LoadConfig() (config Config) {
	viper.Reset()
	viper.SetConfigFile(".env")
	viper.SetConfigType("env")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	viper.SetDefault("PORT", "8080")
	viper.SetDefault("DB_PORT", "5432")
	viper.SetDefault("DB_SSLMODE", "disable")
	viper.SetDefault("JWT_EXPIRE_MINUTES", 120)

	if _, err := os.Stat(".env"); err == nil {
		if err := viper.ReadInConfig(); err != nil {
			log.Fatalf("Unable to read configuration: %v", err)
		}
	} else if !os.IsNotExist(err) {
		log.Fatalf("Unable to inspect configuration file: %v", err)
	}

	config = Config{
		Port:             viper.GetString("PORT"),
		DBHost:           viper.GetString("DB_HOST"),
		DBPort:           viper.GetString("DB_PORT"),
		DBUser:           viper.GetString("DB_USER"),
		DBPass:           viper.GetString("DB_PASSWORD"),
		DBName:           viper.GetString("DB_NAME"),
		DBSSLMode:        viper.GetString("DB_SSLMODE"),
		JWTSecret:        viper.GetString("JWT_SECRET"),
		JWTExpireMinutes: viper.GetInt("JWT_EXPIRE_MINUTES"),
	}

	if config.JWTExpireMinutes <= 0 {
		config.JWTExpireMinutes = 120
	}

	if config.JWTSecret == "" {
		log.Fatal("JWT_SECRET is required")
	}
	if config.DBHost == "" || config.DBUser == "" || config.DBName == "" {
		log.Fatal("DB_HOST, DB_USER, and DB_NAME are required")
	}

	return
}
