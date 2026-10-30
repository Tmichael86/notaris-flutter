package routes

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"context"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func TestPetugasSyncHTTPPostgres(t *testing.T) {
	dsn := os.Getenv("NOTARIS_SYNC_TEST_DSN")
	if dsn == "" {
		t.Skip("NOTARIS_SYNC_TEST_DSN unset")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnectTimeout = 5 * time.Second
	admin := stdlib.OpenDB(*cfg)
	defer admin.Close()
	schema := fmt.Sprintf("petugas_http_test_%d", time.Now().UnixNano())
	if _, err := admin.Exec("CREATE SCHEMA " + schema); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec("DROP SCHEMA " + schema + " CASCADE")
	cfg.RuntimeParams["search_path"] = schema
	pool := stdlib.OpenDB(*cfg)
	defer pool.Close()
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	old := database.DB
	database.DB = db
	defer func() { database.DB = old }()
	if err := db.AutoMigrate(&models.Group{}, &models.User{}, &models.Sidebar{}, &models.SidebarAccess{}, &models.Petugas{}); err != nil {
		t.Fatal(err)
	}
	// GORM maps *string to text by default. The real identity migration declares
	// UUID natively; make this isolated HTTP fixture use that same SQL type.
	if err := db.Exec("ALTER TABLE petugas ALTER COLUMN uuid TYPE uuid USING uuid::uuid").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("CREATE TABLE jenis_kelamin (id bigint PRIMARY KEY, nama text); INSERT INTO jenis_kelamin VALUES (2,'Test')").Error; err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"20261029_01_petugas_cloud_sync.sql", "20261030_01_petugas_publication.sql", "20261030_02_petugas_uuid_hardening.sql"} {
		b, err := os.ReadFile(filepath.Join("..", "migrations", name))
		if err != nil {
			t.Fatal(err)
		}
		if err := db.Exec(string(b)).Error; err != nil {
			t.Fatal(err)
		}
	}
	for _, sql := range []string{"INSERT INTO groups (id,status) VALUES (1,1)", "INSERT INTO users (id,group_id,status) VALUES (1,1,1)", "INSERT INTO sidebar (id,sidebar_kode,sidebar_route,status) VALUES (1,'petugas','/petugas',1)", `INSERT INTO sidebar_akses (id,group_id,sidebar_id,"read","create","update","delete") VALUES (1,1,1,1,1,1,1)`} {
		if err := db.Exec(sql).Error; err != nil {
			t.Fatal(err)
		}
	}
	secret := "local-test-signing-key"
	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"uid": 1, "gid": 1, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Hour).Unix()}).SignedString([]byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	router := SetupRouter(config.Config{JWTSecret: secret}, nil, nil, controllers.NewPetugasController(), nil, nil, nil, nil, nil, nil, nil, nil)
	uuid := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	path := "/api/v1/petugas/sync/" + uuid
	body := `{"mutation_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","petugas_uuid":"` + uuid + `","operation":"upsert","expected_row_version":null,"payload":{"nama":"Sari","email":"sari@example.com","jenis_kelamin_id":2,"user_id":1}}`
	request := func(method, path, body, auth string, status int) string {
		t.Helper()
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if auth != "" {
			req.Header.Set("Authorization", "Bearer "+auth)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != status {
			t.Fatalf("%s %s: %d want %d: %s", method, path, w.Code, status, w.Body.String())
		}
		return w.Body.String()
	}
	request("PUT", path, body, "", 401)
	if err := db.Exec(`UPDATE sidebar_akses SET "create"=0`).Error; err != nil {
		t.Fatal(err)
	}
	request("PUT", path, body, token, 403)
	db.Exec(`UPDATE sidebar_akses SET "create"=1`)
	request("PUT", path, "{}", token, 400)
	request("PUT", path, strings.ReplaceAll(body, "sari@example.com", "invalid-email"), token, 422)
	first := request("PUT", path, body, token, 200)
	replay := request("PUT", path, body, token, 200)
	if first != replay {
		t.Fatal("receipt replay changed")
	}
	update := strings.ReplaceAll(body, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
	update = strings.ReplaceAll(update, `"expected_row_version":null`, `"expected_row_version":1`)
	update = strings.ReplaceAll(update, "Sari", "Updated")
	db.Exec(`UPDATE sidebar_akses SET "update"=0`)
	request("PUT", path, update, token, 403)
	db.Exec(`UPDATE sidebar_akses SET "update"=1`)
	request("PUT", path, update, token, 200)
	if request("PUT", path, body, token, 200) != first {
		t.Fatal("replay returned latest row instead of acknowledged snapshot")
	}
	stale := strings.ReplaceAll(update, "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
	conflict := request("PUT", path, stale, token, 409)
	if !strings.Contains(conflict, "version_conflict") || strings.Contains(conflict, "created_by") {
		t.Fatal("unsafe/missing conflict")
	}
	invalid := strings.ReplaceAll(stale, `"expected_row_version":1`, `"expected_row_version":2`)
	invalid = strings.ReplaceAll(invalid, `"user_id":1`, `"user_id":999`)
	request("PUT", path, invalid, token, 422)
	deletion := `{"mutation_id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","petugas_uuid":"` + uuid + `","operation":"delete","expected_row_version":2}`
	db.Exec(`UPDATE sidebar_akses SET "delete"=0`)
	request("PUT", path, deletion, token, 403)
	db.Exec(`UPDATE sidebar_akses SET "delete"=1`)
	request("PUT", path, deletion, token, 200)
	if _, err := repositories.NewPetugasPublicationRepository(db).Publish(context.Background(), 50); err != nil {
		t.Fatal(err)
	}
	page := request("GET", "/api/v1/petugas/sync/pull?limit=1", "", token, 200)
	if !strings.Contains(page, "Sari") || !strings.Contains(page, `"has_more":true`) {
		t.Fatal("historical page incorrect")
	}
	request("GET", "/api/v1/petugas/sync/pull?cursor=-1", "", token, 400)
	page = request("GET", "/api/v1/petugas/sync/pull?cursor=2", "", token, 200)
	if !strings.Contains(page, `"tombstone":true`) {
		t.Fatal("tombstone missing")
	}
	if err := db.Exec("INSERT INTO petugas (uuid,row_version,nama,email,status) VALUES (gen_random_uuid(),1,'Legacy baseline','baseline@example.com',1)").Error; err != nil {
		t.Fatal(err)
	}
	pub := repositories.NewPetugasPublicationRepository(db)
	if n, err := pub.Bootstrap(context.Background()); err != nil || n != 1 {
		t.Fatalf("HTTP baseline seed: %d %v", n, err)
	}
	if _, err := pub.Publish(context.Background(), 50); err != nil {
		t.Fatal(err)
	}
	page = request("GET", "/api/v1/petugas/sync/pull?cursor=3", "", token, 200)
	if !strings.Contains(page, "Legacy baseline") {
		t.Fatal("baseline missing from HTTP feed")
	}
	db.Exec("UPDATE petugas_sync_publication SET min_cursor=1")
	request("GET", "/api/v1/petugas/sync/pull", "", token, 410)
	db.Exec(`UPDATE sidebar_akses SET "read"=0`)
	request("GET", "/api/v1/petugas/sync/pull", "", token, 403)
	db.Exec(`UPDATE sidebar_akses SET "read"=1`)
	db.Exec("DROP TABLE petugas_sync_publication")
	failure := request("GET", "/api/v1/petugas/sync/pull", "", token, 500)
	var envelope map[string]any
	if json.Unmarshal([]byte(failure), &envelope) != nil || strings.Contains(failure, "SQLSTATE") || strings.Contains(failure, "password") {
		t.Fatal("database error leaked")
	}
}
