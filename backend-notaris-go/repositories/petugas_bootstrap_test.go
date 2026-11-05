package repositories

import (
	"backend-notaris-go/models"
	"context"
	"testing"
	"time"
)

func TestPetugasBootstrapConcurrentPostgres(t *testing.T) {
	for _, seedFirst := range []bool{true, false} {
		name := "writer_first"
		if seedFirst {
			name = "bootstrap_first"
		}
		t.Run(name, func(t *testing.T) {
			db := legacyTestDB(t)
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			tx := db.WithContext(ctx).Begin()
			defer tx.Rollback()
			update := func(r *PetugasRepository) error {
				_, err := r.Update(ctx, 70, &models.Petugas{Nama: "After seed", Email: "legacy@example.com"}, 1)
				return err
			}
			if seedFirst {
				if n, err := NewPetugasPublicationRepository(tx).Bootstrap(ctx); err != nil || n != 1 {
					t.Fatalf("seed: %d %v", n, err)
				}
			} else {
				if err := update(&PetugasRepository{db: tx}); err != nil {
					t.Fatal(err)
				}
			}
			done := make(chan error, 1)
			go func() {
				if seedFirst {
					done <- update(&PetugasRepository{db: db})
				} else {
					_, err := NewPetugasPublicationRepository(db).Bootstrap(ctx)
					done <- err
				}
			}()
			ticker := time.NewTicker(5 * time.Millisecond)
			defer ticker.Stop()
			for {
				var waiting bool
				if err := db.WithContext(ctx).Raw("SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE pid<>pg_backend_pid() AND datname=current_database() AND wait_event_type='Lock' AND query LIKE '%petugas%')").Row().Scan(&waiting); err != nil {
					t.Fatal(err)
				}
				if waiting {
					break
				}
				select {
				case err := <-done:
					t.Fatalf("expected lock wait: %v", err)
				case <-ctx.Done():
					t.Fatal(ctx.Err())
				case <-ticker.C:
				}
			}
			if err := tx.Commit().Error; err != nil {
				t.Fatal(err)
			}
			if err := <-done; err != nil {
				t.Fatal(err)
			}
			pub := NewPetugasPublicationRepository(db)
			if n, err := pub.Bootstrap(ctx); err != nil || n != 0 {
				t.Fatalf("seed retry: %d %v", n, err)
			}
			if _, err := pub.Publish(ctx, 50); err != nil {
				t.Fatal(err)
			}
			page := pullPublication(t, pub, 0, 50)
			want := 1
			if seedFirst {
				want = 2
			}
			if len(page.Changes) != want || page.Changes[want-1].Payload.Nama != "After seed" || page.Changes[want-1].RowVersion != 2 {
				t.Fatal("concurrent baseline skipped/replaced update")
			}
			if err := (&PetugasRepository{db: db}).Deactivate(ctx, 70, 1); err != nil {
				t.Fatal(err)
			}
			if n, err := pub.Bootstrap(ctx); err != nil || n != 0 {
				t.Fatal("duplicated deletion")
			}
			if _, err := pub.Publish(ctx, 50); err != nil {
				t.Fatal(err)
			}
			page = pullPublication(t, pub, page.NextCursor, 50)
			if len(page.Changes) != 1 || !page.Changes[0].Tombstone {
				t.Fatal("deletion lost")
			}
		})
	}
}
