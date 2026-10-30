package routes

import (
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"context"
	"gorm.io/gorm"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
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
	server := httptest.NewServer(handler)
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	worker, err := services.NewPetugasPublicationWorker(pub, services.PublicationWorkerOptions{BatchSize: 20, Interval: 10 * time.Millisecond, AttemptTimeout: time.Second, MaxBackoff: time.Second}, nil)
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() { defer close(done); worker.Run(ctx) }()
	defer func() { cancel(); <-done }()
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
