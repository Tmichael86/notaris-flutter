package config

import (
	"testing"
	"time"
)

func TestPublicationEnvironmentConfiguration(t *testing.T) {
	backendTestEnvironment(t) // Explicit secure config; no .env or real database.
	for _, key := range []string{"PETUGAS_PUBLISHER_ENABLED", "PETUGAS_PUBLISHER_BATCH", "PETUGAS_PUBLISHER_INTERVAL", "PETUGAS_PUBLISHER_TIMEOUT", "PETUGAS_PUBLISHER_MAX_BACKOFF"} {
		t.Setenv(key, "")
	}
	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PetugasPublisherEnabled || cfg.PetugasPublisherBatch != 100 || cfg.PetugasPublisherInterval != time.Second || cfg.PetugasPublisherTimeout != 10*time.Second || cfg.PetugasPublisherMaxBackoff != 30*time.Second {
		t.Fatal("unsafe publisher defaults")
	}
	t.Setenv("PETUGAS_PUBLISHER_ENABLED", "true")
	t.Setenv("PETUGAS_PUBLISHER_BATCH", "7")
	t.Setenv("PETUGAS_PUBLISHER_INTERVAL", "2s")
	cfg, err = LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.PetugasPublisherEnabled || cfg.PetugasPublisherBatch != 7 || cfg.PetugasPublisherInterval != 2*time.Second {
		t.Fatal("environment overrides ignored")
	}
}
