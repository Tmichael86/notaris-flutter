package repositories

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"backend-notaris-go/models"
	"backend-notaris-go/synccontract"
	"gorm.io/gorm"
)

func hardenPetugas(t *testing.T, db *gorm.DB) {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("..", "migrations", "20261030_02_petugas_uuid_hardening.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(b)).Error; err != nil {
		t.Fatal(err)
	}
}
func legacyTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db := publicationTestDB(t)
	hardenPetugas(t, db)
	if err := db.Exec("ALTER TABLE jenis_kelamin ADD COLUMN nama text; UPDATE jenis_kelamin SET nama = 'Test reference'").Error; err != nil {
		t.Fatal(err)
	}
	return db
}

func TestPetugasUUIDBackfillPostgres(t *testing.T) {
	db := syncTestDB(t)
	var first string
	if err := db.Raw("SELECT uuid::text FROM petugas WHERE id = 70").Row().Scan(&first); err != nil {
		t.Fatal(err)
	}
	var deterministic string
	if err := db.Raw("SELECT md5('petugas:70')::uuid::text").Row().Scan(&deterministic); err != nil {
		t.Fatal(err)
	}
	if !syncUUID.MatchString(first) || first == deterministic {
		t.Fatal("backfill is not random UUID")
	}
	other := syncTestDB(t)
	var otherUUID string
	if err := other.Raw("SELECT uuid::text FROM petugas WHERE id = 70").Row().Scan(&otherUUID); err != nil {
		t.Fatal(err)
	}
	if first == otherUUID {
		t.Fatal("same integer ID in independent schema generated same UUID")
	}
	if err := db.Exec("INSERT INTO petugas (id,nama,email,status,uuid) VALUES (71,'Existing','existing@example.com',1,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), (72,'Missing','missing@example.com',1,NULL)").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO petugas (id,nama,email,status,uuid) VALUES (73,'Previously assigned','old@example.com',1,md5('petugas:73')::uuid)").Error; err != nil {
		t.Fatal(err)
	}
	hardenPetugas(t, db)
	var before []struct {
		ID   uint
		UUID string
	}
	if err := db.Raw("SELECT id,uuid::text FROM petugas ORDER BY id").Scan(&before).Error; err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join("..", "migrations", "20261029_01_petugas_cloud_sync.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(b)).Error; err != nil {
		t.Fatal(err)
	}
	hardenPetugas(t, db)
	var after []struct {
		ID   uint
		UUID string
	}
	if err := db.Raw("SELECT id,uuid::text FROM petugas ORDER BY id").Scan(&after).Error; err != nil {
		t.Fatal(err)
	}
	if len(after) != 4 {
		t.Fatal("legacy rows changed")
	}
	for i, row := range after {
		if row != before[i] || !syncUUID.MatchString(row.UUID) {
			t.Fatal("identity changed on rerun")
		}
	}
	if after[0].UUID != first || after[1].UUID != "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" || after[2].UUID == first {
		t.Fatal("valid identity not preserved or duplicate generated")
	}
	if err := db.Exec("INSERT INTO petugas (nama,email,status,uuid) VALUES ('Duplicate','duplicate@example.com',1,?::uuid)", first).Error; err == nil {
		t.Fatal("duplicate UUID accepted")
	}
}

func TestPetugasLegacyCRUDPostgres(t *testing.T) {
	db := legacyTestDB(t)
	r := &PetugasRepository{db: db}
	ctx := context.Background()
	item := &models.Petugas{Nama: "Legacy create", Email: "legacy-create@example.com"}
	if err := r.Create(ctx, item, 1); err != nil {
		t.Fatal(err)
	}
	if item.UUID == nil || !syncUUID.MatchString(*item.UUID) || item.RowVersion != 1 {
		t.Fatalf("invalid create: %+v", item)
	}
	id, uuid := item.ID, *item.UUID
	if err := db.Exec("CREATE TABLE legacy_transaksi (id bigint PRIMARY KEY, petugas_id bigint REFERENCES petugas(id))").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO legacy_transaksi VALUES (1,?)", id).Error; err != nil {
		t.Fatal(err)
	}
	updated, err := r.Update(ctx, id, &models.Petugas{Nama: "Updated", Email: item.Email}, 1)
	if err != nil {
		t.Fatal(err)
	}
	if updated.ID != id || *updated.UUID != uuid || updated.RowVersion != 2 {
		t.Fatal("update identity or version changed")
	}
	items, total, err := r.FindActive(ctx, 1, 50)
	if err != nil || total != 2 || len(items) != 2 {
		t.Fatalf("GET list: %d %v", total, err)
	}
	if err := r.Deactivate(ctx, id, 1); err != nil {
		t.Fatal(err)
	}
	if _, err := r.FindActiveByID(ctx, id); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatal("deleted record visible")
	}
	if err := r.Deactivate(ctx, id, 1); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatal("legacy repeat DELETE must retain not found semantics")
	}
	var row models.Petugas
	if err := db.Where("id = ?", id).Take(&row).Error; err != nil {
		t.Fatal(err)
	}
	if row.RowVersion != 3 || row.DeletedAt == nil || row.Status != 0 || *row.UUID != uuid {
		t.Fatal("invalid tombstone")
	}
	var linked uint
	if err := db.Raw("SELECT petugas_id FROM legacy_transaksi WHERE id = 1").Row().Scan(&linked); err != nil || linked != id {
		t.Fatal("legacy relation broken")
	}
	pub := NewPetugasPublicationRepository(db)
	if n, err := pub.Publish(ctx, 50); err != nil || n != 3 {
		t.Fatalf("expected exactly three CRUD events: %d %v", n, err)
	}
	page := pullPublication(t, pub, 0, 50)
	if len(page.Changes) != 3 || page.Changes[0].Payload.Nama != "Legacy create" || page.Changes[1].Payload.Nama != "Updated" || !page.Changes[2].Tombstone {
		t.Fatal("CRUD history lost")
	}
}

