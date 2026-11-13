package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"context"
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

// Existing test fixtures use minimal schema/AutoMigrate. This one uses a restored
// full development backup, with the actual application grants and NO AutoMigrate.
func TestPetugasRestoredDevelopmentReadiness(t *testing.T) {
	dsn := os.Getenv("NOTARIS_READINESS_TEST_DSN")
	if dsn == "" {
		t.Skip("restored disposable readiness DSN unset")
	}
	c, err := pgx.ParseConfig(dsn)
	if err != nil || c.Port != 55442 || c.Host != "127.0.0.1" || c.Database != "notarisdev" || c.User != "readiness_app" {
		t.Fatal("unsafe readiness target")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal("readiness connection failed")
	}
	pool, _ := db.DB()
	defer pool.Close()
	old := database.DB
	database.DB = db
	defer func() { database.DB = old }()
	var n int64
	db.Raw("SELECT count(*) FROM petugas WHERE id BETWEEN 101 AND 104 AND uuid IS NOT NULL AND row_version=1").Scan(&n)
	if n != 4 {
		t.Fatal("legacy identity/backfill invalid")
	}
	ctx := context.Background()
	pub := repositories.NewPetugasPublicationRepository(db)
	if n, err := pub.Bootstrap(ctx); err != nil || n != 4 {
		t.Fatalf("bootstrap %d %v", n, err)
	}
	if n, err := pub.Bootstrap(ctx); err != nil || n != 0 {
		t.Fatalf("repeat bootstrap %d %v", n, err)
	}
	if n, err := pub.Publish(ctx, 100); err != nil || n != 4 {
		t.Fatalf("publish baseline %d %v", n, err)
	}
	if n, err := pub.Publish(ctx, 100); err != nil || n != 0 {
		t.Fatalf("repeat publish %d %v", n, err)
	}
	cfg := config.Config{JWTSecret: "disposable-readiness-only-secret", JWTExpireMinutes: 30}
	r := gin.New()
	r.POST("/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	auth := middleware.JWTAuth(cfg)
	access := repositories.NewSidebarAccessRepository()
	legacy := controllers.NewPetugasController()
	read := middleware.RequirePermission(access, "petugas", middleware.PermissionRead)
	r.GET("/pull", auth, read, controllers.PetugasSyncPull)
	r.PUT("/sync/:uuid", auth, read, controllers.PetugasSyncPush)
	r.GET("/legacy", auth, read, legacy.GetAll)
	r.POST("/legacy", auth, middleware.RequirePermission(access, "petugas", middleware.PermissionCreate), legacy.Create)
	r.PUT("/legacy/:id", auth, middleware.RequirePermission(access, "petugas", middleware.PermissionUpdate), legacy.Update)
	r.DELETE("/legacy/:id", auth, middleware.RequirePermission(access, "petugas", middleware.PermissionDelete), legacy.Delete)
	call := func(method, path, body, token string, status int) string {
		q := httptest.NewRequest(method, path, strings.NewReader(body))
		q.Header.Set("Content-Type", "application/json")
		if token != "" {
			q.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, q)
		if w.Code != status {
			t.Fatalf("%s %s status=%d expected=%d", method, path, w.Code, status)
		}
		return w.Body.String()
	}
	loginBody, _ := json.Marshal(map[string]string{"username": "fixture.operator", "password": os.Getenv("NOTARIS_READINESS_FIXTURE_PASSWORD")})
	var login struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	json.Unmarshal([]byte(call("POST", "/login", string(loginBody), "", 200)), &login)
	token := login.Data.Token
	if token == "" {
		t.Fatal("missing actual fixture login JWT")
	}
	call("GET", "/pull", "", "", 401)
	call("GET", "/legacy", "", token, 200)
	call("POST", "/legacy", `{"nama":"Readiness legacy","email":"legacy@readiness.invalid","jenis_kelamin":11}`, token, 201)
	call("PUT", "/legacy/105", `{"nama":"Readiness edited","email":"legacy@readiness.invalid","jenis_kelamin":11}`, token, 200)
	call("DELETE", "/legacy/105", "", token, 200)
	uuid := "df000000-0000-4000-8000-000000000001"
	create := `{"mutation_id":"df000000-0000-4000-8000-000000000002","petugas_uuid":"` + uuid + `","operation":"upsert","expected_row_version":null,"payload":{"nama":"Readiness Sync","email":"sync@readiness.invalid","jenis_kelamin_id":29,"user_id":2001}}`
	first := call("PUT", "/sync/"+uuid, create, token, 200)
	if call("PUT", "/sync/"+uuid, create, token, 200) != first {
		t.Fatal("idempotent replay mismatch")
	}
	update := strings.ReplaceAll(strings.ReplaceAll(create, "000000000002", "000000000003"), `"expected_row_version":null`, `"expected_row_version":1`)
	call("PUT", "/sync/"+uuid, update, token, 200)
	stale := strings.ReplaceAll(update, "000000000003", "000000000004")
	if !strings.Contains(call("PUT", "/sync/"+uuid, stale, token, 409), "version_conflict") {
		t.Fatal("missing version conflict")
	}
	deletion := `{"mutation_id":"df000000-0000-4000-8000-000000000005","petugas_uuid":"` + uuid + `","operation":"delete","expected_row_version":2}`
	call("PUT", "/sync/"+uuid, deletion, token, 200)
	call("PUT", "/sync/"+uuid, deletion, token, 200)
	if _, err := pub.Publish(ctx, 100); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(call("GET", "/pull?cursor=4&limit=100", "", token, 200), `"tombstone":true`) {
		t.Fatal("missing tombstone")
	}
	db.Raw("SELECT count(*) FROM petugas_sync_mutations WHERE petugas_uuid=?::uuid", uuid).Scan(&n)
	if n != 3 {
		t.Fatal("mutation receipts duplicated")
	}
	db.Raw("SELECT count(*) FROM petugas_sync_outbox WHERE petugas_uuid=?::uuid", uuid).Scan(&n)
	if n != 3 {
		t.Fatal("outbox duplicated")
	}
	if err := db.Exec("UPDATE petugas_sync_publication SET min_cursor=1 WHERE id=1").Error; err != nil {
		t.Fatal(err)
	}
	call("GET", "/pull?cursor=0", "", token, 410)
	db.Raw("SELECT count(*) FROM petugas WHERE id BETWEEN 101 AND 104 AND row_version=1").Scan(&n)
	if n != 4 {
		t.Fatal("legacy identity rows changed")
	}
}
