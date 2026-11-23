package petugasops

import (
	"backend-notaris-go/repositories"
	"backend-notaris-go/synccontract"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestRequestGuards(t *testing.T) {
	good := Baseline{AppRole: "ops_app", PetugasHash: strings.Repeat("a", 32), UUIDHash: strings.Repeat("b", 32), TransactionHash: strings.Repeat("c", 32), DetailHash: strings.Repeat("d", 32), PaymentHash: strings.Repeat("e", 32)}
	if err := good.Validate(); err != nil {
		t.Fatal(err)
	}
	for _, role := range []string{"", "postgres", "bad role", "user';SELECT"} {
		b := good
		b.AppRole = role
		if b.Validate() == nil {
			t.Fatal("unsafe role accepted")
		}
	}
	b := good
	b.UUIDHash = ""
	if b.Validate() == nil {
		t.Fatal("missing UUID baseline accepted")
	}
	for _, o := range []Options{{Operation: "reset", BatchSize: 1, MaxBatches: 1}, {Operation: "drain", BatchSize: 0, MaxBatches: 1}, {Operation: "drain", BatchSize: 501, MaxBatches: 1}, {Operation: "drain", BatchSize: 1, MaxBatches: 0}, {Operation: "drain", BatchSize: 1, MaxBatches: 101}, {Operation: "bootstrap", BatchSize: 1, MaxBatches: 1, Apply: true, RequirePublishedBaseline: true}} {
		if o.Validate() == nil {
			t.Fatal("invalid options accepted")
		}
	}
}

func TestDevelopmentOperationsPostgres(t *testing.T) {
	dsn := os.Getenv("NOTARIS_OPS_TEST_DSN")
	if dsn == "" {
		t.Skip("owned disposable operations DSN unset")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil || cfg.Host != "127.0.0.1" || cfg.Port != 55445 || cfg.Database != "notarisdev" || cfg.User != "notaris_test" {
		t.Fatal("unsafe disposable operations target")
	}
	admin := func(query string) {
		t.Helper()
		pool := stdlib.OpenDB(*cfg)
		defer pool.Close()
		if _, err := pool.Exec(query); err != nil {
			t.Fatal(err)
		}
	}
	// The harness creates only an empty owned database. No restore/production .env.
	admin(`CREATE TABLE konfigurasi_umum(id bigint PRIMARY KEY,notaris_bersangkutan text);
INSERT INTO konfigurasi_umum VALUES(1,'NOTARISDEV SYNTHETIC v1');
CREATE TABLE jenis_kelamin(id integer PRIMARY KEY,status smallint);
CREATE TABLE users(id integer PRIMARY KEY,status smallint);
INSERT INTO jenis_kelamin VALUES(11,1),(29,1); INSERT INTO users VALUES(2001,1);
CREATE TABLE petugas(id bigserial PRIMARY KEY,nik varchar,nama varchar NOT NULL,alamat varchar,
 tempat_lahir varchar,tanggal_lahir date,jenis_kelamin integer,no_telp varchar,email varchar NOT NULL,
 user_id integer,created_by integer,updated_by integer,created_at timestamp,updated_at timestamp,status smallint NOT NULL);
INSERT INTO petugas(id,nama,email,jenis_kelamin,user_id,status) SELECT i,'Synthetic '||i,'fixture'||i||'@example.invalid',11,2001,1 FROM generate_series(101,104)i;
CREATE TABLE transaksi(id bigint PRIMARY KEY,petugas_id bigint,note text);
CREATE TABLE transaksi_detail_proses(id bigint PRIMARY KEY,transaksi_id bigint,note text);
CREATE TABLE transaksi_riwayat_pembayaran(id bigint PRIMARY KEY,transaksi_id bigint,note text);
INSERT INTO transaksi SELECT i,i-400,'Synthetic transaction' FROM generate_series(501,504)i;
INSERT INTO transaksi_detail_proses SELECT i,i-100,'Synthetic detail' FROM generate_series(601,604)i;
INSERT INTO transaksi_riwayat_pembayaran SELECT i,i-200,'Synthetic payment' FROM generate_series(701,704)i;`)
	for _, name := range []string{"20261029_01_petugas_cloud_sync.sql", "20261030_01_petugas_publication.sql", "20261030_02_petugas_uuid_hardening.sql"} {
		b, err := os.ReadFile(filepath.Join("..", "..", "migrations", name))
		if err != nil {
			t.Fatal(err)
		}
		admin(string(b))
	}
	admin(`CREATE ROLE ops_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
GRANT CONNECT ON DATABASE notarisdev TO ops_app; GRANT USAGE ON SCHEMA public TO ops_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON konfigurasi_umum,jenis_kelamin,users,petugas,transaksi,transaksi_detail_proses,transaksi_riwayat_pembayaran TO ops_app;
GRANT SELECT,USAGE,UPDATE ON SEQUENCE petugas_id_seq TO ops_app;
GRANT SELECT,INSERT ON petugas_sync_mutations TO ops_app;
GRANT SELECT,INSERT,UPDATE ON petugas_sync_outbox TO ops_app;
GRANT SELECT,UPDATE ON petugas_sync_publication TO ops_app;
GRANT SELECT,USAGE ON SEQUENCE petugas_sync_outbox_id_seq TO ops_app;`)
	app := cfg.Copy()
	app.User = "ops_app"
	app.RuntimeParams = map[string]string{"search_path": "public,pg_catalog", "timezone": "UTC", "statement_timeout": "10000", "lock_timeout": "1000"}
	pool := stdlib.OpenDB(*app)
	defer pool.Close()
	pool.SetMaxOpenConns(1)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	var baseline Baseline
	if err = db.Raw(`SELECT current_user AS app_role,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p)-ARRAY['uuid','row_version','deleted_at'] ORDER BY id)::text,'[]')) FROM petugas p) AS petugas_hash,
 (SELECT md5(string_agg(id::text||':'||uuid::text,',' ORDER BY id)) FROM petugas) AS uuid_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]')) FROM transaksi t) AS transaction_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM transaksi_detail_proses d) AS detail_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM transaksi_riwayat_pembayaran p) AS payment_hash`).Scan(&baseline).Error; err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	options := Options{Operation: "bootstrap-and-drain", BatchSize: 1, MaxBatches: 10}
	call := func(o Options) (State, error) { return run(ctx, db, baseline, o, 55445, nil) }
	if _, err = Run(ctx, db, baseline, options, nil); err == nil {
		t.Fatal("public runner accepted disposable port")
	}
	before, err := legacySnapshot(db)
	if err != nil {
		t.Fatal(err)
	}
	s, err := call(options)
	if err != nil || s.Outbox != 0 || s.SequenceCalled {
		t.Fatalf("initial read-only preflight: %+v %v", s, err)
	}
	gate := options
	gate.RequirePublishedBaseline = true
	if _, err = call(gate); err == nil {
		t.Fatal("worker gate accepted unbootstrapped database")
	}
	// Each rejected preflight is read-only; fixture changes are made by the
	// test administrator, then explicitly reversed only in this owned cluster.
	for _, test := range []struct{ name, change, undo string }{
		{"identity", "UPDATE konfigurasi_umum SET notaris_bersangkutan='wrong'", "UPDATE konfigurasi_umum SET notaris_bersangkutan='NOTARISDEV SYNTHETIC v1'"},
		{"legacy_data", "UPDATE transaksi_detail_proses SET note='changed' WHERE id=601", "UPDATE transaksi_detail_proses SET note='Synthetic detail' WHERE id=601"},
		{"counter", "UPDATE petugas_sync_publication SET last_seq=1", "UPDATE petugas_sync_publication SET last_seq=0"},
		{"excess_grants", "GRANT DELETE ON petugas_sync_outbox TO ops_app", "REVOKE DELETE ON petugas_sync_outbox FROM ops_app"},
		{"missing_grants", "REVOKE INSERT ON petugas_sync_outbox FROM ops_app", "GRANT INSERT ON petugas_sync_outbox TO ops_app"},
		{"missing_index", "DROP INDEX petugas_sync_outbox_unpublished_idx", "CREATE INDEX petugas_sync_outbox_unpublished_idx ON petugas_sync_outbox(id) WHERE publication_seq IS NULL"},
		{"ddl_privilege", "GRANT CREATE ON SCHEMA public TO ops_app", "REVOKE CREATE ON SCHEMA public FROM ops_app"},
	} {
		t.Run(test.name, func(t *testing.T) {
			admin(test.change)
			defer admin(test.undo)
			if _, err := call(options); err == nil {
				t.Fatal("unsafe preflight accepted")
			}
		})
	}
	t.Run("maintenance", func(t *testing.T) {
		other := stdlib.OpenDB(*cfg)
		defer other.Close()
		if err := other.Ping(); err != nil {
			t.Fatal(err)
		}
		if _, err := call(options); err == nil {
			t.Fatal("active client accepted")
		}
	})
	t.Run("runner_lock", func(t *testing.T) {
		other := stdlib.OpenDB(*app)
		defer other.Close()
		conn, err := other.Conn(ctx)
		if err != nil {
			t.Fatal(err)
		}
		defer conn.Close()
		if _, err = conn.ExecContext(ctx, "SELECT pg_advisory_lock(7281946103101)"); err != nil {
			t.Fatal(err)
		}
		defer conn.ExecContext(context.Background(), "SELECT pg_advisory_unlock(7281946103101)")
		o := options
		o.Apply = true
		if _, err = call(o); err == nil || !strings.Contains(err.Error(), "maintenance lock") {
			t.Fatalf("concurrent runner not rejected: %v", err)
		}
	})
	// A failed transaction can consume IDs without committed outbox rows. This
	// is deliberately allocated only in the disposable fixture, never reset.
	admin("BEGIN; SELECT nextval('petugas_sync_outbox_id_seq'); ROLLBACK;")
	options.Apply = true
	crashCtx, crash := context.WithCancel(ctx)
	bootCommitted := false
	_, err = run(crashCtx, db, baseline, options, 55445, func(e Event) {
		if e.Stage == "bootstrap_committed" {
			bootCommitted = true
			crash()
		}
	})
	crash()
	if !bootCommitted {
		t.Fatalf("bootstrap failed before cancellation: %v", err)
	}
	if err == nil {
		t.Fatal("interrupted process unexpectedly completed")
	}
	dry := options
	dry.Apply = false
	s, err = call(dry)
	if err != nil || s.Outbox != 4 || s.Pending != 4 || s.LastSeq != 0 {
		t.Fatalf("bootstrap commit not recoverable: %+v %v", s, err)
	}
	boot := options
	boot.Operation = "bootstrap"
	var count int
	_, err = run(ctx, db, baseline, boot, 55445, func(e Event) {
		if e.Stage == "bootstrap_committed" {
			count = e.Count
		}
	})
	if err != nil || count != 0 {
		t.Fatalf("bootstrap retry duplicated baseline: %d %v", count, err)
	}
	// Abort after exactly one committed publication batch, then reconnect/retry.
	partial := options
	partial.Operation = "drain"
	partial.MaxBatches = 1
	s, err = call(partial)
	if err == nil || s.LastSeq != 1 || s.Pending != 3 {
		t.Fatalf("bounded partial publication: %+v %v", s, err)
	}
	s, err = call(options)
	if err != nil || !s.Ready() || s.SequenceLast != 5 {
		t.Fatalf("resume/drain/pull failed: %+v %v", s, err)
	}
	stable, _ := json.Marshal(s)
	retry, err := call(options)
	again, _ := json.Marshal(retry)
	if err != nil || string(stable) != string(again) {
		t.Fatalf("completed retry changed durable state: %+v %v", retry, err)
	}
	if _, err = call(gate); err != nil {
		t.Fatalf("published worker gate failed: %v", err)
	}
	// Reject unexpected rows, duplicate or corrupted snapshots and reset cursors.
	for _, test := range []struct{ name, change, undo string }{
		{"payload", "UPDATE petugas_sync_outbox SET payload=jsonb_set(payload,'{nama}','\"corrupt\"') WHERE petugas_uuid=(SELECT uuid FROM petugas WHERE id=101)", "UPDATE petugas_sync_outbox SET payload=jsonb_set(payload,'{nama}','\"Synthetic 101\"') WHERE petugas_uuid=(SELECT uuid FROM petugas WHERE id=101)"},
		{"retention", "UPDATE petugas_sync_publication SET min_cursor=1", "UPDATE petugas_sync_publication SET min_cursor=0"},
	} {
		t.Run(test.name, func(t *testing.T) {
			admin(test.change)
			defer admin(test.undo)
			if _, err := call(dry); err == nil {
				t.Fatal("corrupt resumed state accepted")
			}
		})
	}
	after, err := legacySnapshot(db)
	if err != nil {
		t.Fatal(err)
	}
	if len(before) != len(after) {
		t.Fatal("legacy schema changed")
	}
	for name, hash := range before {
		if after[name] != hash {
			t.Fatalf("legacy identity/data/sequence changed: %s", name)
		}
	}
	t.Run("worker_restart_after_crud", func(t *testing.T) {
		var uuid string
		if err := db.Raw("SELECT uuid::text FROM petugas WHERE id=101").Scan(&uuid).Error; err != nil {
			t.Fatal(err)
		}
		v := int64(1)
		_, err := repositories.NewPetugasSyncRepository(db).Apply(ctx, synccontract.PetugasMutation{MutationID: "df000000-0000-4000-8000-000000000099", PetugasUUID: uuid, Operation: synccontract.PetugasUpsert, ExpectedRowVersion: &v, Payload: &synccontract.PetugasPayload{Nama: "Legitimate later CRUD", Email: "updated@example.invalid"}}, 2001)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := call(gate); err != nil {
			t.Fatalf("pending legitimate CRUD blocks worker startup: %v", err)
		}
		if _, err := call(dry); err == nil {
			t.Fatal("initial rollout runner accepted changed live data")
		}
		if _, err := repositories.NewPetugasPublicationRepository(db).Publish(ctx, 10); err != nil {
			t.Fatal(err)
		}
		s, err := call(gate)
		if err != nil || s.LastSeq != 5 || s.Pending != 0 {
			t.Fatalf("worker restart after publication failed: %+v %v", s, err)
		}
	})
}