func TestPetugasLegacyRollbackPostgres(t *testing.T) {
	db := legacyTestDB(t)
	r := &PetugasRepository{db: db}
	ctx := context.Background()
	item := &models.Petugas{Nama: "Keep", Email: "keep@example.com"}
	if err := r.Create(ctx, item, 1); err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("ALTER TABLE petugas_sync_outbox ADD CONSTRAINT reject_legacy_event CHECK (row_version < 0) NOT VALID").Error; err != nil {
		t.Fatal(err)
	}
	if err := r.Create(ctx, &models.Petugas{Nama: "Fail", Email: "fail@example.com"}, 1); err == nil {
		t.Fatal("create should fail")
	}
	if _, err := r.Update(ctx, item.ID, &models.Petugas{Nama: "Fail", Email: item.Email}, 1); err == nil {
		t.Fatal("update should fail")
	}
	if err := r.Deactivate(ctx, item.ID, 1); err == nil {
		t.Fatal("delete should fail")
	}
	current, err := r.FindActiveByID(ctx, item.ID)
	if err != nil || current.RowVersion != 1 || current.Nama != "Keep" {
		t.Fatal("failed write changed row")
	}
	var rows, events int64
	db.Table("petugas").Count(&rows)
	db.Table("petugas_sync_outbox").Count(&events)
	if rows != 2 || events != 1 {
		t.Fatalf("partial writes: rows=%d events=%d", rows, events)
	}
}

func TestPetugasLegacySyncConcurrencyPostgres(t *testing.T) {
	for _, legacyFirst := range []bool{true, false} {
		name := "sync first"
		if legacyFirst {
			name = "legacy first"
		}
		t.Run(name, func(t *testing.T) {
			db := legacyTestDB(t)
			r := &PetugasRepository{db: db}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			item := &models.Petugas{Nama: "Initial", Email: "initial@example.com"}
			if err := r.Create(ctx, item, 1); err != nil {
				t.Fatal(err)
			}
			// Hold the first write open in an outer transaction. The other repository
			// must wait on the same PostgreSQL row lock, in either ordering.
			tx := db.WithContext(ctx).Begin()
			if tx.Error != nil {
				t.Fatal(tx.Error)
			}
			defer tx.Rollback()
			m := testMutation("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
			m.PetugasUUID = *item.UUID
			v := int64(1)
			m.ExpectedRowVersion = &v
			m.Payload.Nama = "Sync"
			if legacyFirst {
				if _, err := (&PetugasRepository{db: tx}).Update(ctx, item.ID, &models.Petugas{Nama: "Legacy", Email: item.Email}, 1); err != nil {
					t.Fatal(err)
				}
			} else {
				if _, err := NewPetugasSyncRepository(tx).Apply(ctx, m, 1); err != nil {
					t.Fatal(err)
				}
			}
			done := make(chan error, 1)
			go func() {
				if legacyFirst {
					_, err := NewPetugasSyncRepository(db).Apply(ctx, m, 1)
					done <- err
				} else {
					_, err := r.Update(ctx, item.ID, &models.Petugas{Nama: "Legacy", Email: item.Email}, 1)
					done <- err
				}
			}()
			// Observe a genuine blocked query, rather than assuming goroutine timing.
			ticker := time.NewTicker(5 * time.Millisecond)
			defer ticker.Stop()
			for {
				var blocked bool
				if err := db.WithContext(ctx).Raw("SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid() AND wait_event_type = 'Lock' AND query LIKE '%petugas%')").Row().Scan(&blocked); err != nil {
					t.Fatal(err)
				}
				if blocked {
					break
				}
				select {
				case err := <-done:
					t.Fatalf("writer failed to wait: %v", err)
				case <-ctx.Done():
					t.Fatal(ctx.Err())
				case <-ticker.C:
				}
			}
			if err := tx.Commit().Error; err != nil {
				t.Fatal(err)
			}
			err := <-done
			var conflict *PetugasVersionConflict
			if legacyFirst {
				if !errors.As(err, &conflict) || conflict.Current.RowVersion != 2 {
					t.Fatalf("stale sync did not conflict: %v", err)
				}
			} else if err != nil {
				t.Fatal(err)
			}
			current, err := r.FindActiveByID(ctx, item.ID)
			if err != nil {
				t.Fatal(err)
			}
			want := int64(3)
			if legacyFirst {
				want = 2
			}
			if current.RowVersion != want || current.Nama != "Legacy" || *current.UUID != *item.UUID {
				t.Fatal("serialized identity/version incorrect")
			}
			pub := NewPetugasPublicationRepository(db)
			if n, err := pub.Publish(ctx, 50); err != nil || int64(n) != want {
				t.Fatalf("lost/duplicate event: %d %v", n, err)
			}
			page, err := pub.Pull(ctx, synccontract.PetugasPullRequest{Limit: 50})
			if err != nil {
				t.Fatal(err)
			}
			for i, event := range page.Changes {
				if event.RowVersion != int64(i+1) {
					t.Fatal("version history inconsistent")
				}
			}
			if !legacyFirst && page.Changes[1].Payload.Nama != "Sync" {
				t.Fatal("sync write lost from history")
			}
		})
	}
}
