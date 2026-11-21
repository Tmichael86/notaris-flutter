package main

import (
	"os"
	"testing"

	"backend-notaris-go/database"
)

// Exercise the actual entrypoint, not only config helpers. No configuration
// below can reach ConnectDB, workers, router construction or listener creation.
func TestH05MainRejectsBeforeDatabase(t *testing.T) {
	t.Chdir(t.TempDir())
	if err := os.WriteFile(".env", []byte("DB_NAME=notarislokal\nUSERS_SECURITY_ENABLED=false\n"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, mode := range []string{"staging", "production", "release", "local"} {
		for _, flag := range []string{"", "false", "malformed"} {
			t.Run(mode+"/"+flag, func(t *testing.T) {
				t.Setenv("BACKEND_ENV", mode)
				t.Setenv("USERS_SECURITY_ENABLED", flag)
				previous := database.DB
				if err := run(); err == nil {
					t.Fatal("insecure main startup succeeded")
				}
				if database.DB != previous {
					t.Fatal("startup reached database initialization")
				}
			})
		}
	}
}
