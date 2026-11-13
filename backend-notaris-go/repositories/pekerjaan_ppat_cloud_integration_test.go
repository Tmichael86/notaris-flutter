package repositories

import (
	"context"
	"errors"
	"os"
	"sync"
	"testing"
)

// syncTestDB owns a random schema on an explicitly supplied disposable PG DSN.
func TestPpatCloudCreatePublicationPostgres(t *testing.T) {
	db := syncTestDB(t)
	ddl := `CREATE TABLE pekerjaan_kategori(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE,nama text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat_harga(id bigserial PRIMARY KEY,pekerjaan_ppat_id bigint NOT NULL REFERENCES pekerjaan_ppat(id),kategori_pekerjaan_id bigint NOT NULL REFERENCES pekerjaan_kategori(id),harga text NOT NULL CHECK(harga<>'fail'),estimasi_waktu text NOT NULL,status smallint NOT NULL);
CREATE TABLE pekerjaan_ppat_proses(id bigserial PRIMARY KEY,pekerjaan_ppat_id bigint NOT NULL REFERENCES pekerjaan_ppat(id),nama text NOT NULL,detail text NOT NULL,status smallint NOT NULL);
INSERT INTO pekerjaan_kategori(uuid,nama,status) VALUES('00000000-0000-4000-8000-000000000011','Category',1);`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile("../migration_proposals/20261103_pekerjaan_ppat_aggregate_sync.sql")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(migration)).Error; err != nil {
		t.Fatal(err)
	}
	r := NewPpatCloudRepository(db)
	request := PpatCloudCreate{
		MutationID: "00000000-0000-4000-8000-000000000101", UUID: "00000000-0000-4000-8000-000000000201", Nama: "Synthetic Ppat",
		Harga:  []PpatCloudHarga{{UUID: "00000000-0000-4000-8000-000000000301", CategoryUUID: "00000000-0000-4000-8000-000000000011", Harga: "100000", EstimasiWaktu: "2 hari"}},
		Proses: []PpatCloudProses{{UUID: "00000000-0000-4000-8000-000000000401", Nama: "Periksa", Detail: "Synthetic", Atribut: []PpatCloudAtribut{{UUID: "00000000-0000-4000-8000-000000000501", Value: "KTP"}}}},
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
	if _, err := r.Create(ctx, changed, 2001); !errors.Is(err, ErrPpatCloudReuse) {
		t.Fatalf("mutation reuse: %v", err)
	}
	bad := request
	bad.MutationID = "00000000-0000-4000-8000-000000000102"
	bad.UUID = "00000000-0000-4000-8000-000000000202"
	bad.Harga = []PpatCloudHarga{{UUID: "00000000-0000-4000-8000-000000000302", CategoryUUID: "00000000-0000-4000-8000-000000000099", Harga: "100", EstimasiWaktu: "1 hari"}}
	if _, err := r.Create(ctx, bad, 2001); !errors.Is(err, ErrPpatCloudInvalid) {
		t.Fatalf("bad reference: %v", err)
	}
	bad.MutationID = "00000000-0000-4000-8000-000000000103"
	bad.UUID = "00000000-0000-4000-8000-000000000203"
	bad.Harga[0].CategoryUUID = request.Harga[0].CategoryUUID
	bad.Harga[0].Harga = "fail"
	if _, err := r.Create(ctx, bad, 2001); err == nil {
		t.Fatal("child constraint should roll back")
	}
	for table, want := range map[string]int{"pekerjaan_ppat": 1, "pekerjaan_ppat_harga": 1, "pekerjaan_ppat_proses": 1, "pekerjaan_ppat_sync_atribut": 1, "pekerjaan_ppat_sync_mutation": 1, "pekerjaan_ppat_sync_outbox": 1} {
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
	firstUpdate := PpatCloudUpdate{PpatCloudCreate: request, ExpectedRevision: 1}
	firstUpdate.MutationID = "00000000-0000-4000-8000-000000000601"
	firstUpdate.Nama = "First update"
	secondUpdate := PpatCloudUpdate{PpatCloudCreate: request, ExpectedRevision: 1}
	secondUpdate.MutationID = "00000000-0000-4000-8000-000000000602"
	secondUpdate.Nama = "Second update"
	start := make(chan struct{})
	results := make(chan error, 2)
	var workers sync.WaitGroup
	for _, update := range []PpatCloudUpdate{firstUpdate, secondUpdate} {
		workers.Add(1)
		go func(m PpatCloudUpdate) {
			defer workers.Done()
			<-start
			_, err := r.Update(ctx, m, 2001)
			results <- err
		}(update)
	}
	close(start)
	workers.Wait()
	close(results)
	successes, conflicts := 0, 0
	for result := range results {
		switch {
		case result == nil:
			successes++
		case errors.Is(result, ErrPpatCloudRevision):
			conflicts++
		default:
			t.Fatalf("unexpected concurrent result: %v", result)
		}
	}
	if successes != 1 || conflicts != 1 {
		t.Fatalf("concurrent updates success=%d conflicts=%d", successes, conflicts)
	}
	var revision, outbox int
	if err := db.Raw("SELECT row_version FROM pekerjaan_ppat WHERE uuid=?::uuid", request.UUID).Row().Scan(&revision); err != nil || revision != 2 {
		t.Fatalf("revision=%d err=%v", revision, err)
	}
	if err := db.Raw("SELECT count(*) FROM pekerjaan_ppat_sync_outbox").Row().Scan(&outbox); err != nil || outbox != 2 {
		t.Fatalf("outbox=%d err=%v", outbox, err)
	}
}
