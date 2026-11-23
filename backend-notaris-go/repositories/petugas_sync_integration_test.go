package repositories

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"backend-notaris-go/synccontract"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// Only an explicitly supplied TEST DSN is used. Production config and .env are
// never loaded. Each run owns a unique schema with a restricted search_path.
func syncTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	dsn := os.Getenv("NOTARIS_SYNC_TEST_DSN")
	if dsn == "" {
		t.Skip("PostgreSQL integration not run: NOTARIS_SYNC_TEST_DSN is unset")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnectTimeout = 5 * time.Second
	admin := stdlib.OpenDB(*cfg)
	t.Cleanup(func() { _ = admin.Close() })
	schema := fmt.Sprintf("petugas_sync_test_%d", time.Now().UnixNano())
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if _, err := admin.ExecContext(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if _, err := admin.ExecContext(ctx, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Error(err)
		}
	})
	cfg.RuntimeParams["search_path"] = schema
	cfg.RuntimeParams["statement_timeout"] = "10000"
	pool := stdlib.OpenDB(*cfg)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = pool.Close() })
	// Minimal legacy PostgreSQL fixture, then the actual additive migration.
	ddl := `CREATE TABLE users (id bigint PRIMARY KEY);
CREATE TABLE jenis_kelamin (id bigint PRIMARY KEY);
CREATE TABLE petugas (
 id bigserial PRIMARY KEY, nik text, nama text NOT NULL, alamat text,
 tempat_lahir text, tanggal_lahir date, jenis_kelamin bigint REFERENCES jenis_kelamin(id),
 no_telp text, email text NOT NULL CHECK (email <> 'constraint-failure@example.com'),
 user_id bigint REFERENCES users(id), created_by bigint, updated_by bigint,
 created_at timestamptz, updated_at timestamptz, status smallint NOT NULL);
INSERT INTO users VALUES (1); INSERT INTO jenis_kelamin VALUES (2);
INSERT INTO petugas (id,nama,email,status) VALUES (70,'Legacy','legacy@example.com',1);`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile(filepath.Join("..", "migrations", "20261029_01_petugas_cloud_sync.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(migration)).Error; err != nil {
		t.Fatal(err)
	}
	return db
}

