package repositories

import (
	"context"
	"errors"
	"testing"
)

func TestExpectedMasterPublicationPostgres(t *testing.T) {
	db := syncTestDB(t)
	ddl := `CREATE TABLE pekerjaan_notaris_sync_publication(id smallint PRIMARY KEY,last_seq bigint NOT NULL,min_cursor bigint NOT NULL);
CREATE TABLE pekerjaan_ppat_sync_publication(id smallint PRIMARY KEY,last_seq bigint NOT NULL,min_cursor bigint NOT NULL);
INSERT INTO pekerjaan_notaris_sync_publication VALUES(1,0,0);
INSERT INTO pekerjaan_ppat_sync_publication VALUES(1,0,0);
CREATE TABLE pekerjaan_notaris_sync_outbox(id bigserial PRIMARY KEY,aggregate_uuid uuid NOT NULL,payload jsonb NOT NULL,revision bigint NOT NULL,operation text NOT NULL,publication_seq bigint UNIQUE,published_at timestamptz);
CREATE TABLE pekerjaan_ppat_sync_outbox(id bigserial PRIMARY KEY,aggregate_uuid uuid NOT NULL,payload jsonb NOT NULL,revision bigint NOT NULL,operation text NOT NULL,publication_seq bigint UNIQUE,published_at timestamptz);
INSERT INTO pekerjaan_notaris_sync_outbox(aggregate_uuid,payload,revision,operation) VALUES
('00000000-0000-4000-8000-000000000101','{"uuid":"00000000-0000-4000-8000-000000000101","nama":"N","harga":[],"proses":[]}',1,'create');`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	uuid := "00000000-0000-4000-8000-000000000101"
	if _, err := PublishExpectedMaster(ctx, db, "notaris", uuid, "update", 1); !errors.Is(err, ErrUnexpectedMasterOutbox) {
		t.Fatalf("wrong operation allowed: %v", err)
	}
	if err := db.Exec(`INSERT INTO pekerjaan_ppat_sync_outbox(aggregate_uuid,payload,revision,operation) VALUES('00000000-0000-4000-8000-000000000201','{"uuid":"00000000-0000-4000-8000-000000000201","nama":"P","harga":[],"proses":[]}',1,'create')`).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := PublishExpectedMaster(ctx, db, "notaris", uuid, "create", 1); !errors.Is(err, ErrUnexpectedMasterOutbox) {
		t.Fatalf("other domain pending allowed: %v", err)
	}
	if err := db.Exec("DELETE FROM pekerjaan_ppat_sync_outbox").Error; err != nil {
		t.Fatal(err)
	}
	seq, err := PublishExpectedMaster(ctx, db, "notaris", uuid, "create", 1)
	if err != nil || seq != 1 {
		t.Fatalf("expected event seq=%d err=%v", seq, err)
	}
	if _, err := PublishExpectedMaster(ctx, db, "notaris", uuid, "create", 1); !errors.Is(err, ErrUnexpectedMasterOutbox) {
		t.Fatalf("already published event selected again: %v", err)
	}
	var count, last int64
	if err := db.Raw("SELECT count(*) FROM pekerjaan_notaris_sync_outbox WHERE publication_seq=1").Row().Scan(&count); err != nil || count != 1 {
		t.Fatalf("published count=%d err=%v", count, err)
	}
	if err := db.Raw("SELECT last_seq FROM pekerjaan_notaris_sync_publication WHERE id=1").Row().Scan(&last); err != nil || last != 1 {
		t.Fatalf("cursor=%d err=%v", last, err)
	}
}
