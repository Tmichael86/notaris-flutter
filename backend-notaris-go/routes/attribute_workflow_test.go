package routes

import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

const (
	workflowProcess = "74100000-0000-4000-8000-000000000005"
	workflowOther   = "74100000-0000-4000-8000-000000000015"
	workflowBase    = "/api/v1/attribute-workflow"
)

func workflowFixture(t *testing.T, passwords []string) (*gin.Engine, *gorm.DB) {
	t.Helper()
	dsn := os.Getenv("NOTARIS_ATTRIBUTE_TEST_DSN")
	if dsn == "" {
		t.Skip("owned disposable workflow DSN unset")
	}
	cfg, e := pgx.ParseConfig(dsn)
	if e != nil || cfg.Host != "127.0.0.1" || cfg.Port < 55400 || cfg.Port > 55999 ||
		!regexp.MustCompile(`^attribute_demo_[0-9a-f]{12}$`).MatchString(cfg.Database) {
		t.Fatal("owned workflow database required")
	}
	admin := stdlib.OpenDB(*cfg)
	t.Cleanup(func() { admin.Close() })
	var target, host, marker string
	var port uint16
	if e = admin.QueryRow(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),
        coalesce(shobj_description(oid,'pg_database'),'') FROM pg_database WHERE datname=current_database()`).
		Scan(&target, &host, &port, &marker); e != nil || target != cfg.Database || host != cfg.Host || port != cfg.Port || marker != "NOTARIS ATTRIBUTE DISPOSABLE "+target {
		t.Fatal("owned workflow database unavailable")
	}
	schema := fmt.Sprintf("attribute_workflow_%d", time.Now().UnixNano())
	if _, e = admin.Exec("CREATE SCHEMA " + schema); e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() {
		if _, e := admin.Exec("DROP SCHEMA " + schema + " CASCADE"); e != nil {
			t.Error(e)
		}
	})
	cfg.RuntimeParams["search_path"] = schema
	pool := stdlib.OpenDB(*cfg)
	t.Cleanup(func() { pool.Close() })
	db, e := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{})
	if e != nil {
		t.Fatal(e)
	}
	previous := database.DB
	database.DB = db
	t.Cleanup(func() { database.DB = previous })
	if e = db.AutoMigrate(&models.Group{}, &models.User{}, &models.Sidebar{}, &models.SidebarAccess{}); e != nil {
		t.Fatal(e)
	}
	workflowSQL(t, db, `
 CREATE TABLE pemohon(id bigint PRIMARY KEY);
 CREATE TABLE petugas(id bigint PRIMARY KEY);
 CREATE TABLE pekerjaan_kategori(id bigint PRIMARY KEY);
 CREATE TABLE pekerjaan_notaris(id bigint PRIMARY KEY);
 CREATE TABLE pekerjaan_notaris_harga(id bigint PRIMARY KEY);
 CREATE TABLE pekerjaan_ppat(id bigint PRIMARY KEY);
 CREATE TABLE pekerjaan_ppat_harga(id bigint PRIMARY KEY);
 INSERT INTO pemohon VALUES(1); INSERT INTO petugas VALUES(1);
 INSERT INTO pekerjaan_kategori VALUES(1); INSERT INTO pekerjaan_notaris VALUES(1); INSERT INTO pekerjaan_notaris_harga VALUES(1);
 INSERT INTO groups(id,group_nama,status) VALUES(71,'Petugas',1),(72,'Validator',1),(73,'Tanpa akses',1);
 INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(71,'Transaksi','transaksi','/transaksi',1);
 INSERT INTO sidebar_akses(id,group_id,sidebar_id,"read","create","update","delete") VALUES(71,71,71,1,0,0,0),(72,72,71,1,0,0,0);`)
	for _, name := range []string{"20261105_transaction_notaris_create.sql", "20261105_transaction_notaris_mutations.sql", "20261105_transaction_ppat_domain.sql", "20261110_attribute_workflow.sql"} {
		body, e := os.ReadFile("../migration_proposals/" + name)
		if e != nil {
			t.Fatal(e)
		}
		workflowSQL(t, db, string(body))
	}
	for i, user := range []struct {
		id, group      int
		username, name string
	}{
		{71, 71, "demo.dimas", "Dimas Prasetyo"}, {72, 72, "demo.nabila", "Nabila Putri"},
		{73, 72, "demo.other-office", "Validator kantor lain"}, {74, 73, "demo.no-access", "Akun tanpa akses Transaksi"},
	} {
		hash, e := bcrypt.GenerateFromPassword([]byte(passwords[i]), bcrypt.DefaultCost)
		if e != nil {
			t.Fatal(e)
		}
		workflowSQL(t, db, "INSERT INTO users(id,group_id,username,nama,password,status) VALUES(?,?,?,?,?,1)", user.id, user.group, user.username, user.name, string(hash))
	}
	workflowSQL(t, db, `
 INSERT INTO transaction_cloud(id,uuid,final_number,revision,pemohon_id,petugas_id,header,domain)
 VALUES(1,'74100000-0000-4000-8000-000000000003','1001011260001',1,1,1,'{}','notaris');
 INSERT INTO transaction_cloud_detail(uuid,transaction_id,pekerjaan_notaris_id,harga_id,kategori_id,snapshot,domain)
 VALUES('74100000-0000-4000-8000-000000000004',1,1,1,1,'{}','notaris'),
       ('74100000-0000-4000-8000-000000000014',1,1,1,1,'{}','notaris');
 INSERT INTO transaction_cloud_process(uuid,detail_uuid,snapshot)
 VALUES('74100000-0000-4000-8000-000000000005','74100000-0000-4000-8000-000000000004','{"source_id":"1","name":"Pemeriksaan Berkas"}'),
       ('74100000-0000-4000-8000-000000000015','74100000-0000-4000-8000-000000000014','{"source_id":"1","name":"Pemeriksaan Berkas"}');
 INSERT INTO attribute_workflow_office VALUES('74100000-0000-4000-8000-000000000020'),('74100000-0000-4000-8000-000000000021');
 INSERT INTO attribute_workflow_member VALUES
 ('74100000-0000-4000-8000-000000000020',71,'worker'),('74100000-0000-4000-8000-000000000020',72,'reviewer'),
 ('74100000-0000-4000-8000-000000000021',73,'reviewer'),('74100000-0000-4000-8000-000000000020',74,'reviewer');
 INSERT INTO attribute_workflow_definition VALUES ('74100000-0000-4000-8000-000000000006','74100000-0000-4000-8000-000000000020','Catatan Pemeriksaan Identitas','text','1');
 INSERT INTO attribute_workflow_item(process_uuid,definition_uuid,office_uuid) VALUES
 ('74100000-0000-4000-8000-000000000005','74100000-0000-4000-8000-000000000006','74100000-0000-4000-8000-000000000020'),
 ('74100000-0000-4000-8000-000000000015','74100000-0000-4000-8000-000000000006','74100000-0000-4000-8000-000000000020');`)
	secret := make([]byte, 32)
	if _, e = rand.Read(secret); e != nil {
		t.Fatal(e)
	}
	settings := config.Config{JWTSecret: hex.EncodeToString(secret), JWTExpireMinutes: 120}
	router := SetupRouter(settings, controllers.NewHealthController(), nil, nil, nil, nil, nil, nil,
		controllers.NewAuthController(services.NewAuthService(settings)), controllers.NewMeController(), nil, nil)
	RegisterAttributeWorkflow(router, settings, repositories.AttributeWorkflow{DB: db})
	return router, db
}

func workflowSQL(t *testing.T, db *gorm.DB, sql string, args ...any) {
	t.Helper()
	if e := db.Exec(sql, args...).Error; e != nil {
		t.Fatal(e)
	}
}

func TestAttributeWorkflowPostgres(t *testing.T) {
	router, db := workflowFixture(t, []string{"disposable-dimas", "disposable-nabila", "disposable-other", "disposable-no-access"})
	server := httptest.NewServer(router)
	defer server.Close()
	var token string
	request := func(method, path string, body any, status int) map[string]any {
		t.Helper()
		payload, _ := json.Marshal(body)
		req, e := http.NewRequest(method, server.URL+path, bytes.NewReader(payload))
		if e != nil {
			t.Fatal(e)
		}
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		res, e := server.Client().Do(req)
		if e != nil {
			t.Fatal(e)
		}
		defer res.Body.Close()
		var result map[string]any
		if e = json.NewDecoder(res.Body).Decode(&result); e != nil {
			t.Fatal(e)
		}
		if res.StatusCode != status {
			t.Fatalf("%s %s got %d, want %d: %v", method, path, res.StatusCode, status, result)
		}
		return result
	}
	login := func(name, password string) string {
		t.Helper()
		return request("POST", "/api/v1/auth/login", gin.H{"username": name, "password": password}, 200)["data"].(map[string]any)["token"].(string)
	}
	dimas := login("demo.dimas", "disposable-dimas")
	nabila := login("demo.nabila", "disposable-nabila")
	other := login("demo.other-office", "disposable-other")
	noAccess := login("demo.no-access", "disposable-no-access")
	path := workflowBase + "/processes/" + workflowProcess
	inbox := workflowBase + "/inbox"
	data := func(path string) map[string]any { return request("GET", path, nil, 200)["data"].(map[string]any) }
	notifications := func() []any { return request("GET", inbox, nil, 200)["data"].([]any) }
	cmd := func(n, rev int, action string, extra gin.H, status int) {
		t.Helper()
		body := gin.H{"mutation_id": fmt.Sprintf("74100000-0000-4000-8000-%012d", 100+n), "definition_uuid": "74100000-0000-4000-8000-000000000006", "expected_revision": rev, "action": action}
		for k, v := range extra {
			body[k] = v
		}
		request("POST", path, body, status)
	}
	token = other
	request("GET", path, nil, 403)
	if len(notifications()) != 0 {
		t.Fatal("cross-office inbox leak")
	}
	token = noAccess
	request("GET", path, nil, 403)
	token = dimas
	if v := data(path); v["revision"] != float64(0) || len(v["history"].([]any)) != 0 {
		t.Fatal("read initialized process")
	}
	cmd(1, 0, "initialize", nil, 200)
	cmd(1, 0, "initialize", nil, 200)
	cmd(2, 0, "initialize", nil, 200)
	request("POST", path, gin.H{"action": "submit", "actor_id": 72}, 422)
	cmd(3, 0, "submit", gin.H{"value": "stale"}, 409)
	cmd(11, 1, "submit", gin.H{"definition_uuid": workflowOther, "value": "wrong definition"}, 409)
	cmd(4, 1, "submit", gin.H{"value": "Identitas diperiksa"}, 200)
	cmd(4, 1, "submit", gin.H{"value": "Identitas diperiksa"}, 200)
	cmd(4, 1, "submit", gin.H{"value": "payload changed"}, 409)
	cmd(5, 2, "submit", gin.H{"value": "silent edit"}, 409)
	cmd(6, 2, "approve", nil, 403)
	workflowSQL(t, db, "UPDATE attribute_workflow_member SET role='reviewer' WHERE user_id=71")
	cmd(6, 2, "approve", nil, 403)
	workflowSQL(t, db, "UPDATE attribute_workflow_member SET role='worker' WHERE user_id=71")
	request("POST", inbox+"/74100000-0000-4000-8000-000000000104/read", nil, 403)
	token = nabila
	if n := notifications(); len(n) != 1 || n[0].(map[string]any)["read_at"] != nil {
		t.Fatal("incorrect recipient or duplicate inbox")
	}
	mark := inbox + "/74100000-0000-4000-8000-000000000104/read"
	request("POST", mark, nil, 200)
	firstRead := notifications()[0].(map[string]any)["read_at"]
	request("POST", mark, nil, 200)
	if firstRead == nil || notifications()[0].(map[string]any)["read_at"] != firstRead {
		t.Fatal("read state not idempotent")
	}
	cmd(7, 2, "revise", nil, 422)
	cmd(8, 2, "revise", gin.H{"reason": "Lengkapi catatan"}, 200)
	token = dimas
	if n := notifications(); len(n) != 1 || n[0].(map[string]any)["reason"] != "Lengkapi catatan" {
		t.Fatal("revision not routed")
	}
	cmd(9, 3, "submit", gin.H{"value": "Identitas dan ejaan diperiksa"}, 200)
	token = nabila
	cmd(10, 4, "approve", nil, 200)
	cmd(10, 4, "approve", nil, 200)
	token = dimas
	if len(notifications()) != 2 {
		t.Fatal("approval not routed once")
	}
	current := data(path)
	if current["status"] != "valid" || current["version"] != float64(2) || current["revision"] != float64(5) {
		t.Fatal(current)
	}
	h := current["history"].([]any)
	if len(h) != 5 || h[1].(map[string]any)["value"] != "Identitas diperiksa" || h[3].(map[string]any)["value"] != "Identitas dan ejaan diperiksa" || h[4].(map[string]any)["actor_id"] != float64(72) {
		t.Fatal("history not frozen")
	}
	if untouched := data(workflowBase + "/processes/" + workflowOther); untouched["revision"] != float64(0) || untouched["detail_uuid"] == current["detail_uuid"] {
		t.Fatal("detail isolation lost")
	}
	var modified int
	if e := db.Raw(`SELECT (SELECT count(*) FROM transaction_cloud_outbox)+(SELECT count(*) FROM transaction_cloud_mutation)+(SELECT last_seq FROM transaction_cloud_publication)+(SELECT count(*) FROM transaction_cloud WHERE revision!=1 OR header!='{}'::jsonb)`).Scan(&modified).Error; e != nil || modified != 0 {
		t.Fatal("transaction contract modified", e)
	}
	// A new repository/router still reads from durable storage.
	if restored, e := (repositories.AttributeWorkflow{DB: db}).View(t.Context(), workflowProcess, 71); e != nil || restored.Status != "valid" || len(restored.History) != 5 {
		t.Fatal("durable read failed", e)
	}
}

func TestAttributeWorkflowFlutterPostgres(t *testing.T) {
	if os.Getenv("NOTARIS_ATTRIBUTE_FLUTTER_E2E") != "1" {
		t.Skip("disposable Flutter integration opt-in unset")
	}
	router, _ := workflowFixture(t, []string{"disposable-dimas", "disposable-nabila", "disposable-other", "disposable-no-access"})
	server := httptest.NewServer(router)
	defer server.Close()
	args := []string{"test", "--no-pub", "test/e2e/attribute_workflow_e2e_test.dart", "--reporter", "expanded"}
	command := exec.CommandContext(t.Context(), "flutter", args...)
	if runtime.GOOS == "windows" {
		command = exec.CommandContext(t.Context(), "cmd", append([]string{"/c", "flutter"}, args...)...)
	}
	command.Dir = "../../frontend_notaris"
	command.Env = append(os.Environ(), "ATTRIBUTE_TEST_URL="+server.URL+"/api/v1")
	output, err := command.CombinedOutput()
	t.Log(string(output))
	if err != nil {
		t.Fatal(err)
	}
}

// Opt-in interactive server owns only the generated schema. Ctrl+C releases it.
func TestAttributeWorkflowDemo(t *testing.T) {
	if os.Getenv("NOTARIS_ATTRIBUTE_DEMO") != "1" {
		t.Skip("interactive disposable mode unset")
	}
	identity := make([]byte, 16)
	if _, err := rand.Read(identity); err != nil {
		t.Fatal(err)
	}
	nonce := hex.EncodeToString(identity)
	dimas, nabila := os.Getenv("NOTARIS_ATTRIBUTE_DIMAS_PASSWORD"), os.Getenv("NOTARIS_ATTRIBUTE_NABILA_PASSWORD")
	if len(dimas) < 12 || len(nabila) < 12 || dimas == nabila || len(dimas) > 72 || len(nabila) > 72 {
		t.Fatal("distinct demo passwords of 12–72 bytes required")
	}
	router, _ := workflowFixture(t, []string{dimas, nabila, strings.Repeat(nonce, 2), nonce + "-disabled"})
	router.GET(workflowBase+"/demo-profile", func(c *gin.Context) { c.JSON(200, gin.H{"demo_id": nonce}) })
	listener, e := net.Listen("tcp", "127.0.0.1:56781")
	if e != nil {
		t.Fatal(e)
	}
	server := &http.Server{Handler: router, ReadHeaderTimeout: 5 * time.Second}
	defer server.Close()
	ctx, stop := signal.NotifyContext(t.Context(), os.Interrupt)
	defer stop()
	done := make(chan error, 1)
	go func() { done <- server.Serve(listener) }()
	fmt.Println("ATTRIBUTE_DEMO_READY http://127.0.0.1:56781/api/v1 " + nonce)
	select {
	case <-ctx.Done():
	case e := <-done:
		t.Fatal(e)
	}
}
