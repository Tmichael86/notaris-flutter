package middleware

import (
	"backend-notaris-go/database"
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"net/http/httptest"
	"os"
	"testing"
	"time"
)

func TestAcceptanceActualConnectionRejectsDisposable(t *testing.T) {
	dsn := os.Getenv("NOTARIS_SYNC_TEST_DSN")
	if dsn == "" {
		t.Skip("owned disposable DSN required")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Host != "127.0.0.1" || cfg.Port < 55400 || cfg.Port > 55999 {
		t.Fatal("disposable only")
	}
	admin := stdlib.OpenDB(*cfg)
	defer admin.Close()
	schema := fmt.Sprintf("attestation_%d", time.Now().UnixNano())
	if _, err = admin.Exec("CREATE SCHEMA " + schema); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec("DROP SCHEMA " + schema + " CASCADE")
	cfg.RuntimeParams["search_path"] = schema
	sqlDB := stdlib.OpenDB(*cfg)
	defer sqlDB.Close()
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: sqlDB}), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err = db.Exec("CREATE TABLE konfigurasi_umum(id int PRIMARY KEY,notaris_bersangkutan text); INSERT INTO konfigurasi_umum VALUES(1,'NOTARISDEV SYNTHETIC v1')").Error; err != nil {
		t.Fatal(err)
	}
	old := database.DB
	database.DB = db
	defer func() { database.DB = old }()
	c, _ := gin.CreateTestContext(httptest.NewRecorder())
	c.Request = httptest.NewRequest("GET", "/", nil)
	gate := &AcceptanceGate{Plan: fixturePlan()}
	if _, err = gate.probe(c); err == nil {
		t.Fatal("synthetic marker alone incorrectly authorized a different active DB connection")
	}
	c.Set("user_id", uint(2001))
	c.Set("group_id", uint(11))
	w := httptest.NewRecorder()
	c.Writer = gin.CreateTestContextOnly(w, gin.New()).Writer
	gate.Attest(c)
	if w.Code != 409 {
		t.Fatalf("got %d", w.Code)
	}
}
