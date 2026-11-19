package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"backend-notaris-go/database"
	"backend-notaris-go/services"
	"github.com/golang-jwt/jwt/v5"
)

func TestPromotionalAttestationReadOnly(t *testing.T) {
	id := os.Getenv("NOTARIS_PROMOTIONAL_TEST_PROFILE")
	if id == "" {
		t.Skip("owned promotional profile opt-in required")
	}
	root, s, e := promotionalRoot(id)
	if e != nil {
		t.Fatal("profile unavailable")
	}
	db, e := promoOpen(id, false, false)
	if e != nil {
		t.Fatal("bound app database unavailable")
	}
	defer closePromo(db)
	prior := database.DB
	defer func() { database.DB = prior }()
	server := httptest.NewServer(promotionalHandler(id, db, s))
	defer server.Close()
	info, e := promotionalContext(id, db, s, server.URL)
	if e != nil {
		t.Fatal("authenticated context unavailable")
	}
	version := int64(1)
	claims := services.Claims{UID: info.UserID, GID: info.GroupID, Version: &version, RegisteredClaims: jwt.RegisteredClaims{Issuer: "backend-notaris-go", ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Minute))}}
	token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(s.JWTSecret))
	request, _ := http.NewRequest("GET", server.URL+"/api/v1/development/promotional", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	result, e := http.DefaultClient.Do(request)
	if e != nil {
		t.Fatal("attestation failed")
	}
	defer result.Body.Close()
	var value map[string]any
	if result.StatusCode != 200 || json.NewDecoder(result.Body).Decode(&value) != nil || value["profile"] != id || value["database"] != promoManifest(id).Database || value["port"] != float64(promoPGPort) || value["host"] != "127.0.0.1" || value["marker"] != "NOTARIS PROMOTIONAL DISPOSABLE "+id {
		t.Fatal("active connection attestation mismatch")
	}
	log, e := os.ReadFile(filepath.Join(root, "postgres.log"))
	if e != nil {
		t.Fatal("owned log unavailable")
	}
	for _, secret := range []string{s.OwnerPassword, s.AppPassword, s.JWTSecret, s.LoginPassword} {
		if strings.Contains(string(log), secret) {
			t.Fatal("secret present in owned demo log")
		}
	}
}

func TestPromotionalHTTPAllowlist(t *testing.T) {
	for _, test := range []struct {
		method, path string
		allowed      bool
	}{
		{"POST", "/api/v1/auth/login", true}, {"GET", "/api/v1/auth/me", true}, {"GET", "/api/v1/users", true},
		{"POST", "/api/v1/users", false}, {"PUT", "/api/v1/groups/104", false}, {"DELETE", "/api/v1/users/104", false},
		{"GET", "/api/v1/transaksi-notaris/sync/pull", false}, {"POST", "/api/v1/transaksi-ppat/sync/create", false},
		{"GET", "/api/v1/users?override=1", false}, {"GET", "/api/v1/development/promotional", true}} {
		if promotionalAllowed(httptest.NewRequest(test.method, test.path, nil)) != test.allowed {
			t.Fatalf("invalid allowlist: %s %s", test.method, test.path)
		}
	}
	if _, _, e := promotionalRoot("../daily"); e == nil {
		t.Fatal("arbitrary profile")
	}
	if _, _, e := promotionalRoot(strings.Repeat("0", 32)); e == nil {
		t.Fatal("unknown profile")
	}
}

