package routes

import (
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/services"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"
)

func profileFixture(t *testing.T) usersFixture {
	f := usersSetup(t)
	if e := f.db.Exec(`CREATE TABLE transaksi(id bigint PRIMARY KEY,locked_by bigint,locked_at timestamptz);INSERT INTO transaksi VALUES(1,3,'2026-11-21T00:00:00Z');CREATE TABLE protected_ledger(id bigint PRIMARY KEY,payment bigint,materai bigint,cursor bigint,ack text);INSERT INTO protected_ledger VALUES(1,500000,12,9,'protected');`).Error; e != nil {
		t.Fatal(e)
	}
	return f
}
func profileBody(rev int) map[string]any {
	return map[string]any{"expected_revision": rev, "nama": "Nama Diperbarui", "no_telp": " +62 812-0000 ", "alamat": nil}
}
func profileProtected(t *testing.T, f usersFixture, id uint) string {
	t.Helper()
	var s string
	if e := f.db.Raw(`SELECT json_build_object('own',(SELECT row_to_json(t)FROM(SELECT id,group_id,username,email,password,status,security_version,image FROM users WHERE id=?)t),'others',(SELECT json_agg(t ORDER BY id)FROM users t WHERE id<>?),'groups',(SELECT json_agg(t ORDER BY id)FROM groups t),'sidebar',(SELECT json_agg(t ORDER BY id)FROM sidebar t),'grants',(SELECT json_agg(t ORDER BY id)FROM sidebar_akses t),'locks',(SELECT json_agg(t ORDER BY id)FROM transaksi t),'ledger',(SELECT json_agg(t ORDER BY id)FROM protected_ledger t))::text`, id, id).Scan(&s).Error; e != nil {
		t.Fatal(e)
	}
	return s
}
func TestProfileOwnAccountAndAudit(t *testing.T) {
	for _, id := range []uint{1, 2, 3, 4, 5} {
		t.Run(string(rune('a'+id)), func(t *testing.T) {
			f := profileFixture(t)
			before := profileProtected(t, f, id)
			got := f.req(t, "GET", "/profile", id, nil, 200)["data"].(map[string]any)
			if len(got) != 11 || got["id"] != float64(id) {
				t.Fatal("DTO")
			}
			result := f.req(t, "PATCH", "/profile", id, profileBody(1), 200)["data"].(map[string]any)
			if result["revision"] != float64(2) || result["no_telp"] != "+62 812-0000" || result["alamat"] != nil {
				t.Fatal("readback")
			}
			f.req(t, "GET", "/profile", id, nil, 200)
			if profileProtected(t, f, id) != before {
				t.Fatal("protected state changed")
			}
			var audit string
			f.db.Raw("SELECT row_to_json(t)::text FROM administrative_audit t WHERE action='profile_self_update'").Scan(&audit)
			var a map[string]any
			if json.Unmarshal([]byte(audit), &a) != nil || a["actor_id"] != float64(id) || a["target_id"] != float64(id) || a["target_type"] != "self_profile" || a["result"] != "success" {
				t.Fatal("self audit")
			}
			if strings.Contains(audit, "Nama Diperbarui") || strings.Contains(audit, "+62") || strings.Contains(audit, "password") || strings.Contains(audit, "$2a$") {
				t.Fatal("audit secrets")
			}
			if a["before_state"].(map[string]any)["revision"] != float64(1) || a["after_state"].(map[string]any)["revision"] != float64(2) {
				t.Fatal("audit revision")
			}
		})
	}
}
func TestProfileStrictPayload(t *testing.T) {
	f := profileFixture(t)
	before := profileProtected(t, f, 3)
	for _, k := range []string{"id", "user_id", "group_id", "group_jenis", "role", "status", "security_version", "username", "email", "password", "password_hash", "user_img", "revision", "image", "unknown"} {
		b := profileBody(1)
		b[k] = 1
		f.req(t, "PATCH", "/profile", 3, b, 400)
	}
	for _, k := range []string{"expected_revision", "nama", "no_telp", "alamat"} {
		b := profileBody(1)
		delete(b, k)
		f.req(t, "PATCH", "/profile", 3, b, 400)
	}
	for _, v := range []any{nil, " ", strings.Repeat("n", 161), "bad\x00name", true} {
		b := profileBody(1)
		b["nama"] = v
		f.req(t, "PATCH", "/profile", 3, b, 400)
	}
	for k, v := range map[string]any{"no_telp": strings.Repeat("a", 33), "alamat": strings.Repeat("a", 256), "expected_revision": 0} {
		b := profileBody(1)
		b[k] = v
		f.req(t, "PATCH", "/profile", 3, b, 400)
	}
	for _, raw := range []string{`{"expected_revision":1,"nama":"A","nama":"B","no_telp":null,"alamat":null}`, `null`, `[]`, `{"expected_revision":1,"nama":"A","no_telp":null,"alamat":null}{}`, string([]byte{0xff}), strings.Repeat("a", 32769)} {
		q := httptest.NewRequest("PATCH", "/api/v1/profile", strings.NewReader(raw))
		q.Header.Set("Authorization", "Bearer "+f.token(3, nil))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		if w.Code != 400 {
			t.Fatal("shape", w.Code)
		}
	}
	for _, path := range []string{"/profile?id=1", "/profile?user_id=2"} {
		f.req(t, "GET", path, 3, nil, 400)
		f.req(t, "PATCH", path, 3, profileBody(1), 400)
	}
	q := httptest.NewRequest("PATCH", "/api/v1/profile", bytes.NewBufferString(`{"expected_revision":1,"nama":"A","no_telp":null,"alamat":null}`))
	q.Header.Set("Authorization", "Bearer "+f.token(3, nil))
	q.Header.Set("X-User-ID", "1")
	w := httptest.NewRecorder()
	f.api.ServeHTTP(w, q)
	if w.Code != 400 {
		t.Fatal("header")
	}
	if profileProtected(t, f, 3) != before {
		t.Fatal("forged writes")
	}
	f.db.Exec(`DELETE FROM sidebar_akses WHERE group_id=2`)
	f.req(t, "PATCH", "/profile", 3, profileBody(1), 200)
	b := profileBody(2)
	b["nama"] = strings.Repeat("\u754c", 160)
	b["no_telp"] = nil
	b["alamat"] = strings.Repeat("\u754c", 255)
	f.req(t, "PATCH", "/profile", 3, b, 200)
}
func TestProfileJWTConflictAndRollback(t *testing.T) {
	f := profileFixture(t)
	f.req(t, "GET", "/profile", 0, nil, 401)
	f.req(t, "PATCH", "/profile", 6, profileBody(1), 401)
	for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { delete(c, "sv") }, func(c jwt.MapClaims) { c["sv"] = 2 }, func(c jwt.MapClaims) { delete(c, "exp") }, func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }} {
		q := httptest.NewRequest("GET", "/api/v1/profile", nil)
		q.Header.Set("Authorization", "Bearer "+f.token(3, change))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		if w.Code != 401 {
			t.Fatal("JWT")
		}
	}
	f.req(t, "PATCH", "/profile", 3, profileBody(2), 409)
	before := profileProtected(t, f, 3)
	if e := f.db.Exec(`CREATE FUNCTION reject_profile_audit()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='profile_self_update' THEN RAISE EXCEPTION 'test failure';END IF;RETURN NEW;END$$;CREATE TRIGGER reject_profile BEFORE INSERT ON administrative_audit FOR EACH ROW EXECUTE FUNCTION reject_profile_audit()`).Error; e != nil {
		t.Fatal(e)
	}
	f.req(t, "PATCH", "/profile", 3, profileBody(1), 500)
	var rev int
	f.db.Raw("SELECT revision FROM users WHERE id=3").Scan(&rev)
	if rev != 1 || profileProtected(t, f, 3) != before {
		t.Fatal("rollback")
	}
	f.db.Exec("UPDATE groups SET status=0 WHERE id=2")
	f.req(t, "GET", "/profile", 3, nil, 401)
}
func TestProfileConcurrentAdministration(t *testing.T) {
	for _, kind := range []string{"edit", "reset", "deactivate", "reassign"} {
		t.Run(kind, func(t *testing.T) {
			f := profileFixture(t)
			f.db.Exec("INSERT INTO groups(id,group_nama,group_jenis,status,revision)VALUES(5,'Destination','user',1,1)")
			var wg sync.WaitGroup
			wg.Add(2)
			out := make(chan int, 2)
			request := func(method, path string, id uint, b any) {
				defer wg.Done()
				raw, _ := json.Marshal(b)
				q := httptest.NewRequest(method, "/api/v1"+path, bytes.NewReader(raw))
				q.Header.Set("Authorization", "Bearer "+f.token(id, nil))
				w := httptest.NewRecorder()
				f.api.ServeHTTP(w, q)
				out <- w.Code
			}
			go request("PATCH", "/profile", 3, profileBody(1))
			switch kind {
			case "edit", "reassign":
				b := map[string]any{"expected_revision": 1, "group_id": 2, "username": "user3", "email": "user3@example.invalid", "nama": "Admin Changed"}
				if kind == "reassign" {
					b["group_id"] = 5
				}
				go request("PUT", "/users/3", 1, b)
			case "reset":
				go request("POST", "/users/3/password-reset", 1, map[string]any{"expected_revision": 1, "password": "disposable-safe-password", "password_confirm": "disposable-safe-password"})
			case "deactivate":
				go request("DELETE", "/users/3", 1, map[string]any{"expected_revision": 1})
			}
			wg.Wait()
			close(out)
			success := 0
			for s := range out {
				if s == 200 {
					success++
				} else if s != 409 && s != 401 {
					t.Fatal(s)
				}
			}
			if success != 1 {
				t.Fatal("one winner", success)
			}
		})
	}
}
func TestProfileActorRevalidatedUnderLock(t *testing.T) {
	for _, change := range []string{"UPDATE users SET status=0 WHERE id=3", "UPDATE users SET security_version=2 WHERE id=3", "UPDATE groups SET status=0 WHERE id=2"} {
		f := profileFixture(t)
		tx := f.db.Begin()
		tx.Exec("SELECT pg_advisory_xact_lock(?)", services.AdminLock)
		done := make(chan error, 1)
		go func() {
			_, e := (services.ProfileService{DB: f.db, Enabled: true}).Update(context.Background(), actor(3), services.ProfileInput{ExpectedRevision: 1, Nama: "Blocked"})
			done <- e
		}()
		deadline := time.Now().Add(3 * time.Second)
		waiting := false
		for time.Now().Before(deadline) {
			var n int64
			f.db.Raw("SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND NOT granted").Scan(&n)
			if n > 0 {
				waiting = true
				break
			}
			time.Sleep(10 * time.Millisecond)
		}
		if !waiting {
			tx.Rollback()
			t.Fatal("lock wait")
		}
		tx.Exec(change)
		tx.Commit()
		if e := <-done; e == nil {
			t.Fatal("stale actor")
		}
		var u models.User
		f.db.First(&u, 3)
		if u.Nama == "Blocked" || u.Revision != 1 {
			t.Fatal("unsafe write")
		}
	}
}
func TestProfileFlutterHTTP(t *testing.T) {
	if os.Getenv("NOTARIS_PROFILE_V1_FLUTTER_E2E") != "1" {
		t.Skip("Flutter opt-in")
	}
	f := profileFixture(t)
	before := profileProtected(t, f, 3)
	server := httptest.NewServer(f.api)
	defer server.Close()
	token := f.token(3, func(c jwt.MapClaims) { c["gid"] = 2 })
	cmd := exec.Command("flutter.bat", "test", "--no-pub", "test/e2e/profile_v1_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	cmd.Env = append(os.Environ(), "NOTARIS_PROFILE_V1_HTTP="+server.URL+"/api/v1", "NOTARIS_PROFILE_V1_TOKEN="+token)
	output, e := cmd.CombinedOutput()
	safe := strings.ReplaceAll(string(output), token, "[REDACTED]")
	if e != nil {
		t.Fatalf("Flutter: %s", safe)
	}
	t.Log(safe)
	if profileProtected(t, f, 3) != before {
		t.Fatal("protected UI state")
	}
}

func TestProfileCutoverDisabled(t *testing.T) {
	s := services.ProfileService{Enabled: false}
	if _, e := s.Read(context.Background(), actor(1)); e == nil {
		t.Fatal("disabled read")
	}
	if _, e := s.Update(context.Background(), actor(1), services.ProfileInput{ExpectedRevision: 1, Nama: "No write"}); e == nil {
		t.Fatal("disabled mutation")
	}
}

func TestProfileConcurrentGroupDeactivation(t *testing.T) {
	f := profileFixture(t)
	var membership string
	if e := f.db.Raw("SELECT " + services.GroupMembershipSQL + " FROM users m WHERE m.group_id=2").Scan(&membership).Error; e != nil {
		t.Fatal(e)
	}
	type outcome struct {
		operation string
		status    int
	}
	out := make(chan outcome, 2)
	request := func(operation, method, path string, id uint, body any) {
		raw, _ := json.Marshal(body)
		q := httptest.NewRequest(method, "/api/v1"+path, bytes.NewReader(raw))
		q.Header.Set("Authorization", "Bearer "+f.token(id, nil))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		out <- outcome{operation, w.Code}
	}
	go request("profile", "PATCH", "/profile", 3, profileBody(1))
	go request("group", "DELETE", "/groups/2", 1, map[string]any{"expected_revision": 1, "expected_membership": membership})
	profileStatus := 0
	for i := 0; i < 2; i++ {
		v := <-out
		if v.operation == "group" && v.status != 200 {
			t.Fatal("group deactivation", v.status)
		}
		if v.operation == "profile" {
			profileStatus = v.status
			if v.status != 200 && v.status != 401 && v.status != 403 {
				t.Fatal("profile", v.status)
			}
		}
	}
	var user models.User
	f.db.First(&user, 3)
	if user.SecurityVersion != 2 {
		t.Fatal("revocation")
	}
	var audits int64
	f.db.Table("administrative_audit").Where("action='profile_self_update'").Count(&audits)
	if (profileStatus == 200 && audits != 1) || (profileStatus != 200 && (audits != 0 || user.Revision != 1)) {
		t.Fatal("partial profile commit")
	}
	if (services.Administration{DB: f.db, Enabled: true}).Ready(context.Background()) != nil {
		t.Fatal("recovery lost")
	}
}

func TestProfileHTTPColumnLimitedRole(t *testing.T) {
	f := profileFixture(t)
	var schema string
	f.db.Raw("SELECT current_schema()").Scan(&schema)
	role := fmt.Sprintf("profile_role_%d", time.Now().UnixNano())
	if e := f.db.Exec(fmt.Sprintf(`CREATE ROLE %s NOLOGIN;GRANT USAGE ON SCHEMA %s TO %s;GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s;GRANT UPDATE(nama,no_telp,alamat,revision,updated_at,updated_by) ON users TO %s;GRANT INSERT ON administrative_audit TO %s;GRANT USAGE ON SEQUENCE administrative_audit_id_seq TO %s`, role, schema, role, schema, role, role, role, role)).Error; e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { f.db.Exec("DROP OWNED BY " + role); f.db.Exec("DROP ROLE " + role) })
	tx := f.db.Begin()
	defer tx.Rollback()
	if e := tx.Exec("SET LOCAL ROLE " + role).Error; e != nil {
		t.Fatal(e)
	}
	old := database.DB
	database.DB = tx
	defer func() { database.DB = old }()
	pc := controllers.NewProfileController(f.cfg)
	router := gin.New()
	router.PATCH("/api/v1/profile", pc.Prepare, middleware.JWTAuth(f.cfg), pc.Patch)
	raw, _ := json.Marshal(profileBody(1))
	q := httptest.NewRequest("PATCH", "/api/v1/profile", bytes.NewReader(raw))
	q.Header.Set("Authorization", "Bearer "+f.token(3, nil))
	w := httptest.NewRecorder()
	router.ServeHTTP(w, q)
	if w.Code != 200 {
		t.Fatal("column-limited runtime HTTP", w.Code)
	}
	tx.Rollback()
	var u models.User
	f.db.First(&u, 3)
	if u.Revision != 1 {
		t.Fatal("outer disposable rollback")
	}
}
