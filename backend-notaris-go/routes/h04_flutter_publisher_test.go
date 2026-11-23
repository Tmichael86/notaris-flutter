package routes

import (
	"context"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"
)

func TestH04FlutterSelectivePublishers(t *testing.T) {
	if os.Getenv("NOTARIS_H04_FLUTTER_E2E") != "1" {
		t.Skip("owned H04 publisher opt-in unset")
	}
	f := h04Setup(t)
	server := httptest.NewServer(f.api)
	defer server.Close()
	token := f.token(1, nil)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "flutter.bat", "test", "--no-pub", "test/e2e/h04_master_publishers_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	cmd.Env = append(os.Environ(), "NOTARIS_H04_HTTP="+server.URL+"/api/v1", "NOTARIS_H04_TOKEN="+token)
	output, e := cmd.CombinedOutput()
	safe := strings.ReplaceAll(string(output), token, "[REDACTED]")
	if e != nil {
		t.Fatalf("Flutter publishers failed: %v\n%s", e, safe)
	}
	t.Log(safe)
	for _, r := range h04Resources {
		var count int64
		if e := f.db.Table(r.table).Where("status=1 AND updated_by=1 AND nama LIKE '%updated'").Count(&count).Error; e != nil || count != 1 {
			t.Fatalf("%s committed publisher result mismatch: %d %v", r.code, count, e)
		}
	}
}
