package repositories

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"backend-notaris-go/models"
	"backend-notaris-go/synccontract"
	"gorm.io/gorm"
)

func publicationTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db := syncTestDB(t)
	migration, err := os.ReadFile(filepath.Join("..", "migrations", "20261030_01_petugas_publication.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(string(migration)).Error; err != nil {
		t.Fatal(err)
	}
	return db
}

func insertPublicationEvent(t *testing.T, tx *gorm.DB, name string, version int64, deleted bool) int64 {
	t.Helper()
	uuid := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	row := models.Petugas{ID: 71, UUID: &uuid, Nama: name, RowVersion: version, Status: 1}
	if deleted {
		row.Status = 0
	}
	payload, err := json.Marshal(row)
	if err != nil {
		t.Fatal(err)
	}
	var id int64
	if err := tx.Raw("INSERT INTO petugas_sync_outbox (petugas_uuid,row_version,tombstone,payload) VALUES (?::uuid,?,?,?::jsonb) RETURNING id", uuid, version, deleted, string(payload)).Row().Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

func pullPublication(t *testing.T, r *PetugasPublicationRepository, cursor int64, limit int) *PetugasPullPage {
	t.Helper()
	page, err := r.Pull(context.Background(), synccontract.PetugasPullRequest{Cursor: cursor, Limit: limit})
	if err != nil {
		t.Fatal(err)
	}
	return page
}

func TestPetugasPublicationCommitOrderPostgres(t *testing.T) {
	db := publicationTestDB(t)
	r := NewPetugasPublicationRepository(db)
	ctx := context.Background()
	a := db.Begin()
	if a.Error != nil {
		t.Fatal(a.Error)
	}
	defer a.Rollback()
	idA := insertPublicationEvent(t, a, "A allocated first, committed later", 1, false)
	idB := insertPublicationEvent(t, db, "B committed first", 1, false)
	if idA >= idB {
		t.Fatal("fixture did not allocate A first")
	}
	if n, err := r.Publish(ctx, 10); err != nil || n != 1 {
		t.Fatalf("committed B only: %d %v", n, err)
	}
	page := pullPublication(t, r, 0, 10)
	if len(page.Changes) != 1 || page.Changes[0].Payload.Nama != "B committed first" || page.NextCursor != 1 {
		t.Fatalf("uncommitted A leaked: %+v", page)
	}
	if err := a.Commit().Error; err != nil {
		t.Fatal(err)
	}
	if n, err := r.Publish(ctx, 10); err != nil || n != 1 {
		t.Fatalf("late A publication: %d %v", n, err)
	}
	page = pullPublication(t, r, page.NextCursor, 10)
	if len(page.Changes) != 1 || page.Changes[0].Payload.Nama != "A allocated first, committed later" || page.NextCursor != 2 {
		t.Fatal("late commit skipped")
	}
	insertPublicationEvent(t, db, "deleted", 2, true)
	if _, err := r.Publish(ctx, 10); err != nil {
		t.Fatal(err)
	}
	first := pullPublication(t, r, 0, 1)
	if !first.HasMore || first.NextCursor != 1 {
		t.Fatal("first page bounds")
	}
	replay := pullPublication(t, r, 0, 1)
	if !reflect.DeepEqual(first, replay) {
		t.Fatal("same cursor changed historical result")
	}
	second := pullPublication(t, r, first.NextCursor, 1)
	third := pullPublication(t, r, second.NextCursor, 1)
	if !second.HasMore || third.HasMore || third.NextCursor != 3 || !third.Changes[0].Tombstone || third.Changes[0].Payload != nil {
		t.Fatal("pagination/tombstone lost")
	}
	empty := pullPublication(t, r, 3, 1)
	if empty.NextCursor != 3 || empty.HasMore || len(empty.Changes) != 0 {
		t.Fatal("empty cursor advanced")
	}
	if n, err := r.Publish(ctx, 10); err != nil || n != 0 {
		t.Fatalf("duplicate publication on retry: %d %v", n, err)
	}
	for _, request := range []synccontract.PetugasPullRequest{{Cursor: -1, Limit: 1}, {Cursor: 4, Limit: 1}, {Limit: 0}, {Limit: 501}} {
		if _, err := r.Pull(ctx, request); !errors.Is(err, ErrPetugasPull) {
			t.Fatalf("invalid pagination accepted: %v", err)
		}
	}
	if err := db.Exec("UPDATE petugas_sync_publication SET min_cursor = 1 WHERE id = 1").Error; err != nil {
		t.Fatal(err)
	}
	if _, err := r.Pull(ctx, synccontract.PetugasPullRequest{Limit: 1}); !errors.Is(err, ErrPetugasCursorExpired) {
		t.Fatalf("retention bounds: %v", err)
	}
}

func TestPetugasPublisherRollbackAndSerializationPostgres(t *testing.T) {
	db := publicationTestDB(t)
	r := NewPetugasPublicationRepository(db)
	insertPublicationEvent(t, db, "first", 1, false)
	insertPublicationEvent(t, db, "second", 2, false)
	// Simulate connection loss/crash after all UPDATEs but before COMMIT.
	crash := db.Begin()
	defer crash.Rollback()
	if n, err := publishPetugasBatch(crash, 1); err != nil || n != 1 {
		t.Fatalf("crash fixture: %d %v", n, err)
	}
	if page := pullPublication(t, r, 0, 10); len(page.Changes) != 0 {
		t.Fatal("uncommitted publication visible")
	}
	if err := crash.Rollback().Error; err != nil {
		t.Fatal(err)
	}
	a := db.Begin()
	defer a.Rollback()
	if n, err := publishPetugasBatch(a, 1); err != nil || n != 1 {
		t.Fatalf("publisher A: %d %v", n, err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pidChan := make(chan int, 1)
	done := make(chan error, 1)
	go func() {
		b := db.WithContext(ctx).Begin()
		if b.Error != nil {
			done <- b.Error
			return
		}
		defer b.Rollback()
		var pid int
		if err := b.Raw("SELECT pg_backend_pid()").Row().Scan(&pid); err != nil {
			done <- err
			return
		}
		pidChan <- pid
		n, err := publishPetugasBatch(b, 1)
		if err == nil && n != 1 {
			err = errors.New("publisher B did not publish remaining event")
		}
		if err == nil {
			err = b.Commit().Error
		}
		done <- err
	}()
	var pid int
	select {
	case pid = <-pidChan:
	case err := <-done:
		t.Fatalf("publisher startup: %v", err)
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
	// Observe PostgreSQL blocking the second publisher on a real lock. This
	// proves it cannot commit sequence 2 while A's sequence 1 is uncommitted.
	ticker := time.NewTicker(5 * time.Millisecond)
	defer ticker.Stop()
	waiting := false
	for !waiting {
		var locked bool
		if err := db.WithContext(ctx).Raw("SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE pid = ? AND wait_event_type = 'Lock')", pid).Row().Scan(&locked); err != nil {
			t.Fatal(err)
		}
		waiting = locked
		if !waiting {
			select {
			case err := <-done:
				t.Fatalf("publisher B bypassed counter lock: %v", err)
			case <-ctx.Done():
				t.Fatal(ctx.Err())
			case <-ticker.C:
			}
		}
	}
	if page := pullPublication(t, r, 0, 10); len(page.Changes) != 0 {
		t.Fatal("A leaked before commit")
	}
	if err := a.Commit().Error; err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
	page := pullPublication(t, r, 0, 10)
	if len(page.Changes) != 2 || page.Changes[0].PublicationSequence != 1 || page.Changes[1].PublicationSequence != 2 {
		t.Fatalf("rollback/serialization sequence mismatch: %+v", page)
	}
	if n, err := r.Publish(ctx, 10); err != nil || n != 0 {
		t.Fatalf("post-commit retry: %d %v", n, err)
	}
}

func TestPetugasHistoricalPullPostgres(t *testing.T) {
	db := publicationTestDB(t)
	mutations := NewPetugasSyncRepository(db)
	r := NewPetugasPublicationRepository(db)
	ctx := context.Background()
	m := testMutation("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
	if _, err := mutations.Apply(ctx, m, 1); err != nil {
		t.Fatal(err)
	}
	version := int64(1)
	m.ExpectedRowVersion = &version
	m.MutationID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
	m.Payload.Nama = "Changed later"
	if _, err := mutations.Apply(ctx, m, 1); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Publish(ctx, 10); err != nil {
		t.Fatal(err)
	}
	page := pullPublication(t, r, 0, 10)
	if len(page.Changes) != 2 || page.Changes[0].RowVersion != 1 || page.Changes[0].Payload.Nama != "Sari" || page.Changes[1].RowVersion != 2 || page.Changes[1].Payload.Nama != "Changed later" {
		t.Fatal("historical version replaced with latest state")
	}
}
