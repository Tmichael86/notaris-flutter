package repositories

import (
	"context"
	"errors"
	"os"
	"testing"
)

// syncTestDB owns a random schema on an explicitly supplied disposable PG DSN.
func TestNotarisCloudCreatePublicationPostgres(t *testing.T) {
	db := syncTestDB(t)
	ddl := `CREATE TABLE pekerjaan_kategori(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris_harga(id bigserial PRIMARY KEY,pekerjaan_notaris_id bigint NOT NULL REFERENCES pekerjaan_notaris(id),kategori_pekerjaan_id bigint NOT NULL REFERENCES pekerjaan_kategori(id),harga text NOT NULL CHECK(harga<>'fail'),estimasi_waktu text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_notaris_proses(id bigserial PRIMARY KEY,pekerjaan_notaris_id bigint NOT NULL REFERENCES pekerjaan_notaris(id),nama text NOT NULL,detail text NOT NULL,status smallint NOT NULL);
INSERT INTO pekerjaan_kategori(uuid,nama,status) VALUES('00000000-0000-4000-8000-000000000011','Category',1);`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile("../migration_proposals/20261103_pekerjaan_notaris_create_sync.sql")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(migration)).Error; err != nil {
		t.Fatal(err)
	}
	r := NewNotarisCloudRepository(db)
	request := NotarisCloudCreate{
		MutationID: "00000000-0000-4000-8000-000000000101", UUID: "00000000-0000-4000-8000-000000000201", Nama: "Synthetic Notaris",
		Harga:  []NotarisCloudHarga{{UUID: "00000000-0000-4000-8000-000000000301", CategoryUUID: "00000000-0000-4000-8000-000000000011", Harga: "100000", EstimasiWaktu: "2 hari"}},
		Proses: []NotarisCloudProses{{UUID: "00000000-0000-4000-8000-000000000401", Nama: "Periksa", Detail: "Synthetic", Atribut: []NotarisCloudAtribut{{UUID: "00000000-0000-4000-8000-000000000501", Value: "KTP"}}}},
	}
	ctx := context.Background()
	ack, err := r.Create(ctx, request, 2001)
	if err != nil {
		t.Fatal(err)
	}
	replay, err := r.Create(ctx, request, 2001)
	if err != nil || *replay != *ack {
		t.Fatalf("receipt replay: %v %v", replay, err)
	}
	changed := request
	changed.Nama = "Different"
	if _, err := r.Create(ctx, changed, 2001); !errors.Is(err, ErrNotarisCloudReuse) {
		t.Fatalf("mutation reuse: %v", err)
	}
	bad := request
	bad.MutationID = "00000000-0000-4000-8000-000000000102"
	bad.UUID = "00000000-0000-4000-8000-000000000202"
	bad.Harga = []NotarisCloudHarga{{UUID: "00000000-0000-4000-8000-000000000302", CategoryUUID: "00000000-0000-4000-8000-000000000099", Harga: "100", EstimasiWaktu: "1 hari"}}
	if _, err := r.Create(ctx, bad, 2001); !errors.Is(err, ErrNotarisCloudInvalid) {
		t.Fatalf("bad reference: %v", err)
	}
	bad.MutationID = "00000000-0000-4000-8000-000000000103"
	bad.UUID = "00000000-0000-4000-8000-000000000203"
	bad.Harga[0].CategoryUUID = request.Harga[0].CategoryUUID
	bad.Harga[0].Harga = "fail"
	if _, err := r.Create(ctx, bad, 2001); err == nil {
		t.Fatal("child constraint should roll back")
	}
	for table, want := range map[string]int{"pekerjaan_notaris": 1, "pekerjaan_notaris_harga": 1, "pekerjaan_notaris_proses": 1, "pekerjaan_notaris_sync_atribut": 1, "pekerjaan_notaris_sync_mutation": 1, "pekerjaan_notaris_sync_outbox": 1} {
		var got int
		if err := db.Raw("SELECT count(*) FROM " + table).Row().Scan(&got); err != nil || got != want {
			t.Fatalf("%s count %d err %v", table, got, err)
		}
	}
	n, err := r.Publish(ctx, 2)
	if err != nil || n != 1 {
		t.Fatalf("publish %d %v", n, err)
	}
	n, err = r.Publish(ctx, 2)
	if err != nil || n != 0 {
		t.Fatalf("re-publish %d %v", n, err)
	}
	page, err := r.Pull(ctx, 0, 2)
	if err != nil || len(page.Changes) != 1 || page.NextCursor != 1 || page.Changes[0].Aggregate.Proses[0].Atribut[0].Value != "KTP" {
		t.Fatalf("pull %#v %v", page, err)
	}
	page, err = r.Pull(ctx, 1, 2)
	if err != nil || len(page.Changes) != 0 {
		t.Fatalf("replay %#v %v", page, err)
	}
}
