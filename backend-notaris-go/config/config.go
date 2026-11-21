package config

import (
	"errors"
	"net"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Environment                string
	DeploymentID               string
	HTTPHost                   string
	Port                       string `mapstructure:"PORT"`
	DBHost                     string `mapstructure:"DB_HOST"`
	DBPort                     string `mapstructure:"DB_PORT"`
	DBUser                     string `mapstructure:"DB_USER"`
	DBPass                     string `mapstructure:"DB_PASSWORD"`
	DBName                     string `mapstructure:"DB_NAME"`
	DBSSLMode                  string `mapstructure:"DB_SSLMODE"`
	JWTSecret                  string `mapstructure:"JWT_SECRET"`
	JWTExpireMinutes           int    `mapstructure:"JWT_EXPIRE_MINUTES"`
	UsersSecurityEnabled       bool   `mapstructure:"USERS_SECURITY_ENABLED"`
	PetugasPublisherEnabled    bool
	PetugasPublisherBatch      int
	PetugasPublisherInterval   time.Duration
	PetugasPublisherTimeout    time.Duration
	PetugasPublisherMaxBackoff time.Duration
}

// LoadConfig reads process environment only. Historical .env files are never
// implicit deployment configuration; launchers must explicitly export reviewed
// settings. All normal backend modes require P0, including local development.
func LoadConfig() (Config, error) {
	v := viper.New()
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()
	v.SetDefault("JWT_EXPIRE_MINUTES", 120)
	v.SetDefault("PETUGAS_PUBLISHER_ENABLED", false)
	v.SetDefault("PETUGAS_PUBLISHER_BATCH", 100)
	v.SetDefault("PETUGAS_PUBLISHER_INTERVAL", "1s")
	v.SetDefault("PETUGAS_PUBLISHER_TIMEOUT", "10s")
	v.SetDefault("PETUGAS_PUBLISHER_MAX_BACKOFF", "30s")
	// No boolean coercion: 1, yes, invalid, false and missing all fail closed.
	if value, ok := os.LookupEnv("USERS_SECURITY_ENABLED"); !ok || value != "true" {
		return Config{}, errors.New("USERS_SECURITY_ENABLED must be explicitly true")
	}
	for _, key := range []string{"BACKEND_ENV", "BACKEND_DEPLOYMENT_ID", "HTTP_HOST", "PORT", "DB_HOST", "DB_PORT", "DB_USER", "DB_NAME", "DB_SSLMODE", "JWT_SECRET"} {
		if value, ok := os.LookupEnv(key); !ok || strings.TrimSpace(value) == "" {
			return Config{}, errors.New("explicit backend setting required: " + key)
		}
	}
	cfg := Config{
		Environment: v.GetString("BACKEND_ENV"), DeploymentID: v.GetString("BACKEND_DEPLOYMENT_ID"), HTTPHost: v.GetString("HTTP_HOST"),
		Port: v.GetString("PORT"), DBHost: v.GetString("DB_HOST"), DBPort: v.GetString("DB_PORT"), DBUser: v.GetString("DB_USER"),
		DBPass: v.GetString("DB_PASSWORD"), DBName: v.GetString("DB_NAME"), DBSSLMode: v.GetString("DB_SSLMODE"), JWTSecret: v.GetString("JWT_SECRET"),
		JWTExpireMinutes: v.GetInt("JWT_EXPIRE_MINUTES"), UsersSecurityEnabled: true,
		PetugasPublisherEnabled: v.GetBool("PETUGAS_PUBLISHER_ENABLED"), PetugasPublisherBatch: v.GetInt("PETUGAS_PUBLISHER_BATCH"),
		PetugasPublisherInterval: v.GetDuration("PETUGAS_PUBLISHER_INTERVAL"), PetugasPublisherTimeout: v.GetDuration("PETUGAS_PUBLISHER_TIMEOUT"),
		PetugasPublisherMaxBackoff: v.GetDuration("PETUGAS_PUBLISHER_MAX_BACKOFF"),
	}
	if cfg.JWTExpireMinutes <= 0 {
		cfg.JWTExpireMinutes = 120
	}
	if err := cfg.ValidateStartup(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

var deploymentIdentity = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{2,79}$`)

func (c Config) ValidateStartup() error {
	switch c.Environment {
	case "local", "staging", "production", "release":
	default:
		return errors.New("BACKEND_ENV must explicitly identify local, staging, production or release")
	}
	if !c.UsersSecurityEnabled {
		return errors.New("backend P0 security is required in every mode")
	}
	if !deploymentIdentity.MatchString(c.DeploymentID) {
		return errors.New("invalid BACKEND_DEPLOYMENT_ID")
	}
	host := net.ParseIP(c.HTTPHost)
	if host == nil {
		return errors.New("HTTP_HOST must be an explicit IP address")
	}
	for _, port := range []string{c.Port, c.DBPort} {
		number, err := strconv.Atoi(port)
		if err != nil || number < 1 || number > 65535 {
			return errors.New("explicit valid HTTP and PostgreSQL ports required")
		}
	}
	if strings.TrimSpace(c.DBHost) == "" || strings.TrimSpace(c.DBUser) == "" || strings.TrimSpace(c.DBName) == "" || strings.TrimSpace(c.JWTSecret) == "" {
		return errors.New("explicit database target, role and JWT configuration required")
	}
	if strings.EqualFold(strings.TrimSpace(c.DBName), "notarislokal") {
		return errors.New("protected database target is not permitted")
	}
	switch c.DBSSLMode {
	case "disable", "allow", "prefer", "require", "verify-ca", "verify-full":
	default:
		return errors.New("explicit valid DB_SSLMODE required")
	}
	if c.Environment == "local" {
		dbHost := net.ParseIP(c.DBHost)
		if !host.IsLoopback() || dbHost == nil || !dbHost.IsLoopback() {
			return errors.New("local backend requires literal loopback HTTP and PostgreSQL targets")
		}
	}
	return nil
}

func (c Config) ListenAddress() string { return net.JoinHostPort(c.HTTPHost, c.Port) }
