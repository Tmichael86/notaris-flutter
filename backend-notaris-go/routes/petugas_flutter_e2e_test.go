package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"context"
	"encoding/json"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

// Invoked only by an explicit test opt-in, after the ordinary HTTP fixture has
// created a fresh schema and applied the real migrations. No application .env.
func runFlutterPetugasE2E(t *testing.T, handler http.Handler, db *gorm.DB, token string) {
	t.Helper()
	if err := db.Exec("INSERT INTO petugas(uuid,row_version,nama,email,status,jenis_kelamin) VALUES(gen_random_uuid(),1,'E2E legacy','legacy@e2e.invalid',1,2)").Error; err != nil {
		t.Fatal(err)
	}
	pub := repositories.NewPetugasPublicationRepository(db)
	if n, err := pub.Bootstrap(context.Background()); err != nil || n != 1 {
		t.Fatalf("bootstrap: %d %v", n, err)
	}
	manual := os.Getenv("NOTARIS_MANUAL_DESKTOP") == "1"
	var manualDir, nonce string
	if manual {
		var err error
		manualDir, err = os.MkdirTemp("", "petugas-manual-")
		if err != nil {
			t.Fatal(err)
		}
		nonce = filepath.Base(manualDir)
		engine, ok := handler.(*gin.Engine)
		if !ok {
			t.Fatal("manual test requires real router")
		}
		engine.GET("/api/v1/petugas/testing/status", middleware.JWTAuth(config.Config{JWTSecret: "local-test-signing-key"}), middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "petugas", middleware.PermissionRead), func(c *gin.Context) { c.JSON(200, gin.H{"success": true, "data": gin.H{"nonce": nonce}}) })
	}
	server := httptest.NewServer(handler)
	defer server.Close()
	lifetime := 2 * time.Minute
	if manual {
		lifetime = 30 * time.Minute
	}
	ctx, cancel := context.WithTimeout(context.Background(), lifetime)
	defer cancel()
	worker, err := services.NewPetugasPublicationWorker(pub, services.PublicationWorkerOptions{BatchSize: 20, Interval: 10 * time.Millisecond, AttemptTimeout: time.Second, MaxBackoff: time.Second}, nil)
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() { defer close(done); worker.Run(ctx) }()
	defer func() { cancel(); <-done }()
	if manual {
		b, err := json.Marshal(map[string]string{"url": server.URL + "/api/v1", "token": token, "nonce": nonce})
		if err != nil {
			t.Fatal(err)
		}
		path := filepath.Join(manualDir, "session.json")
		if err := os.WriteFile(path, b, 0600); err != nil {
			t.Fatal(err)
		}
		t.Logf("MANUAL_SESSION_FILE=%s (contains test credentials; do not share contents)", path)
		t.Log("Isolated manual backend ready for 30 minutes. No manual UI success is asserted.")
		if os.Getenv("NOTARIS_MANUAL_SMOKE") == "1" {
			req, err := http.NewRequest("GET", server.URL+"/api/v1/petugas/testing/status", nil)
			if err != nil {
				t.Fatal(err)
			}
			req.Header.Set("Authorization", "Bearer "+token)
			resp, err := server.Client().Do(req)
			if err != nil {
				t.Fatal(err)
			}
			defer resp.Body.Close()
			var result struct {
				Data struct {
					Nonce string `json:"nonce"`
				}
			}
			if err := json.NewDecoder(resp.Body).Decode(&result); err != nil || resp.StatusCode != 200 || result.Data.Nonce != nonce {
				t.Fatal("manual readiness smoke failed")
			}
			t.Log("manual harness readiness smoke passed; no interactive UI executed")
			return
		}
		<-ctx.Done()
		return
	}
	args := []string{"test", "test/e2e/petugas_live_e2e_test.dart", "--reporter", "expanded"}
	var command *exec.Cmd
	if runtime.GOOS == "windows" {
		command = exec.CommandContext(ctx, "cmd", append([]string{"/c", "flutter"}, args...)...)
	} else {
		command = exec.CommandContext(ctx, "flutter", args...)
	}
	command.Dir = "../../frontend_notaris"
	command.Env = append(os.Environ(), "NOTARIS_E2E_URL="+server.URL+"/api/v1", "NOTARIS_E2E_TOKEN="+token)
	output, err := command.CombinedOutput()
	t.Log(strings.ReplaceAll(string(output), token, "[redacted]"))
	if err != nil {
		t.Fatalf("Flutter HTTP E2E failed: %v", err)
	}
	var rows int64
	if err := db.Table("petugas").Where("email = ?", "device@e2e.invalid").Count(&rows).Error; err != nil || rows != 1 {
		t.Fatalf("PostgreSQL did not persist Flutter write: %d %v", rows, err)
	}
}
