package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func backendTestEnvironment(t *testing.T) {
	t.Helper()
	t.Chdir(t.TempDir()) // No repository/private .env is ever read by these tests.
	for key, value := range map[string]string{
		"BACKEND_ENV": "staging", "BACKEND_DEPLOYMENT_ID": "qa-h05-test", "HTTP_HOST": "127.0.0.1", "PORT": "18081",
		"USERS_SECURITY_ENABLED": "true", "DB_HOST": "127.0.0.1", "DB_PORT": "55793", "DB_USER": "test-role", "DB_PASSWORD": "",
		"DB_NAME": "users_security_disposable", "DB_SSLMODE": "disable", "JWT_SECRET": "h05-unit-test-signing-only",
	} {
		t.Setenv(key, value)
	}
}

func TestH05SecurityConfiguration(t *testing.T) {
	for _, mode := range []string{"local", "staging", "production", "release"} {
		for _, value := range []string{"<unset>", "", "false", "yes", "1", "True", "malformed", "true"} {
			t.Run(mode+"/"+value, func(t *testing.T) {
				backendTestEnvironment(t)
				t.Setenv("BACKEND_ENV", mode)
				t.Setenv("USERS_SECURITY_ENABLED", value)
				if value == "<unset>" {
					os.Unsetenv("USERS_SECURITY_ENABLED")
				}
				cfg, err := LoadConfig()
				if value == "true" {
					if err != nil || !cfg.UsersSecurityEnabled {
						t.Fatalf("secure config rejected: %v", err)
					}
				} else if err == nil {
					t.Fatal("insecure configuration accepted")
				}
			})
		}
	}
}

func TestH05ExplicitConfiguration(t *testing.T) {
	for _, key := range []string{"BACKEND_ENV", "BACKEND_DEPLOYMENT_ID", "HTTP_HOST", "PORT", "DB_HOST", "DB_PORT", "DB_USER", "DB_NAME", "DB_SSLMODE", "JWT_SECRET"} {
		t.Run("missing/"+key, func(t *testing.T) {
			backendTestEnvironment(t)
			t.Setenv(key, "")
			if _, err := LoadConfig(); err == nil {
				t.Fatal("implicit deployment fallback accepted")
			}
		})
	}
	t.Run("historical dotenv cannot supply security or target", func(t *testing.T) {
		backendTestEnvironment(t)
		if err := os.WriteFile(filepath.Join(".", ".env"), []byte("USERS_SECURITY_ENABLED=true\nDB_NAME=notarislokal\n"), 0600); err != nil {
			t.Fatal(err)
		}
		t.Setenv("USERS_SECURITY_ENABLED", "")
		if _, err := LoadConfig(); err == nil {
			t.Fatal("dotenv supplied missing security approval")
		}
		t.Setenv("USERS_SECURITY_ENABLED", "true")
		cfg, err := LoadConfig()
		if err != nil || cfg.DBName != "users_security_disposable" {
			t.Fatal("historical .env overrode explicit target")
		}
		t.Setenv("DB_NAME", "")
		if _, err := LoadConfig(); err == nil {
			t.Fatal("dotenv target fallback accepted")
		}
	})
	for key, values := range map[string][]string{"BACKEND_ENV": {"debug", "development", "", "prod-typo"}, "BACKEND_DEPLOYMENT_ID": {"", "bad identity"}, "DB_NAME": {"notarislokal", "NOTARISLOKAL"}, "PORT": {"0", "65536", "8081:8082"}, "DB_PORT": {"abc", "0"}, "HTTP_HOST": {"localhost", ""}, "DB_SSLMODE": {"unknown", ""}} {
		for _, value := range values {
			t.Run(key+"/"+value, func(t *testing.T) {
				backendTestEnvironment(t)
				t.Setenv(key, value)
				if _, err := LoadConfig(); err == nil {
					t.Fatal("invalid deployment identity or target accepted")
				}
			})
		}
	}
	t.Run("GIN_MODE does not select security mode", func(t *testing.T) {
		backendTestEnvironment(t)
		t.Setenv("GIN_MODE", "release")
		t.Setenv("BACKEND_ENV", "")
		if _, err := LoadConfig(); err == nil {
			t.Fatal("GIN_MODE bypassed explicit environment")
		}
	})
	t.Run("errors do not echo secrets", func(t *testing.T) {
		backendTestEnvironment(t)
		t.Setenv("USERS_SECURITY_ENABLED", "credential-marker-not-a-boolean")
		_, err := LoadConfig()
		if err == nil || strings.Contains(err.Error(), "credential-marker") {
			t.Fatal("setting leaked or allowed")
		}
	})
}

func TestH05LocalListenerPolicy(t *testing.T) {
	for _, host := range []string{"0.0.0.0", "::", "192.0.2.1", "localhost"} {
		t.Run(host, func(t *testing.T) {
			backendTestEnvironment(t)
			t.Setenv("BACKEND_ENV", "local")
			t.Setenv("HTTP_HOST", host)
			if _, err := LoadConfig(); err == nil {
				t.Fatal("local mode exposed network listener")
			}
		})
	}
	for _, host := range []string{"localhost", "192.0.2.1"} {
		t.Run("db/"+host, func(t *testing.T) {
			backendTestEnvironment(t)
			t.Setenv("BACKEND_ENV", "local")
			t.Setenv("DB_HOST", host)
			if _, err := LoadConfig(); err == nil {
				t.Fatal("local mode admitted nonliteral/nonloopback database")
			}
		})
	}
	t.Run("IPv6 literal loopback", func(t *testing.T) {
		backendTestEnvironment(t)
		t.Setenv("BACKEND_ENV", "local")
		t.Setenv("HTTP_HOST", "::1")
		t.Setenv("DB_HOST", "::1")
		cfg, err := LoadConfig()
		if err != nil || cfg.ListenAddress() != "[::1]:18081" {
			t.Fatal("safe IPv6 loopback rejected")
		}
	})
}
