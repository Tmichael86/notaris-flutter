package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestTransactionCloudHTTPPostgres(t *testing.T) {
	dsn := os.Getenv("NOTARIS_SYNC_TEST_DSN")
	if dsn == "" {
		t.Skip("disposable DSN unset")
	}
	cfg, e := pgx.ParseConfig(dsn)
	if e != nil {
		t.Fatal(e)
	}
	// Refuse any permanent service target even if its DSN is accidentally supplied.
	if cfg.Host != "127.0.0.1" || cfg.Port < 55400 || cfg.Port > 55999 {
		t.Fatal("owned disposable port required")
	}
	admin := stdlib.OpenDB(*cfg)
	defer admin.Close()
	schema := fmt.Sprintf("transaction_http_%d", time.Now().UnixNano())
	if _, e = admin.Exec("CREATE SCHEMA " + schema); e != nil {
		t.Fatal(e)
	}
	defer admin.Exec("DROP SCHEMA " + schema + " CASCADE")
	cfg.RuntimeParams["search_path"] = schema
	pool := stdlib.OpenDB(*cfg)
	defer pool.Close()
	db, e := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{})
	if e != nil {
		t.Fatal(e)
	}
	prior := database.DB
	database.DB = db
	defer func() { database.DB = prior }()
	if e = db.AutoMigrate(&models.Group{}, &models.User{}, &models.Sidebar{}, &models.SidebarAccess{}); e != nil {
		t.Fatal(e)
	}
	ddl := `CREATE TABLE pemohon(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,status smallint,deleted_at timestamptz);
 CREATE TABLE petugas(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_kategori(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_notaris(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_notaris_harga(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,pekerjaan_notaris_id bigint REFERENCES pekerjaan_notaris(id),kategori_pekerjaan_id bigint REFERENCES pekerjaan_kategori(id),status smallint,deleted_at timestamptz);
 INSERT INTO pemohon VALUES(301,'00000000-0000-4000-8000-000000000001',1,NULL);
 INSERT INTO petugas VALUES(104,'00000000-0000-4000-8000-000000000003',1,NULL);
 INSERT INTO pekerjaan_notaris VALUES(901,'00000000-0000-4000-8000-000000000004',1,NULL);
 INSERT INTO pekerjaan_kategori VALUES(801,'00000000-0000-4000-8000-000000000006',1,NULL);
 INSERT INTO pekerjaan_notaris_harga VALUES(701,'00000000-0000-4000-8000-000000000005',901,801,1,NULL);
 INSERT INTO groups(id,status) VALUES(1,1); INSERT INTO users(id,group_id,status) VALUES(1,1,1);
 INSERT INTO sidebar(id,sidebar_kode,sidebar_route,status) VALUES(1,'transaksi','/transaksi',1);
 INSERT INTO sidebar_akses(id,group_id,sidebar_id,"read","create","update","delete") VALUES(1,1,1,1,1,0,0);`
	if e = db.Exec(ddl).Error; e != nil {
		t.Fatal(e)
	}
	for _, name := range []string{"20261105_transaction_cloud_numbering.sql", "20261105_transaction_notaris_create.sql"} {
		sql, e := os.ReadFile("../migration_proposals/" + name)
		if e != nil {
			t.Fatal(e)
		}
		if e = db.Exec(string(sql)).Error; e != nil {
			t.Fatal(e)
		}
	}
	secret := "transaction-disposable-secret"
	token, e := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"uid": 1, "gid": 1, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Hour).Unix()}).SignedString([]byte(secret))
	if e != nil {
		t.Fatal(e)
	}
	router := SetupRouter(config.Config{JWTSecret: secret}, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	router.POST("/api/v1/transaksi-notaris/testing/publish", middleware.JWTAuth(config.Config{JWTSecret: secret}), func(c *gin.Context) {
		n, e := repositories.NewTransactionCloudRepository(db).Publish(c.Request.Context(), 2)
		if e != nil {
			c.JSON(500, gin.H{"code": "failed"})
			return
		}
		c.JSON(200, gin.H{"published": n})
	})
	server := httptest.NewServer(router)
	defer server.Close()
	if os.Getenv("NOTARIS_TRANSACTION_E2E") == "1" {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
		defer cancel()
		args := []string{"test", "--no-pub", "test/e2e/transaction_cloud_live_e2e_test.dart", "--reporter", "expanded"}
		var cmd *exec.Cmd
		if runtime.GOOS == "windows" {
			cmd = exec.CommandContext(ctx, "cmd", append([]string{"/c", "flutter"}, args...)...)
		} else {
			cmd = exec.CommandContext(ctx, "flutter", args...)
		}
		cmd.Dir = "../../frontend_notaris"
		cmd.Env = append(os.Environ(), "TRANSACTION_E2E_URL="+server.URL+"/api/v1", "TRANSACTION_E2E_TOKEN="+token)
		out, e := cmd.CombinedOutput()
		t.Log(strings.ReplaceAll(string(out), token, "[redacted]"))
		if e != nil {
			t.Fatalf("Flutter Device A/B: %v", e)
		}
		for _, q := range []string{"SELECT count(*) FROM transaction_cloud", "SELECT count(*) FROM transaction_cloud_payment", "SELECT count(*) FROM transaction_cloud_mutation", "SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq=1", "SELECT last_number FROM transaction_cloud_number_counter"} {
			var n int64
			if e = db.Raw(q).Row().Scan(&n); e != nil || n != 1 {
				t.Fatalf("%s=%d err=%v", q, n, e)
			}
		}
		return
	}
	request := func(m repositories.TransactionCloudCreate, auth string) (int, []byte) {
		body, _ := json.Marshal(m)
		req, _ := http.NewRequest("POST", server.URL+"/api/v1/transaksi-notaris/sync/create", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if auth != "" {
			req.Header.Set("Authorization", "Bearer "+auth)
		}
		resp, e := server.Client().Do(req)
		if e != nil {
			t.Fatal(e)
		}
		defer resp.Body.Close()
		out, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, out
	}
	sample := func(i int) repositories.TransactionCloudCreate {
		uuid := func(offset int) string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", i*10+offset) }
		return repositories.TransactionCloudCreate{MutationID: uuid(0), UUID: uuid(1), PemohonUUID: "00000000-0000-4000-8000-000000000001", PetugasUUID: "00000000-0000-4000-8000-000000000003", Header: repositories.TransactionCloudHeader{Date: time.Now().UTC(), Status: "Baru", Total: 100, InitialPayment: 25, Method: "Cash"}, Details: []repositories.TransactionCloudDetail{{UUID: uuid(2), JobUUID: "00000000-0000-4000-8000-000000000004", PriceUUID: "00000000-0000-4000-8000-000000000005", CategoryUUID: "00000000-0000-4000-8000-000000000006", Name: "Snapshot", Category: "Historical", ServiceCost: 100, Total: 100, ProcessSnapshot: json.RawMessage(`[{"id":"old-local-id","name":"Periksa","attributes":["KTP"]}]`), Processes: []repositories.TransactionCloudProcess{{UUID: uuid(3), Name: "Periksa"}}}}, Payments: []repositories.TransactionCloudPayment{{UUID: uuid(4), Date: time.Now().UTC(), Amount: 25, Method: "Cash", Order: 1}}}
	}
	m := sample(100)
	if code, _ := request(m, ""); code != 401 {
		t.Fatal(code)
	}
	code, out := request(m, token)
	if code != 200 {
		t.Fatalf("create %d %s", code, out)
	}
	var first struct {
		Ack repositories.TransactionCloudAck `json:"acknowledgement"`
	}
	json.Unmarshal(out, &first)
	if first.Ack.FinalNumber != "100"+time.Now().In(mustJakarta(t)).Format("020106")+"0001" {
		t.Fatal(first)
	}
	code, replay := request(m, token)
	if code != 200 || !bytes.Equal(out, replay) {
		t.Fatalf("replay=%d %s", code, replay)
	}
	changed := m
	changed.Header.Status = "Changed"
	if code, _ := request(changed, token); code != 409 {
		t.Fatal("reuse", code)
	}
	invalid := sample(101)
	invalid.Details[0].CategoryUUID = invalid.PemohonUUID
	if code, _ := request(invalid, token); code != 422 {
		t.Fatal("reference", code)
	}
	// Duplicate child causes a real DB constraint failure AFTER number allocation.
	failed := sample(102)
	failed.Details[0].UUID = m.Details[0].UUID
	if code, _ := request(failed, token); code != 500 {
		t.Fatal("child constraint", code)
	}
	var n int
	if e = db.Raw("SELECT last_number FROM transaction_cloud_number_counter").Row().Scan(&n); e != nil || n != 1 {
		t.Fatal("failed CREATE consumed number", n, e)
	}
	var wg sync.WaitGroup
	results := make(chan string, 2)
	errs := make(chan string, 2)
	for i := 103; i <= 104; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			code, out := request(sample(i), token)
			if code != 200 {
				errs <- fmt.Sprintf("%d %s", code, out)
				return
			}
			var result struct {
				Ack repositories.TransactionCloudAck `json:"acknowledgement"`
			}
			json.Unmarshal(out, &result)
			results <- result.Ack.FinalNumber
		}(i)
	}
	wg.Wait()
	close(results)
	close(errs)
	for e := range errs {
		t.Error(e)
	}
	seen := map[string]bool{}
	for s := range results {
		if seen[s] {
			t.Fatal("duplicate final number")
		}
		seen[s] = true
	}
	if len(seen) != 2 {
		t.Fatal("concurrent create incomplete")
	}
	for _, table := range []string{"transaction_cloud", "transaction_cloud_detail", "transaction_cloud_process", "transaction_cloud_payment", "transaction_cloud_mutation", "transaction_cloud_outbox"} {
		if e = db.Table(table).Count(new(int64)).Error; e != nil {
			t.Fatal(e)
		}
		var n int64
		db.Table(table).Count(&n)
		if n != 3 {
			t.Fatal(table, n)
		}
	}
	for i, want := range []int{2, 1, 0} {
		n, e := repositories.NewTransactionCloudRepository(db).Publish(context.Background(), 2)
		if e != nil || n != want {
			t.Fatal("publish", i, n, e)
		}
	}
	page, e := repositories.NewTransactionCloudRepository(db).Pull(context.Background(), 0, 2)
	if e != nil || len(page.Changes) != 2 || !page.HasMore || page.NextCursor != 2 || len(page.Changes[0].Aggregate.Payments) != 1 || len(page.Changes[0].Aggregate.Details[0].Processes) != 1 {
		t.Fatal("aggregate page", page, e)
	}
	if e = db.Exec(`UPDATE sidebar_akses SET "create"=0,"read"=0`).Error; e != nil {
		t.Fatal(e)
	}
	if code, _ := request(sample(105), token); code != 403 {
		t.Fatal("permission", code)
	}
}
func mustJakarta(t *testing.T) *time.Location {
	t.Helper()
	tz, e := time.LoadLocation("Asia/Jakarta")
	if e != nil {
		t.Fatal(e)
	}
	return tz
}
