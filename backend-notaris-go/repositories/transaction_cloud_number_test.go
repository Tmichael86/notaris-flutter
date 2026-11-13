package repositories

import (
	"context"
	"errors"
	"gorm.io/gorm"
	"os"
	"sync"
	"testing"
	"time"
)

func TestTransactionCloudNumberPostgres(t *testing.T) {
	db := syncTestDB(t)
	ddl, err := os.ReadFile("../migration_proposals/20261105_transaction_cloud_numbering.sql")
	if err != nil {
		t.Fatal(err)
	}
	if err = db.Exec(string(ddl)).Error; err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if _, e := allocateTransactionNumberAt(ctx, db, "notaris", time.Now()); !errors.Is(e, ErrTransactionCloudTransactionRequired) {
		t.Fatalf("autocommit allowed: %v", e)
	}
	instant := time.Date(2026, 11, 5, 16, 59, 59, 0, time.UTC) // 23:59:59 WIB
	allocate := func(domain string, at time.Time) (string, error) {
		var n string
		err := db.Transaction(func(tx *gorm.DB) error {
			var e error
			n, e = allocateTransactionNumberAt(ctx, tx, domain, at)
			return e
		})
		return n, err
	}
	if n, e := allocate("notaris", instant); e != nil || n != "1000511260001" {
		t.Fatalf("number=%s err=%v", n, e)
	}
	if n, e := allocate("ppat", instant); e != nil || n != "2000511260001" {
		t.Fatalf("separate domain=%s err=%v", n, e)
	}
	if n, e := allocate("notaris", instant.Add(time.Second)); e != nil || n != "1000611260001" {
		t.Fatalf("Jakarta reset=%s err=%v", n, e)
	}
	aborted := errors.New("child rejected")
	err = db.Transaction(func(tx *gorm.DB) error {
		if _, e := allocateTransactionNumberAt(ctx, tx, "notaris", instant); e != nil {
			return e
		}
		return aborted
	})
	if !errors.Is(err, aborted) {
		t.Fatal(err)
	}
	if n, e := allocate("notaris", instant); e != nil || n != "1000511260002" {
		t.Fatalf("rollback consumed number=%s err=%v", n, e)
	}
	var wg sync.WaitGroup
	results := make(chan string, 12)
	failures := make(chan error, 12)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			n, e := allocate("notaris", instant)
			if e != nil {
				failures <- e
			} else {
				results <- n
			}
		}()
	}
	wg.Wait()
	close(results)
	close(failures)
	for e := range failures {
		t.Error(e)
	}
	seen := map[string]bool{}
	for n := range results {
		if seen[n] {
			t.Error("duplicate number", n)
		}
		seen[n] = true
	}
	if len(seen) != 12 {
		t.Fatal("concurrent allocations incomplete")
	}
	if err = db.Exec("UPDATE transaction_cloud_number_counter SET last_number=9999 WHERE domain='notaris' AND issue_date='2026-11-05'").Error; err != nil {
		t.Fatal(err)
	}
	if _, e := allocate("notaris", instant); !errors.Is(e, ErrTransactionNumberExhausted) {
		t.Fatalf("overflow=%v", e)
	}
	if _, e := allocate("invalid", instant); !errors.Is(e, ErrTransactionCloudReference) {
		t.Fatalf("domain=%v", e)
	}
	// Exercise the actual PostgreSQL clock path without a client-supplied date.
	if err = db.Transaction(func(tx *gorm.DB) error { _, e := allocateTransactionNumber(ctx, tx, "ppat"); return e }); err != nil {
		t.Fatal(err)
	}
}
