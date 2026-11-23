package devfixture

import "testing"

func TestGroupsAcceptanceCatalog(t *testing.T) {
	rows := GroupsAcceptanceCatalog()
	if len(rows) != 21 {
		t.Fatal("catalog count")
	}
	ids, codes := map[uint]bool{}, map[string]bool{}
	containers, leaves, frozen := 0, 0, 0
	for _, row := range rows {
		if ids[row.ID] || codes[row.SidebarKode] {
			t.Fatal("duplicate identity")
		}
		ids[row.ID], codes[row.SidebarKode] = true, true
		if row.ID == 20 || row.ID == 21 {
			frozen++
			continue
		}
		if row.SidebarParentID == nil {
			t.Fatal("missing explicit parent")
		}
		if row.SidebarRoute == "#" {
			containers++
		} else {
			leaves++
		}
	}
	if containers != 3 || leaves != 16 || frozen != 2 {
		t.Fatal("coverage counts")
	}
	for _, row := range rows {
		if row.ID != 21 && row.SidebarParentID != nil && *row.SidebarParentID != 0 && !ids[*row.SidebarParentID] {
			t.Fatal("missing parent")
		}
	}
	for _, alias := range []string{"materai", "pendapatan", "konfigurasi", "konfigurasi_umum", "pekerjaan-notaris", "pekerjaan-ppat"} {
		if codes[alias] {
			t.Fatal("unverified alias", alias)
		}
	}
}
