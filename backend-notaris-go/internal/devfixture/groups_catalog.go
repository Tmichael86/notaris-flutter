package devfixture

import "backend-notaris-go/models"

// GroupsAcceptanceCatalog is an opt-in disposable test catalog, never a seed
// for an existing deployment. IDs 1..21 retain the accepted V2 fixture identity.
// Configuration is excluded: its Flutter screen has no operational contract.
func GroupsAcceptanceCatalog() []models.Sidebar {
	type definition struct {
		id, parent uint
		name, code string
	}
	definitions := []definition{
		{1, 34, "Users", "users"}, {2, 34, "Groups", "groups"}, {3, 34, "Sidebars", "sidebars"},
		{4, 10, "Petugas", "petugas"}, {10, 0, "Master", "master"}, {11, 10, "Pemohon", "pemohon"},
		{22, 0, "Transaksi", "transaksi"}, {23, 0, "Monitoring", "monitoring"},
		{24, 0, "Pengeluaran", "pengeluaran"}, {25, 0, "Piutang", "piutang"}, {26, 0, "Penghasilan", "penghasilan"},
		{27, 10, "Pekerjaan Notaris", "pekerjaan_notaris"}, {28, 10, "Pekerjaan PPAT", "pekerjaan_ppat"},
		{29, 10, "Kategori Pekerjaan", "kategori_pekerjaan"}, {30, 10, "Jenis Pengeluaran", "jenis_pengeluaran"},
		{31, 0, "Laporan", "laporan"}, {32, 31, "Materai", "laporan_materai"}, {33, 31, "Pendapatan", "laporan_pendapatan"},
		{34, 0, "System", "system"},
	}
	rows := make([]models.Sidebar, 0, 21)
	for _, d := range definitions {
		route := "/" + d.code
		if d.code == "master" || d.code == "laporan" || d.code == "system" {
			route = "#"
		}
		parent := d.parent
		rows = append(rows, models.Sidebar{ID: d.id, SidebarParentID: &parent, SidebarNama: d.name, SidebarKode: d.code, SidebarRoute: route, SidebarIcon: "folder", SidebarIndex: int32(d.id), Status: 1})
	}
	orphan := uint(999)
	return append(rows,
		models.Sidebar{ID: 20, SidebarNama: "Historis", SidebarKode: "historis", SidebarRoute: "/historis", SidebarIcon: "archive", SidebarIndex: 20, Status: 0},
		models.Sidebar{ID: 21, SidebarParentID: &orphan, SidebarNama: "Parent tidak tersedia", SidebarKode: "unsupported", SidebarRoute: "/unsupported", SidebarIcon: "folder", SidebarIndex: 21, Status: 1},
	)
}
