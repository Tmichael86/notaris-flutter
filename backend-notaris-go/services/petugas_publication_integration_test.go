package services_test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func TestPublicationRuntimePostgres(t *testing.T) {
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
	schema := fmt.Sprintf("petugas_runtime_test_%d", time.Now().UnixNano())
	if _, err := admin.Exec("CREATE SCHEMA " + schema); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec("DROP SCHEMA " + schema + " CASCADE")
	cfg.RuntimeParams["search_path"] = schema
	cfg.RuntimeParams["statement_timeout"] = "10000"
	pool := stdlib.OpenDB(*cfg)
	defer pool.Close()
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("CREATE TABLE petugas(id bigint PRIMARY KEY,nama text); INSERT INTO petugas VALUES(70,'Unchanged')").Error; err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"20261029_01_petugas_cloud_sync.sql", "20261030_01_petugas_publication.sql"} {
		b, err := os.ReadFile(filepath.Join("..", "migrations", name))
		if err != nil {
			t.Fatal(err)
		}
		if err := db.Exec(string(b)).Error; err != nil {
			t.Fatal(err)
		}
	}
	var before string
	if err := db.Raw("SELECT row_to_json(p)::text FROM petugas p").Row().Scan(&before); err != nil {
		t.Fatal(err)
	}
	insert := func(tx *gorm.DB) int64 {
		t.Helper()
		var id int64
		if err := tx.Raw(`INSERT INTO petugas_sync_outbox(petugas_uuid,row_version,tombstone,payload) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,false,'{}') RETURNING id`).Row().Scan(&id); err != nil {
			t.Fatal(err)
		}
		return id
	}
	a := db.Begin()
	if a.Error != nil {
		t.Fatal(a.Error)
	}
	defer a.Rollback()
	idA := insert(a)
	idB := insert(db)
	if idA >= idB {
		t.Fatal("A was not allocated first")
	}
	options := services.PublicationWorkerOptions{BatchSize: 1, Interval: 10 * time.Millisecond, AttemptTimeout: time.Second, MaxBackoff: 100 * time.Millisecond}
	repo := repositories.NewPetugasPublicationRepository(db)
	start := func(n int) func() {
		ctx, cancel := context.WithCancel(context.Background())
		var wg sync.WaitGroup
		for i := 0; i < n; i++ {
			w, err := services.NewPetugasPublicationWorker(repo, options, nil)
			if err != nil {
				t.Fatal(err)
			}
			wg.Add(1)
			go func() { defer wg.Done(); w.Run(ctx) }()
		}
		return func() { cancel(); wg.Wait() }
	}
	waitSeq := func(id int64, want int64) {
		t.Helper()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		ticker := time.NewTicker(5 * time.Millisecond)
		defer ticker.Stop()
		for {
			var seq int64
			if err := db.WithContext(ctx).Raw("SELECT COALESCE(publication_seq,0) FROM petugas_sync_outbox WHERE id=?", id).Row().Scan(&seq); err != nil {
				t.Fatal(err)
			}
			if seq == want {
				return
			}
			select {
			case <-ctx.Done():
				t.Fatalf("event %d expected seq %d got %d", id, want, seq)
			case <-ticker.C:
			}
		}
	}
	stop := start(2)
	defer stop()
	waitSeq(idB, 1) // A still uncommitted: workers must not reserve a cursor for it.
	if err := a.Commit().Error; err != nil {
		t.Fatal(err)
	}
	waitSeq(idA, 2)
	stop()
	idC := insert(db) // Pending event while runtime is stopped survives restart.
	restartStop := start(1)
	defer restartStop()
	waitSeq(idC, 3)
	restartStop()
	var total, distinct int64
	if err := db.Raw("SELECT count(*),count(DISTINCT publication_seq) FROM petugas_sync_outbox").Row().Scan(&total, &distinct); err != nil {
		t.Fatal(err)
	}
	if total != 3 || distinct != 3 {
		t.Fatal("duplicate/missing publication")
	}
	var after string
	if err := db.Raw("SELECT row_to_json(p)::text FROM petugas p").Row().Scan(&after); err != nil {
		t.Fatal(err)
	}
	if before != after {
		t.Fatal("runtime altered Petugas")
	}
}
