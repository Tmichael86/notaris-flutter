package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func TestPpatCloudHTTPPostgres(t *testing.T) {
	dsn := os.Getenv("NOTARIS_SYNC_TEST_DSN")
	if dsn == "" {
		t.Skip("disposable NOTARIS_SYNC_TEST_DSN unset")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	admin := stdlib.OpenDB(*cfg)
	defer admin.Close()
	schema := fmt.Sprintf("ppat_cloud_http_%d", time.Now().UnixNano())
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
	prior := database.DB
	database.DB = db
	defer func() { database.DB = prior }()
	if err := db.AutoMigrate(&models.Group{}, &models.User{}, &models.Sidebar{}, &models.SidebarAccess{}); err != nil {
		t.Fatal(err)
	}
	ddl := `CREATE TABLE pekerjaan_kategori(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat_harga(id bigserial PRIMARY KEY,pekerjaan_ppat_id bigint NOT NULL REFERENCES pekerjaan_ppat(id),kategori_pekerjaan_id bigint NOT NULL REFERENCES pekerjaan_kategori(id),harga text NOT NULL CHECK(harga<>'fail'),estimasi_waktu text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat_proses(id bigserial PRIMARY KEY,pekerjaan_ppat_id bigint NOT NULL REFERENCES pekerjaan_ppat(id),nama text NOT NULL,detail text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris_harga(id bigserial PRIMARY KEY,pekerjaan_notaris_id bigint NOT NULL REFERENCES pekerjaan_notaris(id),kategori_pekerjaan_id bigint NOT NULL REFERENCES pekerjaan_kategori(id),harga text NOT NULL,estimasi_waktu text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris_proses(id bigserial PRIMARY KEY,pekerjaan_notaris_id bigint NOT NULL REFERENCES pekerjaan_notaris(id),nama text NOT NULL,detail text NOT NULL,status smallint NOT NULL);
INSERT INTO pekerjaan_kategori(uuid,nama,status) VALUES('00000000-0000-4000-8000-000000000011','Category',1);`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile(filepath.Join("..", "migration_proposals", "20261103_pekerjaan_ppat_aggregate_sync.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(migration)).Error; err != nil {
		t.Fatal(err)
	}
	notarisMigration, err := os.ReadFile(filepath.Join("..", "migration_proposals", "20261103_pekerjaan_notaris_create_sync.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(notarisMigration)).Error; err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{"INSERT INTO groups(id,status) VALUES(1,1),(2,1)", "INSERT INTO users(id,group_id,status) VALUES(1,1,1),(2,2,1)", "INSERT INTO sidebar(id,sidebar_kode,sidebar_route,status) VALUES(1,'pekerjaan_ppat','/pekerjaan_ppat',1),(2,'pekerjaan_notaris','/pekerjaan_notaris',1)", `INSERT INTO sidebar_akses(id,group_id,sidebar_id,"read","create","update","delete") VALUES(1,1,1,1,1,1,1),(2,2,2,1,1,1,1)`} {
		if err := db.Exec(statement).Error; err != nil {
			t.Fatal(err)
		}
	}
	secret := "ppat-cloud-test-secret"
	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"uid": 1, "gid": 1, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Hour).Unix()}).SignedString([]byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	notarisOnlyToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"uid": 2, "gid": 2, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Hour).Unix()}).SignedString([]byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	router := SetupRouter(config.Config{JWTSecret: secret}, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	if os.Getenv("NOTARIS_PPAT_E2E") == "1" {
		router.POST("/api/v1/pekerjaan-ppat/testing/publish", middleware.JWTAuth(config.Config{JWTSecret: secret}), func(c *gin.Context) {
			n, err := repositories.NewPpatCloudRepository(db).Publish(c.Request.Context(), 10)
			if err != nil {
				c.JSON(500, gin.H{"code": "publish_failed"})
				return
			}
			c.JSON(200, gin.H{"published": n})
		})
		server := httptest.NewServer(router)
		defer server.Close()
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		args := []string{"test", "test/e2e/pekerjaan_ppat_cloud_live_e2e_test.dart", "--reporter", "expanded"}
		var command *exec.Cmd
		if runtime.GOOS == "windows" {
			command = exec.CommandContext(ctx, "cmd", append([]string{"/c", "flutter"}, args...)...)
		} else {
			command = exec.CommandContext(ctx, "flutter", args...)
		}
		command.Dir = "../../frontend_notaris"
		command.Env = append(os.Environ(), "NOTARIS_PPAT_E2E_URL="+server.URL+"/api/v1", "NOTARIS_PPAT_E2E_TOKEN="+token)
		output, err := command.CombinedOutput()
		t.Log(strings.ReplaceAll(string(output), token, "[redacted]"))
		if err != nil {
			t.Fatalf("Device A/B Flutter HTTP E2E: %v", err)
		}
		var count int64
		if err := db.Table("pekerjaan_ppat").Count(&count).Error; err != nil || count != 1 {
			t.Fatalf("server aggregate count %d %v", count, err)
		}
		var revision, status, receipts, outbox, activeAttrs, removedAttrs int64
		if err := db.Raw("SELECT row_version,status FROM pekerjaan_ppat LIMIT 1").Row().Scan(&revision, &status); err != nil || revision != 3 || status != 0 {
			t.Fatalf("tombstone revision=%d status=%d err=%v", revision, status, err)
		}
		for _, check := range []struct {
			query string
			dest  *int64
			want  int64
		}{
			{"SELECT count(*) FROM pekerjaan_ppat_sync_mutation", &receipts, 3},
			{"SELECT count(*) FROM pekerjaan_ppat_sync_outbox WHERE publication_seq IS NOT NULL", &outbox, 3},
			{"SELECT count(*) FROM pekerjaan_ppat_sync_atribut WHERE status=1", &activeAttrs, 1},
			{"SELECT count(*) FROM pekerjaan_ppat_sync_atribut WHERE status=0", &removedAttrs, 1},
		} {
			if err := db.Raw(check.query).Row().Scan(check.dest); err != nil || *check.dest != check.want {
				t.Fatalf("%s count=%d err=%v", check.query, *check.dest, err)
			}
		}
		var same struct {
			UUID string
			Nama string
		}
		if err := db.Raw("SELECT uuid::text AS uuid,nama FROM pekerjaan_ppat LIMIT 1").Scan(&same).Error; err != nil {
			t.Fatal(err)
		}
		var priceUUID, processUUID, attrUUID string
		if err := db.Raw("SELECT uuid::text FROM pekerjaan_ppat_harga LIMIT 1").Row().Scan(&priceUUID); err != nil {
			t.Fatal(err)
		}
		if err := db.Raw("SELECT uuid::text FROM pekerjaan_ppat_proses LIMIT 1").Row().Scan(&processUUID); err != nil {
			t.Fatal(err)
		}
		if err := db.Raw("SELECT uuid::text FROM pekerjaan_ppat_sync_atribut LIMIT 1").Row().Scan(&attrUUID); err != nil {
			t.Fatal(err)
		}
		notaris := repositories.NotarisCloudCreate{MutationID: "00000000-0000-4000-8000-000000000991", UUID: same.UUID, Nama: same.Nama,
			Harga:  []repositories.NotarisCloudHarga{{UUID: priceUUID, CategoryUUID: "00000000-0000-4000-8000-000000000011", Harga: "150000", EstimasiWaktu: "3 hari"}},
			Proses: []repositories.NotarisCloudProses{{UUID: processUUID, Nama: "Periksa", Detail: "Same domain-independent name", Atribut: []repositories.NotarisCloudAtribut{{UUID: attrUUID, Value: "Akta"}}}}}
		if _, err := repositories.NewNotarisCloudRepository(db).Create(ctx, notaris, 2); err != nil {
			t.Fatal(err)
		}
		if n, err := repositories.NewNotarisCloudRepository(db).Publish(ctx, 10); err != nil || n != 1 {
			t.Fatalf("Notaris publish %d %v", n, err)
		}
		ppatPage, err := repositories.NewPpatCloudRepository(db).Pull(ctx, 0, 10)
		if err != nil || len(ppatPage.Changes) != 3 || ppatPage.NextCursor != 3 {
			t.Fatalf("PPAT feed crossed domains: %+v %v", ppatPage, err)
		}
		notarisPage, err := repositories.NewNotarisCloudRepository(db).Pull(ctx, 0, 10)
		if err != nil || len(notarisPage.Changes) != 1 || notarisPage.Changes[0].Aggregate.UUID != same.UUID {
			t.Fatalf("Notaris feed crossed domains: %+v %v", notarisPage, err)
		}
		return
	}
	request := func(method, path, body, auth string, want int) string {
		t.Helper()
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if auth != "" {
			req.Header.Set("Authorization", "Bearer "+auth)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != want {
			t.Fatalf("%s %s: %d want %d: %s", method, path, w.Code, want, w.Body.String())
		}
		return w.Body.String()
	}
	path := "/api/v1/pekerjaan-ppat/sync/create"
	body := `{"mutation_id":"00000000-0000-4000-8000-000000000101","uuid":"00000000-0000-4000-8000-000000000201","nama":"Synthetic","harga":[{"uuid":"00000000-0000-4000-8000-000000000301","category_uuid":"00000000-0000-4000-8000-000000000011","harga":"100000","estimasi_waktu":"2 hari"}],"proses":[{"uuid":"00000000-0000-4000-8000-000000000401","nama":"Periksa","detail":"Fixture","atribut":[{"uuid":"00000000-0000-4000-8000-000000000501","atribut":"KTP"}]}]}`
	request("POST", path, body, "", 401)
	request("POST", "/api/v1/pekerjaan-ppat/sync/update", body, "", 401)
	request("POST", "/api/v1/pekerjaan-ppat/sync/delete", body, "", 401)
	request("POST", path, body, notarisOnlyToken, 403)
	request("GET", "/api/v1/pekerjaan-ppat/sync/pull", "", notarisOnlyToken, 403)
	request("GET", "/api/v1/pekerjaan-notaris/sync/pull", "", notarisOnlyToken, 200)
	request("POST", "/api/v1/pekerjaan-notaris/sync/create", body, token, 403)
	first := request("POST", path, body, token, 200)
	if replay := request("POST", path, body, token, 200); replay != first {
		t.Fatal("receipt replay differs")
	}
	request("POST", path, strings.Replace(body, "Synthetic", "Changed", 1), token, 409)
	if n, err := repositories.NewPpatCloudRepository(db).Publish(context.Background(), 2); err != nil || n != 1 {
		t.Fatalf("publish %d %v", n, err)
	}
	pull := request("GET", "/api/v1/pekerjaan-ppat/sync/pull?cursor=0&limit=2", "", token, 200)
	if !strings.Contains(pull, `"atribut":"KTP"`) || !strings.Contains(pull, `"next_cursor":1`) {
		t.Fatal("complete aggregate missing")
	}
	request("GET", "/api/v1/pekerjaan-ppat/sync/pull?cursor=1", "", token, 200)
	if err := db.Exec(`UPDATE sidebar_akses SET "read"=0 WHERE id=1`).Error; err != nil {
		t.Fatal(err)
	}
	request("GET", "/api/v1/pekerjaan-ppat/sync/pull", "", token, http.StatusForbidden)
	if err := db.Exec(`UPDATE sidebar_akses SET "update"=0,"delete"=0 WHERE id=1`).Error; err != nil {
		t.Fatal(err)
	}
	request("POST", "/api/v1/pekerjaan-ppat/sync/update", body, token, http.StatusForbidden)
	request("POST", "/api/v1/pekerjaan-ppat/sync/delete", body, token, http.StatusForbidden)
}
