package main

import "gorm.io/gorm"

var presentationAccount = account{"superadmin.demo", 104, "Superadmin Demo", "superadmin", 1, 1}

// Leaf destinations in Flutter AppShell. Write grants belong to operational
// local modules only. Shell-only destinations still use their existing guards.
var presentationMenus = []struct {
	code, name string
	write      int
}{
	{"dashboard", "Dashboard", 0},
	{"transaksi", "Transaksi", 1},
	{"monitoring", "Monitoring", 0},
	{"pengeluaran", "Pengeluaran", 1},
	{"piutang", "Piutang", 0},
	{"penghasilan", "Penghasilan", 0},
	{"pekerjaan_notaris", "Pekerjaan Notaris", 1},
	{"pekerjaan_ppat", "Pekerjaan PPAT", 1},
	{"kategori_pekerjaan", "Kategori Pekerjaan", 1},
	{"jenis_pengeluaran", "Jenis Pengeluaran", 1},
	{"petugas", "Petugas", 1},
	{"pemohon", "Pemohon", 1},
	{"laporan_materai", "Materai", 0},
	{"laporan_pendapatan", "Pendapatan", 0},
	{"users", "Users", 0},
	{"groups", "Groups", 0},
	{"sidebars", "Sidebars", 0},
	{"konfigurasi_umum", "Konfigurasi Umum", 0},
	{"log_sinkronisasi", "Log Sinkronisasi", 0},
	{"monitoring_sinkronisasi", "Monitoring Sinkronisasi", 0},
	{"recycle_bin", "Recycle Bin", 0},
}

func presentationAccessValid(a account, sidebars []access) bool {
	if a != presentationAccount || len(sidebars) != len(presentationMenus) {
		return false
	}
	byCode := make(map[string]access, len(sidebars))
	for _, grant := range sidebars {
		byCode[grant.Sidebar.Code] = grant
	}
	for _, menu := range presentationMenus {
		p := byCode[menu.code]
		if p.Sidebar.Name != menu.name || p.Sidebar.Status != 1 || p.Read != 1 ||
			p.Create != menu.write || p.Update != menu.write || p.Delete != menu.write {
			return false
		}
	}
	return true
}

func seedPresentationMenus(tx *gorm.DB) error {
	for index, menu := range presentationMenus {
		id := index + 1
		if err := tx.Exec(
			"INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_index,status) VALUES(?,?,?,?,?,1)",
			id, menu.name, menu.code, "/"+menu.code, id,
		).Error; err != nil {
			return err
		}
		if err := tx.Exec(
			`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(?,?,1,?,?,?)`,
			presentationAccount.ID, id, menu.write, menu.write, menu.write,
		).Error; err != nil {
			return err
		}
	}
	return nil
}
