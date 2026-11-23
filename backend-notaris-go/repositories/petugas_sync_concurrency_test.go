package repositories

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"backend-notaris-go/synccontract"
)

func TestPetugasConcurrentCreatePostgres(t *testing.T) {
	for _, sameMutation := range []bool{true, false} {
		name := "different mutations"
		if sameMutation {
			name = "same mutation"
		}
		t.Run(name, func(t *testing.T) {
			db := syncTestDB(t)
			r := NewPetugasSyncRepository(db)
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			m := testMutation("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
			type result struct {
				ack *synccontract.PetugasAcknowledgement
				err error
			}
			results := make(chan result, 2)
			start := make(chan struct{})
			var wg sync.WaitGroup
			for i := 0; i < 2; i++ {
				request := m
				if !sameMutation && i == 1 {
					request.MutationID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
				}
				wg.Add(1)
				go func(request synccontract.PetugasMutation) {
					defer wg.Done()
					<-start
					ack, err := r.Apply(ctx, request, 1)
					results <- result{ack, err}
				}(request)
			}
			close(start)
			wg.Wait()
			close(results)
			wins, conflicts := 0, 0
			var first *synccontract.PetugasAcknowledgement
			for res := range results {
				var conflict *PetugasVersionConflict
				if res.err == nil {
					wins++
					if first != nil && *first != *res.ack {
						t.Fatal("retry receipts differ")
					}
					first = res.ack
				} else if errors.As(res.err, &conflict) {
					conflicts++
				} else {
					t.Fatal(res.err)
				}
			}
			if sameMutation && (wins != 2 || conflicts != 0) || !sameMutation && (wins != 1 || conflicts != 1) {
				t.Fatalf("wins=%d conflicts=%d", wins, conflicts)
			}
			for _, table := range []string{"petugas_sync_outbox", "petugas_sync_mutations"} {
				var count int64
				if err := db.Table(table).Count(&count).Error; err != nil {
					t.Fatal(err)
				}
				if count != 1 {
					t.Fatalf("%s has %d rows", table, count)
				}
			}
		})
	}
}
