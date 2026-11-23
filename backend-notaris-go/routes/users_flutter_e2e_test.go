package routes

import (
	"crypto/rand"
	"encoding/hex"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
	"testing"
)

// Reuses the owned PostgreSQL P0 fixture and the registered authenticated routes.
// No token/password is placed in command arguments, output or fixture files.
func TestUsersSecurityFlutterV1HTTP(t *testing.T) {
	if os.Getenv("NOTARIS_USERS_V1_FLUTTER_E2E") != "1" {
		t.Skip("Flutter HTTP opt-in unset")
	}
	f := usersSetup(t)
	if f.db.Exec("INSERT INTO groups(id,group_nama,group_jenis,status,revision) VALUES(5,'Arsip','user',1,1)").Error != nil {
		t.Fatal("fixture group")
	}
	server := httptest.NewServer(f.api)
	defer server.Close()
	bytes := make([]byte, 24)
	if _, e := rand.Read(bytes); e != nil {
		t.Fatal("random")
	}
	password := hex.EncodeToString(bytes)
	token := f.token(1, nil)
	var before string
	f.db.Raw(`SELECT string_agg(row_to_json(t)::text,E'\n' ORDER BY id) FROM sidebar_akses t`).Scan(&before)
	cmd := exec.Command("flutter.bat", "test", "--no-pub", "test/e2e/users_v1_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	cmd.Env = append(os.Environ(), "NOTARIS_USERS_V1_HTTP="+server.URL+"/api/v1", "NOTARIS_USERS_V1_TOKEN="+token, "NOTARIS_USERS_V1_PASSWORD="+password)
	output, e := cmd.CombinedOutput()
	safe := strings.ReplaceAll(strings.ReplaceAll(string(output), password, "[REDACTED]"), token, "[REDACTED]")
	if e != nil {
		t.Fatalf("Flutter HTTP failed: %v\n%s", e, safe)
	}
	t.Log(safe)
	var row struct {
		GroupID, Revision, SecurityVersion int64
		Status                             int
	}
	if f.db.Table("users").Where("id=11").Take(&row).Error != nil || row.GroupID != 5 || row.Revision != 4 || row.SecurityVersion != 3 || row.Status != 0 {
		t.Fatal("committed lifecycle mismatch")
	}
	var success int64
	f.db.Table("administrative_audit").Where("result='success'").Count(&success)
	if success != 5 {
		t.Fatal("duplicate or missing success audit")
	}
	var after string
	f.db.Raw(`SELECT string_agg(row_to_json(t)::text,E'\n' ORDER BY id) FROM sidebar_akses t`).Scan(&after)
	if before != after {
		t.Fatal("grant mutation")
	}
	f.req(t, "GET", "/auth/me", 5, nil, 401)
}