func TestPromotionalOwnedPostgres(t *testing.T) {
	id := os.Getenv("NOTARIS_PROMOTIONAL_TEST_PROFILE")
	if id == "" {
		t.Skip("new owned promotional profile opt-in required")
	}
	_, s, e := promotionalRoot(id)
	if e != nil {
		t.Fatal("profile binding failed")
	}
	db, e := promoOpen(id, true, false)
	if e != nil {
		t.Fatal("owned database required")
	}
	defer closePromo(db)
	if e = (services.Administration{DB: db, Enabled: true}).Ready(context.Background()); e != nil {
		t.Fatal("recovery/schema invalid")
	}
	app, e := promoOpen(id, false, false)
	if e != nil {
		t.Fatal("application role unavailable")
	}
	defer closePromo(app)
	var canUpdate bool
	app.Raw("SELECT has_table_privilege(current_user,'users','UPDATE')").Scan(&canUpdate)
	if canUpdate {
		t.Fatal("application DML unexpectedly available")
	}
	prior := database.DB
	defer func() { database.DB = prior }()
	server := httptest.NewServer(promotionalHandler(id, app, s))
	defer server.Close()
	info, e := promotionalContext(id, app, s, server.URL)
	if e != nil || info.GroupType != "superadmin" || len(info.Sidebars) != 21 {
		t.Fatal("normal HTTP bcrypt/JWT refresh failed")
	}
	// All fault injection is rolled back inside this dedicated test transaction.
	tx := db.Begin()
	defer tx.Rollback()
	handler := promotionalHandler(id, tx, s)
	sign := func(change func(jwt.MapClaims)) string {
		c := jwt.MapClaims{"uid": 104, "gid": 104, "sv": 1, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Minute).Unix()}
		if change != nil {
			change(c)
		}
		token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(s.JWTSecret))
		return token
	}
	invoke := func(method, path, token string) int {
		r := httptest.NewRequest(method, path, nil)
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w.Code
	}
	for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { delete(c, "exp") }, func(c jwt.MapClaims) { c["exp"] = 1 }, func(c jwt.MapClaims) { delete(c, "sv") }, func(c jwt.MapClaims) { c["sv"] = 2 }, func(c jwt.MapClaims) { c["iss"] = "invalid" }} {
		if invoke("GET", "/api/v1/auth/me", sign(change)) != 401 {
			t.Fatal("invalid JWT accepted")
		}
	}
	token := sign(nil)
	if invoke("GET", "/api/v1/users", token) != 200 {
		t.Fatal("authorized Users read failed")
	}
	for _, path := range []string{"/api/v1/users", "/api/v1/groups", "/api/v1/sidebars", "/api/v1/transaksi-notaris/sync/create"} {
		if invoke("POST", path, token) != 403 {
			t.Fatal("promotional mutation exposed")
		}
	}
	tx.Exec("UPDATE users SET security_version=2 WHERE id=104")
	if invoke("GET", "/api/v1/auth/me", token) != 401 {
		t.Fatal("revoked version accepted")
	}
	tx.Exec("UPDATE users SET security_version=1 WHERE id=104")
	if invoke("GET", "/api/v1/auth/me", sign(nil)) != 200 {
		t.Fatal("fresh login path unavailable")
	}
	tx.Exec("UPDATE groups SET group_jenis='user' WHERE id=104")
	if invoke("GET", "/api/v1/users", token) != 403 {
		t.Fatal("grant bypassed verified role")
	}
	tx.Exec("UPDATE groups SET group_jenis='superadmin' WHERE id=104")
	// A recovery-critical grant cannot disappear even inside a trusted admin writer.
	admin := services.Administration{DB: tx, Enabled: true}
	if e = admin.Grants(context.Background(), services.AdminActor{ID: 104, Version: 1, RequestID: services.AdminRequestID()}, 104, 1, nil); e == nil {
		t.Fatal("recovery grants lost")
	}
	// Audit table/trigger and uniqueness are the reviewed P0 schema, not AutoMigrate.
	tx.SavePoint("immutability")
	if e = tx.Exec("DELETE FROM administrative_audit").Error; e == nil {
		t.Fatal("audit not immutable")
	}
	tx.RollbackTo("immutability")
	tx.SavePoint("identity")
	if e = tx.Exec("INSERT INTO users(group_id,username,email,nama,status) VALUES(104,' SUPERADMIN.PROMO ','other@example.invalid','Other',1)").Error; e == nil {
		t.Fatal("duplicate identity")
	}
	tx.RollbackTo("identity")
	var count int64
	tx.Model(&struct{}{}).Table("users").Count(&count)
	if count != 1 {
		t.Fatal("unexpected account created")
	}
	raw, _ := json.Marshal(info)
	if strings.Contains(string(raw), s.LoginPassword) || strings.Contains(string(raw), s.JWTSecret) || strings.Contains(string(raw), "passwordHash") {
		t.Fatal("safe fixture context leaked secrets")
	}
	// Rollback occurs before owner/app pools close. Nothing in the prepared fixture
	// is edited or reseeded by these negative tests.
}
