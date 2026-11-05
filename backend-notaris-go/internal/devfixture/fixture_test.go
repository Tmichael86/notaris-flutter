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

func TestBothMasterMenusHaveScopedFixtureCRUD(t *testing.T) {
	rows := Build("test")
	for _, code := range []string{"pekerjaan_notaris", "pekerjaan_ppat"} {
		var id any
		for _, r := range rows {
			if r.Table == "sidebar" && r.Values["sidebar_kode"] == code {
				id = r.Values["id"]
				if r.Values["status"] != 1 || r.Values["sidebar_route"] != "/"+code {
					t.Fatal("inactive/wrong route", code)
				}
			}
		}
		if id == nil {
			t.Fatal("missing master", code)
		}
		count := 0
		for _, r := range rows {
			if r.Table == "sidebar_akses" && r.Values["sidebar_id"] == id {
				count++
				if r.Values["group_id"] != 11 {
					t.Fatal("global access")
				}
				for _, flag := range []string{"read", "create", "update", "delete"} {
					if r.Values[flag] != 1 {
						t.Fatal("missing", flag)
					}
				}
			}
		}
		if count != 1 {
			t.Fatal("duplicate/missing grant", code)
		}
	}
	if err := Validate(rows); err != nil {
		t.Fatal(err)
	}
}
