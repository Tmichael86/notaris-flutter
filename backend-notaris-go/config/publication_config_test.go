package config

import (
	"testing"
	"time"
)

func TestPublicationEnvironmentConfiguration(t *testing.T) {
	t.Chdir(t.TempDir()) // Never load a development .env in a configuration test.
	t.Setenv("JWT_SECRET", "test-only")
	t.Setenv("DB_HOST", "unused-test-host")
	t.Setenv("DB_USER", "unused-test-user")
	t.Setenv("DB_NAME", "unused-test-db")
	for _, key := range []string{"PETUGAS_PUBLISHER_ENABLED", "PETUGAS_PUBLISHER_BATCH", "PETUGAS_PUBLISHER_INTERVAL", "PETUGAS_PUBLISHER_TIMEOUT", "PETUGAS_PUBLISHER_MAX_BACKOFF"} {
		t.Setenv(key, "")
	}
	cfg := LoadConfig()
	if cfg.PetugasPublisherEnabled || cfg.PetugasPublisherBatch != 100 || cfg.PetugasPublisherInterval != time.Second || cfg.PetugasPublisherTimeout != 10*time.Second || cfg.PetugasPublisherMaxBackoff != 30*time.Second {
		t.Fatal("unsafe publisher defaults")
	}
	t.Setenv("PETUGAS_PUBLISHER_ENABLED", "true")
	t.Setenv("PETUGAS_PUBLISHER_BATCH", "7")
	t.Setenv("PETUGAS_PUBLISHER_INTERVAL", "2s")
	cfg = LoadConfig()
	if !cfg.PetugasPublisherEnabled || cfg.PetugasPublisherBatch != 7 || cfg.PetugasPublisherInterval != 2*time.Second {
		t.Fatal("environment overrides ignored")
	}
}
