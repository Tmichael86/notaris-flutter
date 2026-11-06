package main

import (
	"backend-notaris-go/repositories"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestTransactionPublicationAllowlist(t *testing.T) {
	target := "127.0.0.1:5432/notarisdev"
	e := repositories.TransactionPublicationExpectation{Domain: "ppat", UUID: "00000000-0000-4000-8000-000000000001", Operation: "create", Revision: 1, ExpectedLastSeq: 0}
	o := options{transaction: true, domain: "ppat", onlyUUID: e.UUID, operation: e.Operation, revision: 1, batch: 1, maxBatches: 1, timeout: time.Minute, apply: true, liveApproved: true, confirm: target, expectedLastSeq: 0}
	if o.validate(target) == nil {
		t.Fatal("unpinned allowlist accepted")
	}
	o.allowlist = filepath.Join(t.TempDir(), "allowlist.json")
	raw, _ := json.Marshal(map[string]any{"target": target, "events": []any{map[string]any{"kind": "transaction", "domain": e.Domain, "uuid": e.UUID, "operation": e.Operation, "revision": e.Revision, "expected_last_seq": e.ExpectedLastSeq}}})
	if err := os.WriteFile(o.allowlist, raw, 0600); err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(raw)
	o.allowlistHash = hex.EncodeToString(hash[:])
	if err := o.validate(target); err != nil {
		t.Fatal(err)
	}
	if err := approvedPublication(o, target, "transaction", e); err != nil {
		t.Fatal(err)
	}
	bad := e
	bad.ExpectedLastSeq = 1
	if approvedPublication(o, target, "transaction", bad) == nil {
		t.Fatal("unapproved cursor accepted")
	}
	bad = e
	bad.UUID = "00000000-0000-4000-8000-000000000002"
	if approvedPublication(o, target, "transaction", bad) == nil {
		t.Fatal("unrelated UUID accepted")
	}
	if approvedPublication(o, "127.0.0.1:5432/notarislokal", "transaction", e) == nil {
		t.Fatal("wrong target accepted")
	}
	if approvedPublication(o, target, "master", e) == nil {
		t.Fatal("wrong entity accepted")
	}
	o.allowlistHash = "0000000000000000000000000000000000000000000000000000000000000000"
	if approvedPublication(o, target, "transaction", e) == nil {
		t.Fatal("modified approval accepted")
	}
}