func TestPetugasSyncPostgres(t *testing.T) {
	db := syncTestDB(t)
	r := NewPetugasSyncRepository(db)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	mutation := func(n int) synccontract.PetugasMutation {
		return testMutation(fmt.Sprintf("bbbbbbbb-bbbb-4bbb-8bbb-%012d", n))
	}
	count := func(table string) int64 {
		t.Helper()
		var n int64
		if err := db.Table(table).Count(&n).Error; err != nil {
			t.Fatal(err)
		}
		return n
	}
	m := mutation(1)
	userID, genderID := uint(1), uint(2)
	m.Payload.UserID, m.Payload.JenisKelaminID = &userID, &genderID
	ack, err := r.Apply(ctx, m, 1)
	if err != nil {
		t.Fatal(err)
	}
	if ack.ServerID == 70 || ack.RowVersion != 1 {
		t.Fatalf("invalid create: %+v", ack)
	}
	initialID := ack.ServerID
	if count("petugas_sync_outbox") != 1 || count("petugas_sync_mutations") != 1 {
		t.Fatal("missing atomic event/receipt")
	}
	retry, err := r.Apply(ctx, m, 1)
	if err != nil || *ack != *retry {
		t.Fatalf("lost response replay: %+v %v", retry, err)
	}
	_, err = r.Apply(ctx, mutation(2), 1)
	var conflict *PetugasVersionConflict
	if !errors.As(err, &conflict) || conflict.Current.ID != initialID {
		t.Fatalf("duplicate UUID create: %v", err)
	}
	changed := mutation(1)
	changed.Payload.Nama = "Changed"
	if _, err = r.Apply(ctx, changed, 1); !errors.Is(err, ErrMutationReuse) {
		t.Fatalf("mutation reuse: %v", err)
	}

	// Two concurrent edits based on version 1: exactly one wins.
	v := int64(1)
	var wg sync.WaitGroup
	results := make(chan error, 2)
	for _, n := range []int{3, 4} {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			m := mutation(n)
			m.ExpectedRowVersion = &v
			_, err := r.Apply(ctx, m, 1)
			results <- err
		}(n)
	}
	wg.Wait()
	close(results)
	wins, conflicts := 0, 0
	for err := range results {
		if err == nil {
			wins++
		} else if errors.As(err, &conflict) {
			conflicts++
		} else {
			t.Fatal(err)
		}
	}
	if wins != 1 || conflicts != 1 {
		t.Fatalf("concurrent edits: wins=%d conflicts=%d", wins, conflicts)
	}
	if count("petugas_sync_outbox") != 2 {
		t.Fatal("losing edit produced event")
	}
	// Original mutation still replays original version, not the latest row.
	retry, err = r.Apply(ctx, m, 1)
	if err != nil || retry.RowVersion != 1 {
		t.Fatalf("historical receipt: %+v %v", retry, err)
	}
	deleted := mutation(5)
	v2 := int64(2)
	deleted.ExpectedRowVersion = &v2
	deleted.Operation = synccontract.PetugasDelete
	deleted.Payload = nil
	ack, err = r.Apply(ctx, deleted, 1)
	if err != nil || !ack.Tombstone || ack.RowVersion != 3 || ack.ServerID != initialID {
		t.Fatalf("delete: %+v %v", ack, err)
	}
	if _, err = r.Apply(ctx, deleted, 1); err != nil {
		t.Fatal(err)
	}
	repeated := deleted
	repeated.MutationID = mutation(6).MutationID
	v3 := int64(3)
	repeated.ExpectedRowVersion = &v3
	if _, err = r.Apply(ctx, repeated, 1); err != nil {
		t.Fatal(err)
	}
	if count("petugas_sync_outbox") != 3 {
		t.Fatal("repeated delete duplicated event")
	}
	if count("petugas") != 2 {
		t.Fatal("delete removed legacy or sync record")
	}

	beforeReceipts, beforeEvents := count("petugas_sync_mutations"), count("petugas_sync_outbox")
	invalid := mutation(7)
	invalid.PetugasUUID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
	missing := uint(999)
	invalid.Payload.UserID = &missing
	if _, err = r.Apply(ctx, invalid, 1); !errors.Is(err, ErrPetugasReference) {
		t.Fatalf("user validation: %v", err)
	}
	invalid.Payload.UserID = nil
	invalid.Payload.JenisKelaminID = &missing
	if _, err = r.Apply(ctx, invalid, 1); !errors.Is(err, ErrPetugasReference) {
		t.Fatalf("gender validation: %v", err)
	}
	invalid.Payload.JenisKelaminID = nil
	invalid.Payload.Email = "constraint-failure@example.com"
	if _, err = r.Apply(ctx, invalid, 1); !errors.Is(err, ErrPetugasConstraint) {
		t.Fatalf("constraint: %v", err)
	}
	// Force a failure after row write, at outbox insertion; verify full rollback.
	if err := db.Exec("ALTER TABLE petugas_sync_outbox ADD CONSTRAINT test_reject_event CHECK (row_version < 0) NOT VALID").Error; err != nil {
		t.Fatal(err)
	}
	invalid.Payload.Email = "valid@example.com"
	if _, err = r.Apply(ctx, invalid, 1); !errors.Is(err, ErrPetugasConstraint) {
		t.Fatalf("outbox failure: %v", err)
	}
	if count("petugas_sync_mutations") != beforeReceipts || count("petugas_sync_outbox") != beforeEvents || count("petugas") != 2 {
		t.Fatal("failed transaction left partial writes")
	}
}
