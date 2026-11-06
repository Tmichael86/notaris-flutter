package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
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

func TestTransactionCloudHTTPPostgres(t *testing.T)     { runTransactionCloudHTTP(t, "notaris") }
func TestTransactionPpatCloudHTTPPostgres(t *testing.T) { runTransactionCloudHTTP(t, "ppat") }
func TestTransactionMixedManualHTTPPostgres(t *testing.T) {
	if os.Getenv("NOTARIS_TRANSACTION_E2E") != "1" {
		t.Skip("disposable mixed A/B HTTP opt-in unset")
	}
	t.Setenv("NOTARIS_TRANSACTION_MANUAL_BRIDGE", "1")
	t.Setenv("NOTARIS_TRANSACTION_MIXED_E2E", "1")
	runTransactionCloudHTTP(t, "notaris")
}
func runTransactionCloudHTTP(t *testing.T, domain string) {
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
 CREATE TABLE pekerjaan_ppat(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_ppat_harga(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,pekerjaan_ppat_id bigint REFERENCES pekerjaan_ppat(id),kategori_pekerjaan_id bigint REFERENCES pekerjaan_kategori(id),status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_notaris_harga(id bigint PRIMARY KEY,uuid uuid NOT NULL UNIQUE,pekerjaan_notaris_id bigint REFERENCES pekerjaan_notaris(id),kategori_pekerjaan_id bigint REFERENCES pekerjaan_kategori(id),status smallint,deleted_at timestamptz);
 INSERT INTO pemohon VALUES(301,'00000000-0000-4000-8000-000000000001',1,NULL);
 INSERT INTO petugas VALUES(104,'00000000-0000-4000-8000-000000000003',1,NULL);
 INSERT INTO pekerjaan_notaris VALUES(901,'00000000-0000-4000-8000-000000000004',1,NULL);
 INSERT INTO pekerjaan_kategori VALUES(801,'00000000-0000-4000-8000-000000000006',1,NULL);
 INSERT INTO pekerjaan_notaris_harga VALUES(701,'00000000-0000-4000-8000-000000000005',901,801,1,NULL);
 INSERT INTO pekerjaan_ppat VALUES(1901,'00000000-0000-4000-8000-000000000004',1,NULL);
 INSERT INTO pekerjaan_ppat_harga VALUES(1701,'00000000-0000-4000-8000-000000000005',1901,801,1,NULL);
 INSERT INTO pekerjaan_notaris VALUES(902,'00000000-0000-4000-8000-000000000044',1,NULL);
 INSERT INTO pekerjaan_notaris_harga VALUES(702,'00000000-0000-4000-8000-000000000045',902,801,1,NULL);
 INSERT INTO groups(id,status) VALUES(1,1); INSERT INTO users(id,group_id,status) VALUES(1,1,1);
 INSERT INTO sidebar(id,sidebar_kode,sidebar_route,status) VALUES(1,'transaksi','/transaksi',1);
 INSERT INTO sidebar_akses(id,group_id,sidebar_id,"read","create","update","delete") VALUES(1,1,1,1,1,1,1);`
	if e = db.Exec(ddl).Error; e != nil {
		t.Fatal(e)
	}
	for _, name := range []string{"20261105_transaction_cloud_numbering.sql", "20261105_transaction_notaris_create.sql", "20261105_transaction_notaris_mutations.sql", "20261105_transaction_ppat_domain.sql"} {
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
	router := SetupRouter(config.Config{JWTSecret: secret}, nil, nil, nil, nil, nil, nil, nil, nil, controllers.NewMeController(), nil, nil)
	router.POST("/api/v1/transaksi-"+domain+"/testing/publish", middleware.JWTAuth(config.Config{JWTSecret: secret}), func(c *gin.Context) {
		var expected repositories.TransactionPublicationExpectation
		if c.ShouldBindJSON(&expected) != nil {
			c.JSON(400, gin.H{"code": "expected_event_required"})
			return
		}
		result, e := repositories.NewTransactionCloudRepository(db).PublishExpected(c.Request.Context(), expected)
		if e != nil {
			c.JSON(500, gin.H{"code": "failed"})
			return
		}
		c.JSON(200, result)
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
		cmd.Env = append(os.Environ(), "TRANSACTION_DOMAIN="+domain, "TRANSACTION_E2E_URL="+server.URL+"/api/v1", "TRANSACTION_E2E_TOKEN="+token, "TRANSACTION_MUTATIONS="+os.Getenv("NOTARIS_TRANSACTION_MUTATIONS_E2E"), "TRANSACTION_MANUAL_BRIDGE="+os.Getenv("NOTARIS_TRANSACTION_MANUAL_BRIDGE"), "TRANSACTION_MIXED_FEED="+os.Getenv("NOTARIS_TRANSACTION_MIXED_E2E"), "TRANSACTION_DISPOSABLE_TARGET="+fmt.Sprintf("%s:%d/%s", cfg.Host, cfg.Port, cfg.Database), "TRANSACTION_DISPOSABLE_DEPLOYMENT="+schema)
		out, e := cmd.CombinedOutput()
		t.Log(strings.ReplaceAll(string(out), token, "[redacted]"))
		if e != nil {
			t.Fatalf("Flutter Device A/B: %v", e)
		}
		if os.Getenv("NOTARIS_TRANSACTION_MIXED_E2E") == "1" {
			for q, want := range map[string]int64{"SELECT count(*) FROM transaction_cloud": 2, "SELECT count(*) FROM transaction_cloud_payment": 2, "SELECT count(*) FROM transaction_cloud_mutation": 6, "SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq BETWEEN 1 AND 6": 6, "SELECT last_seq FROM transaction_cloud_publication": 6, "SELECT count(*) FROM transaction_cloud_number_counter WHERE last_number=1": 2} {
				var got int64
				if err := db.Raw(q).Row().Scan(&got); err != nil || got != want {
					t.Fatalf("mixed %s=%d want=%d err=%v", q, got, want, err)
				}
			}
			var domains []string
			if err := db.Raw("SELECT payload->>'domain' FROM transaction_cloud_outbox ORDER BY publication_seq LIMIT 4").Scan(&domains).Error; err != nil || strings.Join(domains, ",") != "ppat,notaris,ppat,notaris" {
				t.Fatal("mixed ordering", domains, err)
			}
			return
		}
		for _, q := range []string{"SELECT count(*) FROM transaction_cloud", "SELECT count(*) FROM transaction_cloud_payment", "SELECT count(*) FROM transaction_cloud_mutation", "SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq=1", "SELECT last_number FROM transaction_cloud_number_counter"} {
			var n int64
			want := int64(1)
			if os.Getenv("NOTARIS_TRANSACTION_MUTATIONS_E2E") == "1" && q == "SELECT count(*) FROM transaction_cloud_mutation" {
				want = 3
			}
			if domain == "ppat" && os.Getenv("NOTARIS_TRANSACTION_MUTATIONS_E2E") == "1" {
				if q == "SELECT count(*) FROM transaction_cloud" || q == "SELECT count(*) FROM transaction_cloud_payment" {
					want = 2
				}
				if q == "SELECT count(*) FROM transaction_cloud_mutation" {
					want = 4
				}
			}
			if e = db.Raw(q).Row().Scan(&n); e != nil || n != want {
				t.Fatalf("%s=%d err=%v", q, n, e)
			}
		}
		if domain == "ppat" && os.Getenv("NOTARIS_TRANSACTION_MUTATIONS_E2E") == "1" {
			for _, q := range []string{"SELECT count(*) FROM transaction_cloud_number_counter WHERE last_number=1", "SELECT count(DISTINCT domain) FROM transaction_cloud"} {
				var n int64
				if e = db.Raw(q).Row().Scan(&n); e != nil || n != 2 {
					t.Fatal("combined domains/counters", n, e)
				}
			}
			var n int64
			if e = db.Raw("SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq BETWEEN 1 AND 4").Row().Scan(&n); e != nil || n != 4 {
				t.Fatal("combined publication", n, e)
			}
		}
		return
	}
	post := func(op string, body any) (int, []byte) {
		raw, _ := json.Marshal(body)
		req, _ := http.NewRequest("POST", server.URL+"/api/v1/transaksi-"+domain+"/sync/"+op, bytes.NewReader(raw))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		resp, err := server.Client().Do(req)
		if err != nil {
			t.Error(err)
			return 0, nil
		}
		defer resp.Body.Close()
		out, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, out
	}
	request := func(m repositories.TransactionCloudCreate, auth string) (int, []byte) {
		body, _ := json.Marshal(m)
		req, _ := http.NewRequest("POST", server.URL+"/api/v1/transaksi-"+domain+"/sync/create", bytes.NewReader(body))
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
		requestDomain := ""
		if domain == "ppat" {
			requestDomain = domain
		}
		return repositories.TransactionCloudCreate{Domain: requestDomain, MutationID: uuid(0), UUID: uuid(1), PemohonUUID: "00000000-0000-4000-8000-000000000001", PetugasUUID: "00000000-0000-4000-8000-000000000003", Header: repositories.TransactionCloudHeader{Date: time.Now().UTC(), Status: "Baru", Total: 100, InitialPayment: 25, Method: "Cash"}, Details: []repositories.TransactionCloudDetail{{UUID: uuid(2), JobUUID: "00000000-0000-4000-8000-000000000004", PriceUUID: "00000000-0000-4000-8000-000000000005", CategoryUUID: "00000000-0000-4000-8000-000000000006", Name: "Snapshot", Category: "Historical", ServiceCost: 100, Total: 100, ProcessSnapshot: json.RawMessage(`[{"id":"old-local-id","name":"Periksa","attributes":["KTP"]}]`), Processes: []repositories.TransactionCloudProcess{{UUID: uuid(3), Name: "Periksa"}}}}, Payments: []repositories.TransactionCloudPayment{{UUID: uuid(4), Date: time.Now().UTC(), Amount: 25, Method: "Cash", Order: 1}}}
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
	prefix := "100"
	if domain == "ppat" {
		prefix = "200"
	}
	if first.Ack.FinalNumber != prefix+time.Now().In(mustJakarta(t)).Format("020106")+"0001" {
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
	update := m
	update.Details = append([]repositories.TransactionCloudDetail{}, m.Details...)
	update.Details[0].Processes = append(append([]repositories.TransactionCloudProcess{}, m.Details[0].Processes...), repositories.TransactionCloudProcess{UUID: "00000000-0000-4000-8000-000000008888", Name: "Temporary process"})
	update.Details[0].ProcessSnapshot = json.RawMessage(`[{"id":"old-local-id","name":"Periksa","attributes":["KTP"]},{"id":"temporary","name":"Temporary process","attributes":[]}]`)
	update.ExpectedRevision = 1
	update.MutationID = "00000000-0000-4000-8000-000000009001"
	note := "updated"
	update.Header.Note = &note
	code, updatedReceipt := post("update", update)
	if code != 200 {
		t.Fatalf("update=%d %s", code, updatedReceipt)
	}
	if code, replayed := post("update", update); code != 200 || !bytes.Equal(updatedReceipt, replayed) {
		t.Fatalf("update retry=%d %s", code, replayed)
	}
	changed = update
	other := "different"
	changed.Header.Note = &other
	if code, _ := post("update", changed); code != 409 {
		t.Fatal("update reuse", code)
	}
	stale := update
	stale.MutationID = "00000000-0000-4000-8000-000000009002"
	if code, _ := post("update", stale); code != 409 {
		t.Fatal("stale update", code)
	}
	clone := func(m repositories.TransactionCloudCreate) repositories.TransactionCloudCreate {
		raw, _ := json.Marshal(m)
		var c repositories.TransactionCloudCreate
		json.Unmarshal(raw, &c)
		return c
	}
	badPayment := clone(update)
	badPayment.ExpectedRevision = 2
	badPayment.MutationID = "00000000-0000-4000-8000-000000009003"
	badPayment.Payments[0].Amount = 26
	badPayment.Header.InitialPayment = 26
	if code, out := post("update", badPayment); code != 422 {
		t.Fatalf("payment mutation=%d %s", code, out)
	}
	badActor := clone(update)
	badActor.ExpectedRevision = 2
	badActor.MutationID = "00000000-0000-4000-8000-000000009004"
	state := "Valid"
	badActor.Details[0].Processes[0].Status = &state
	if code, _ := post("update", badActor); code != 422 {
		t.Fatal("unresolved process actor", code)
	}
	badChild := clone(update)
	badChild.ExpectedRevision = 2
	badChild.MutationID = "00000000-0000-4000-8000-000000009005"
	badChild.Details[0].UUID = sample(103).Details[0].UUID
	rolledBackNote := "MUST_ROLL_BACK"
	badChild.Header.Note = &rolledBackNote
	if code, _ := post("update", badChild); code != 422 {
		t.Fatal("child reparenting", code)
	}
	var revision int64
	if e = db.Raw("SELECT revision FROM transaction_cloud WHERE uuid=?::uuid", m.UUID).Row().Scan(&revision); e != nil || revision != 2 {
		t.Fatal("failed update partial write", revision, e)
	}
	var actualNote string
	var activeChildren int64
	if e = db.Raw("SELECT header->>'note' FROM transaction_cloud WHERE uuid=?::uuid", m.UUID).Row().Scan(&actualNote); e != nil || actualNote != "updated" {
		t.Fatal("failed update changed header", actualNote, e)
	}
	if e = db.Raw("SELECT count(*) FROM transaction_cloud_process WHERE detail_uuid=?::uuid AND deleted_at IS NULL", m.Details[0].UUID).Row().Scan(&activeChildren); e != nil || activeChildren != 2 {
		t.Fatal("failed update changed children", activeChildren, e)
	}
	var paymentSnapshotBefore []byte
	db.Raw("SELECT snapshot FROM transaction_cloud_payment WHERE transaction_id=?", first.Ack.ServerID).Row().Scan(&paymentSnapshotBefore)
	statuses := make(chan int, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			u := clone(update)
			u.Details[0].Processes = u.Details[0].Processes[:1]
			u.Details[0].ProcessSnapshot = m.Details[0].ProcessSnapshot
			u.ExpectedRevision = 2
			u.MutationID = fmt.Sprintf("00000000-0000-4000-8000-%012d", 9100+i)
			s, _ := post("update", u)
			statuses <- s
		}(i)
	}
	wg.Wait()
	close(statuses)
	wins, conflicts := 0, 0
	for s := range statuses {
		if s == 200 {
			wins++
		} else if s == 409 {
			conflicts++
		} else {
			t.Fatal("concurrent update", s)
		}
	}
	if wins != 1 || conflicts != 1 {
		t.Fatal("optimistic concurrency", wins, conflicts)
	}
	var removed int64
	if e = db.Raw("SELECT count(*) FROM transaction_cloud_process WHERE uuid='00000000-0000-4000-8000-000000008888' AND deleted_at IS NOT NULL").Row().Scan(&removed); e != nil || removed != 1 {
		t.Fatal("removed process tombstone", removed, e)
	}
	del := repositories.TransactionCloudDelete{Domain: domain, MutationID: "00000000-0000-4000-8000-000000009201", UUID: m.UUID, ExpectedRevision: 3}
	code, deletedReceipt := post("delete", del)
	if code != 200 {
		t.Fatalf("delete=%d %s", code, deletedReceipt)
	}
	if code, replay := post("delete", del); code != 200 || !bytes.Equal(deletedReceipt, replay) {
		t.Fatal("delete retry", code)
	}
	var paymentSnapshotAfter []byte
	db.Raw("SELECT snapshot FROM transaction_cloud_payment WHERE transaction_id=?", first.Ack.ServerID).Row().Scan(&paymentSnapshotAfter)
	if !bytes.Equal(paymentSnapshotBefore, paymentSnapshotAfter) {
		t.Fatal("committed payment rewritten")
	}
	for _, table := range []string{"transaction_cloud", "transaction_cloud_detail", "transaction_cloud_process", "transaction_cloud_payment", "transaction_cloud_mutation", "transaction_cloud_outbox"} {
		if e = db.Table(table).Count(new(int64)).Error; e != nil {
			t.Fatal(e)
		}
		var n int64
		db.Table(table).Count(&n)
		want := int64(3)
		if table == "transaction_cloud_process" {
			want = 4
		}
		if table == "transaction_cloud_mutation" || table == "transaction_cloud_outbox" {
			want = 6
		}
		if n != want {
			t.Fatal(table, n)
		}
	}
	for i, want := range []int{2, 2, 2, 0} {
		n, e := repositories.NewTransactionCloudRepository(db).Publish(context.Background(), 2)
		if e != nil || n != want {
			t.Fatal("publish", i, n, e)
		}
	}
	page, e := repositories.NewTransactionCloudRepository(db).Pull(context.Background(), 0, 2)
	if e != nil || len(page.Changes) != 2 || !page.HasMore || page.NextCursor != 2 || len(page.Changes[0].Aggregate.Payments) != 1 || len(page.Changes[0].Aggregate.Details[0].Processes) != 1 {
		t.Fatal("aggregate page", page, e)
	}
	lastPage, e := repositories.NewTransactionCloudRepository(db).Pull(context.Background(), 5, 1)
	if e != nil || len(lastPage.Changes) != 1 || lastPage.Changes[0].Operation != "delete" || lastPage.Changes[0].Revision != 4 || lastPage.Changes[0].Aggregate.DeletedAt == nil {
		t.Fatal("published transaction tombstone", lastPage, e)
	}
	if domain == "ppat" {
		postDomain := func(target, op string, body any) (int, []byte) {
			raw, _ := json.Marshal(body)
			req, _ := http.NewRequest("POST", server.URL+"/api/v1/transaksi-"+target+"/sync/"+op, bytes.NewReader(raw))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("Authorization", "Bearer "+token)
			resp, err := server.Client().Do(req)
			if err != nil {
				t.Fatal(err)
			}
			defer resp.Body.Close()
			out, _ := io.ReadAll(resp.Body)
			return resp.StatusCode, out
		}
		// UUID identity is global: a domain switch is rejected, never reconciled by name.
		collision := clone(m)
		collision.Domain = "notaris"
		collision.MutationID = "00000000-0000-4000-8000-000000009701"
		if code, _ := postDomain("notaris", "create", collision); code != 409 {
			t.Fatal("cross-domain UUID collision", code)
		}
		invalidJob := sample(971)
		invalidJob.Details[0].JobUUID = "00000000-0000-4000-8000-000000000044"
		invalidJob.Details[0].PriceUUID = "00000000-0000-4000-8000-000000000045"
		if code, _ := postDomain("ppat", "create", invalidJob); code != 422 {
			t.Fatal("Notaris-only reference accepted for PPAT", code)
		}
		independent := sample(972)
		independent.Domain = "notaris"
		code, body := postDomain("notaris", "create", independent)
		if code != 200 {
			t.Fatalf("Notaris alongside PPAT=%d %s", code, body)
		}
		var separate struct {
			Ack repositories.TransactionCloudAck `json:"acknowledgement"`
		}
		json.Unmarshal(body, &separate)
		if separate.Ack.FinalNumber != "100"+time.Now().In(mustJakarta(t)).Format("020106")+"0001" {
			t.Fatal("domain counter leaked", separate)
		}
		var ppatCounter int64
		if err := db.Raw("SELECT last_number FROM transaction_cloud_number_counter WHERE domain='ppat'").Row().Scan(&ppatCounter); err != nil || ppatCounter != 3 {
			t.Fatal("PPAT counter changed", ppatCounter, err)
		}
		attack := clone(independent)
		attack.Domain = "ppat"
		attack.ExpectedRevision = 1
		attack.MutationID = "00000000-0000-4000-8000-000000009702"
		if code, _ := postDomain("ppat", "update", attack); code != 409 {
			t.Fatal("PPAT updated Notaris UUID", code)
		}
		if code, _ := postDomain("ppat", "delete", repositories.TransactionCloudDelete{Domain: "ppat", MutationID: "00000000-0000-4000-8000-000000009703", UUID: independent.UUID, ExpectedRevision: 1}); code != 409 {
			t.Fatal("PPAT deleted Notaris UUID", code)
		}
		var preserved int64
		if err := db.Raw("SELECT count(*) FROM transaction_cloud WHERE uuid=?::uuid AND domain='notaris' AND revision=1 AND deleted_at IS NULL", independent.UUID).Row().Scan(&preserved); err != nil || preserved != 1 {
			t.Fatal("Notaris modified by PPAT", preserved, err)
		}
		var correct int64
		if err := db.Raw("SELECT count(*) FROM transaction_cloud_detail WHERE domain='ppat' AND pekerjaan_notaris_id IS NULL AND harga_id IS NULL AND pekerjaan_ppat_id=1901 AND harga_ppat_id=1701").Row().Scan(&correct); err != nil || correct != 3 {
			t.Fatal("domain references mixed", correct, err)
		}
		if n, err := repositories.NewTransactionCloudRepository(db).Publish(context.Background(), 2); err != nil || n != 1 {
			t.Fatal("combined publication", n, err)
		}
		page, err := repositories.NewTransactionCloudRepository(db).Pull(context.Background(), 6, 1)
		if err != nil || len(page.Changes) != 1 || page.Changes[0].Aggregate.Domain != "notaris" || page.NextCursor != 7 {
			t.Fatal("shared domain-tagged feed", page, err)
		}
	}
	if e = db.Exec(`UPDATE sidebar_akses SET "create"=0,"read"=0`).Error; e != nil {
		t.Fatal(e)
	}
	if code, _ := request(sample(105), token); code != 403 {
		t.Fatal("permission", code)
	}
	if e = db.Exec(`UPDATE sidebar_akses SET "update"=0,"delete"=0`).Error; e != nil {
		t.Fatal(e)
	}
	if code, _ := post("update", update); code != 403 {
		t.Fatal("update permission", code)
	}
	if code, _ := post("delete", del); code != 403 {
		t.Fatal("delete permission", code)
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
