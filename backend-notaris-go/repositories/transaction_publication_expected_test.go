package repositories

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"
)

func TestTransactionExpectedPublicationPostgres(t *testing.T) {
	db := syncTestDB(t)
	ddl := `CREATE TABLE transaction_cloud(uuid uuid PRIMARY KEY,domain text NOT NULL);
 CREATE TABLE transaction_cloud_publication(id integer PRIMARY KEY,last_seq bigint NOT NULL,min_cursor bigint NOT NULL);INSERT INTO transaction_cloud_publication VALUES(1,0,0);
 CREATE TABLE transaction_cloud_outbox(id bigserial PRIMARY KEY,aggregate_uuid uuid REFERENCES transaction_cloud(uuid),revision bigint NOT NULL,operation text NOT NULL,payload jsonb NOT NULL,publication_seq bigint UNIQUE,published_at timestamptz,UNIQUE(aggregate_uuid,revision));`
	if err := db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	const uuid = "00000000-0000-4000-8000-000000000101"
	aggregate := TransactionCloudAggregate{FinalNumber: "1000611260001", TransactionCloudCreate: TransactionCloudCreate{Domain: "notaris", UUID: uuid, MutationID: "00000000-0000-4000-8000-000000000102", Header: TransactionCloudHeader{Date: time.Now().UTC(), Status: "Baru", Method: "Cash", Total: 100}, Details: []TransactionCloudDetail{{UUID: "00000000-0000-4000-8000-000000000103", Name: "Synthetic", ServiceCost: 100, Total: 100}}}}
	aggregate.PemohonUUID = "00000000-0000-4000-8000-000000000201"
	aggregate.PetugasUUID = "00000000-0000-4000-8000-000000000202"
	aggregate.Details[0].JobUUID = "00000000-0000-4000-8000-000000000203"
	aggregate.Details[0].PriceUUID = "00000000-0000-4000-8000-000000000204"
	aggregate.Details[0].CategoryUUID = "00000000-0000-4000-8000-000000000205"
	body, _ := json.Marshal(aggregate)
	if err := db.Exec("INSERT INTO transaction_cloud VALUES(?::uuid,'notaris')", uuid).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO transaction_cloud_outbox(aggregate_uuid,revision,operation,payload) VALUES(?::uuid,1,'create',?::jsonb)", uuid, string(body)).Error; err != nil {
		t.Fatal(err)
	}
	repo := NewTransactionCloudRepository(db)
	ctx := context.Background()
	expected := TransactionPublicationExpectation{Domain: "notaris", UUID: uuid, Operation: "create", Revision: 1, ExpectedLastSeq: 0}
	for _, mutate := range []func(*TransactionPublicationExpectation){func(e *TransactionPublicationExpectation) { e.Domain = "ppat" }, func(e *TransactionPublicationExpectation) { e.Operation = "delete" }, func(e *TransactionPublicationExpectation) { e.Revision = 2 }, func(e *TransactionPublicationExpectation) { e.ExpectedLastSeq = 1 }, func(e *TransactionPublicationExpectation) { e.UUID = "00000000-0000-4000-8000-000000000199" }} {
		invalid := expected
		mutate(&invalid)
		if _, err := repo.PublishExpected(ctx, invalid); !errors.Is(err, ErrUnexpectedTransactionOutbox) {
			t.Fatalf("bad expectation allowed: %+v %v", invalid, err)
		}
	}
	if err := db.Exec("INSERT INTO transaction_cloud_outbox(aggregate_uuid,revision,operation,payload) VALUES(?::uuid,2,'update',?::jsonb)", uuid, string(body)).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := repo.PublishExpected(ctx, expected); !errors.Is(err, ErrUnexpectedTransactionOutbox) {
		t.Fatal("unrelated pending event allowed", err)
	}
	if err := db.Exec("DELETE FROM transaction_cloud_outbox WHERE revision=2").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(`CREATE FUNCTION deny_publication() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected publication failure'; END $$; CREATE TRIGGER deny_publication BEFORE UPDATE ON transaction_cloud_outbox FOR EACH ROW EXECUTE FUNCTION deny_publication()`).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := repo.PublishExpected(ctx, expected); err == nil {
		t.Fatal("failure injection ignored")
	}
	var last, pending int64
	db.Raw("SELECT last_seq FROM transaction_cloud_publication WHERE id=1").Row().Scan(&last)
	db.Raw("SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq IS NULL").Row().Scan(&pending)
	if last != 0 || pending != 1 {
		t.Fatal("partial publication", last, pending)
	}
	if err := db.Exec("DROP TRIGGER deny_publication ON transaction_cloud_outbox").Error; err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	results := make(chan TransactionPublicationResult, 2)
	errs := make(chan error, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); r, e := repo.PublishExpected(ctx, expected); results <- r; errs <- e }()
	}
	wg.Wait()
	close(results)
	close(errs)
	for e := range errs {
		if e != nil {
			t.Fatal(e)
		}
	}
	published, replayed := 0, 0
	for r := range results {
		published += r.Published
		if r.Replay {
			replayed++
		}
		if r.Sequence != 1 || r.LastSeq != 1 {
			t.Fatal(r)
		}
	}
	if published != 1 || replayed != 1 {
		t.Fatal("publication duplicated", published, replayed)
	}
	if r, e := repo.PublishExpected(ctx, expected); e != nil || r.Published != 0 || !r.Replay {
		t.Fatal("retry not idempotent", r, e)
	}
}
