package config

import (
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	Port             string `mapstructure:"PORT"`
	DBHost           string `mapstructure:"DB_HOST"`
	DBPort           string `mapstructure:"DB_PORT"`
	DBUser           string `mapstructure:"DB_USER"`
	DBPass           string `mapstructure:"DB_PASSWORD"`
	DBName           string `mapstructure:"DB_NAME"`
	JWTSecret        string `mapstructure:"JWT_SECRET"`
	JWTExpireMinutes int    `mapstructure:"JWT_EXPIRE_MINUTES"`
}

func LoadConfig() (config Config) {
	viper.SetConfigFile(".env")
	viper.AutomaticEnv()

	err := viper.ReadInConfig()
	if err != nil {
		log.Fatalf("Error reading config file: %s", err)
	}

	err = viper.Unmarshal(&config)
	if err != nil {
		log.Fatalf("Unable to decode into struct: %s", err)
	}

	if config.JWTExpireMinutes <= 0 {
		config.JWTExpireMinutes = 120
	}

	if config.JWTSecret == "" {
		log.Fatal("JWT_SECRET is required")
	}

	return
}
