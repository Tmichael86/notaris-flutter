package devfixture

import (
	"strings"
	"testing"
)

func TestDeterministicGraph(t *testing.T) {
	a, err := SQL(Build("fresh-test-hash"))
	if err != nil {
		t.Fatal(err)
	}
	b, _ := SQL(Build("fresh-test-hash"))
	if a != b {
		t.Fatal("nondeterministic fixture")
	}
	if !strings.Contains(a, "Fixture target refused") {
		t.Fatal("missing target guard")
	}
	for _, s := range []string{"TRUNCATE", "DROP TABLE", "ALTER TABLE", "petugas_sync_outbox"} {
		if strings.Contains(a, s) {
			t.Fatalf("unexpected %s", s)
		}
	}
}
func TestRejectBrokenGraph(t *testing.T) {
	rows := Build("test")
	for i := range rows {
		if rows[i].Table == "transaksi_detail_proses" {
			rows[i].Values["transaksi_id"] = 999999
			break
		}
	}
	if Validate(rows) == nil {
		t.Fatal("broken parent accepted")
	}
}
func TestDuplicatePK(t *testing.T) {
	rows := Build("test")
	rows = append(rows, rows[0])
	if Validate(rows) == nil {
		t.Fatal("duplicate accepted")
	}
}
