package repositories

import (
	"context"
	"errors"
	"gorm.io/gorm"
	"testing"
)

func TestTransactionCloudReferencesPostgres(t *testing.T) {
	db := syncTestDB(t)
	const a = "00000000-0000-4000-8000-000000000001"
	const o = "00000000-0000-4000-8000-000000000002"
	const j = "00000000-0000-4000-8000-000000000003"
	const h = "00000000-0000-4000-8000-000000000004"
	const c = "00000000-0000-4000-8000-000000000005"
	ddl := `CREATE TABLE pemohon(id bigserial PRIMARY KEY,uuid uuid,status smallint,deleted_at timestamptz);
 CREATE TABLE pekerjaan_kategori(id bigserial PRIMARY KEY,uuid uuid,status smallint,deleted_at timestamptz);`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	for _, d := range []string{"notaris", "ppat"} {
		if err := db.Exec("CREATE TABLE pekerjaan_" + d + "(id bigserial PRIMARY KEY,uuid uuid,status smallint,deleted_at timestamptz); CREATE TABLE pekerjaan_" + d + "_harga(id bigserial PRIMARY KEY,uuid uuid,pekerjaan_" + d + "_id bigint REFERENCES pekerjaan_" + d + "(id),kategori_pekerjaan_id bigint REFERENCES pekerjaan_kategori(id),status smallint,deleted_at timestamptz)").Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Transaction(func(tx *gorm.DB) error {
			if e := tx.Exec("INSERT INTO pekerjaan_"+d+"(uuid,status) VALUES(?,1)", j).Error; e != nil {
				return e
			}
			return tx.Exec("INSERT INTO pekerjaan_"+d+"_harga(uuid,pekerjaan_"+d+"_id,kategori_pekerjaan_id,status) VALUES(?,1,1,1)", h).Error
		}); err == nil {
			t.Fatal("price FK must reject missing category")
		}
		// The failed child write must roll back the parent in the same transaction.
		var n int64
		db.Table("pekerjaan_" + d).Count(&n)
		if n != 0 {
			t.Fatal("partial parent after FK error")
		}
	}
	for _, query := range []struct{ sql, value string }{{"INSERT INTO pemohon(uuid,status) VALUES(?,1)", a}, {"INSERT INTO pekerjaan_kategori(id,uuid,status) VALUES(1,?,1)", c}, {"UPDATE petugas SET uuid=? WHERE id=70", o}} {
		if err := db.Exec(query.sql, query.value).Error; err != nil {
			t.Fatal(err)
		}
	}
	for _, d := range []string{"notaris", "ppat"} {
		if err := db.Exec("INSERT INTO pekerjaan_"+d+"(id,uuid,status) VALUES(1,?,1)", j).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.Exec("INSERT INTO pekerjaan_"+d+"_harga(uuid,pekerjaan_"+d+"_id,kategori_pekerjaan_id,status) VALUES(?,1,1,1)", h).Error; err != nil {
			t.Fatal(err)
		}
	}
	input := TransactionCloudReferences{PemohonUUID: a, PetugasUUID: o, Domain: "notaris", Jobs: []TransactionCloudJobReference{{JobUUID: j, PriceUUID: h, CategoryUUID: c}}}
	if _, err := ResolveTransactionCloudReferences(context.Background(), db, input); !errors.Is(err, ErrTransactionCloudTransactionRequired) {
		t.Fatalf("autocommit allowed: %v", err)
	}
	resolve := func() error {
		return db.Transaction(func(tx *gorm.DB) error {
			r, err := ResolveTransactionCloudReferences(context.Background(), tx, input)
			if err == nil && (r.PetugasID != 70 || len(r.Jobs) != 1 || r.Jobs[0].JobID != 1) {
				t.Fatal("incorrect UUID resolution")
			}
			return err
		})
	}
	if err := resolve(); err != nil {
		t.Fatal(err)
	}
	input.Domain = "ppat"
	if err := resolve(); err != nil {
		t.Fatal(err)
	}
	input.Jobs[0].CategoryUUID = a
	if !errors.Is(resolve(), ErrTransactionCloudReference) {
		t.Fatal("wrong category accepted")
	}
	input.Jobs[0].CategoryUUID = c
	if err := db.Exec("UPDATE pekerjaan_ppat SET deleted_at=now() WHERE id=1").Error; err != nil {
		t.Fatal(err)
	}
	if !errors.Is(resolve(), ErrTransactionCloudReference) {
		t.Fatal("deleted job accepted")
	}
	input.Domain = "notaris"
	for _, table := range []string{"pekerjaan_kategori", "pekerjaan_notaris_harga"} {
		if err := db.Exec("UPDATE " + table + " SET deleted_at=now()").Error; err != nil {
			t.Fatal(err)
		}
		if !errors.Is(resolve(), ErrTransactionCloudReference) {
			t.Fatal("optional tombstone accepted", table)
		}
		if err := db.Exec("ALTER TABLE " + table + " DROP COLUMN deleted_at").Error; err != nil {
			t.Fatal(err)
		}
		if err := resolve(); err != nil {
			t.Fatalf("legacy status-only reference %s: %v", table, err)
		}
		if err := db.Exec("UPDATE " + table + " SET status=0").Error; err != nil {
			t.Fatal(err)
		}
		if !errors.Is(resolve(), ErrTransactionCloudReference) {
			t.Fatal("inactive legacy reference accepted", table)
		}
		if err := db.Exec("UPDATE " + table + " SET status=1").Error; err != nil {
			t.Fatal(err)
		}
	}
	input.Domain = "ppat"
	if err := db.Exec("ALTER TABLE pekerjaan_ppat_harga DROP COLUMN deleted_at; UPDATE pekerjaan_ppat SET deleted_at=NULL").Error; err != nil {
		t.Fatal(err)
	}
	if err := resolve(); err != nil {
		t.Fatalf("legacy PPAT status-only price: %v", err)
	}
	if err := db.Exec("UPDATE pekerjaan_ppat_harga SET status=0").Error; err != nil {
		t.Fatal(err)
	}
	if !errors.Is(resolve(), ErrTransactionCloudReference) {
		t.Fatal("inactive legacy PPAT price accepted")
	}
	input.Domain = "notaris"
	if err := db.Exec("INSERT INTO pemohon(uuid,status) VALUES(?,1)", a).Error; err != nil {
		t.Fatal(err)
	}
	if !errors.Is(resolve(), ErrTransactionCloudReference) {
		t.Fatal("ambiguous applicant accepted")
	}
	input.Domain = "notaris;DROP TABLE pemohon"
	if !errors.Is(resolve(), ErrTransactionCloudReference) {
		t.Fatal("unrecognized domain accepted")
	}
}
