// Package devfixture constructs test-owned data; it never reads source records.
package devfixture

import (
	"fmt"
	"sort"
	"strings"
)

type Row struct {
	Table  string
	Values map[string]any
}
type Edge struct{ Table, Column, Parent, Key string }

var Edges = []Edge{
	{"users", "group_id", "groups", "id"}, {"petugas", "user_id", "users", "id"}, {"petugas", "jenis_kelamin", "jenis_kelamin", "id"},
	{"pemohon", "jenis_kelamin", "jenis_kelamin", "id"}, {"sidebar_akses", "group_id", "groups", "id"}, {"sidebar_akses", "sidebar_id", "sidebar", "id"},
	{"transaksi", "petugas_id", "petugas", "id"}, {"transaksi", "pemohon_id", "pemohon", "id"}, {"transaksi", "status_id", "transaksi_status", "id"},
	{"transaksi", "jenis_pekerjaan_id", "pekerjaan_jenis", "id"}, {"transaksi", "pekerjaan_id", "pekerjaan_notaris", "id"}, {"transaksi", "kategori_pekerjaan_id", "pekerjaan_kategori", "id"}, {"transaksi", "jenis_pembayaran_id", "pembayaran_jenis", "id"},
	{"pekerjaan_notaris_proses", "pekerjaan_notaris_id", "pekerjaan_notaris", "id"},
	{"pekerjaan_notaris_harga", "pekerjaan_notaris_id", "pekerjaan_notaris", "id"}, {"pekerjaan_notaris_harga", "kategori_pekerjaan_id", "pekerjaan_kategori", "id"},
	{"transaksi_detail_proses", "transaksi_id", "transaksi", "id"}, {"transaksi_detail_proses", "jenis_pekerjaan_id", "pekerjaan_jenis", "id"}, {"transaksi_detail_proses", "prosesId", "pekerjaan_notaris_proses", "id"},
	{"transaksi_riwayat_pembayaran", "no_transaksi", "transaksi", "no_akta"},
}

// Build is deterministic given a fresh, caller-generated bcrypt hash. Fixture
// UUID constants are explicit test identities, never a cloud backfill algorithm.
func Build(hash string) []Row {
	var rows []Row
	add := func(table string, id int, v map[string]any) {
		v["id"] = id
		rows = append(rows, Row{table, v})
	}
	add("groups", 11, map[string]any{"group_nama": "Fixture Operators", "group_jenis": "user", "status": 1})
	add("users", 2001, map[string]any{"group_id": 11, "username": "fixture.operator", "password": hash, "email": "operator@example.invalid", "nama": "Synthetic Operator", "status": 1})
	for _, item := range []struct {
		id   int
		name string
	}{{11, "Fixture Gender A"}, {29, "Fixture Gender B"}} {
		add("jenis_kelamin", item.id, map[string]any{"nama": item.name, "status": 1})
	}
	menus := []struct{ code, name string }{{"pemohon", "Pemohon"}, {"petugas", "Petugas"}, {"kategori_pekerjaan", "Kategori Pekerjaan"}, {"jenis_pengeluaran", "Jenis Pengeluaran"}, {"transaksi", "Transaksi"}, {"pekerjaan_notaris", "Pekerjaan Notaris"}}
	for i, m := range menus {
		add("sidebar", i+1, map[string]any{"sidebar_nama": m.name, "sidebar_route": "/" + m.code, "sidebar_kode": m.code, "sidebar_icon": "folder", "sidebar_index": i + 1, "status": 1})
		add("sidebar_akses", i+1, map[string]any{"sidebar_id": i + 1, "group_id": 11, "read": 1, "create": 1, "update": 1, "delete": 1})
	}
	for i := 1; i <= 4; i++ {
		add("petugas", 100+i, map[string]any{"nama": fmt.Sprintf("Synthetic Petugas %02d", i), "email": fmt.Sprintf("petugas%02d@example.invalid", i), "jenis_kelamin": 11, "status": 1})
	}
	for i := 1; i <= 20; i++ {
		add("pemohon", 300+i, map[string]any{"nama": fmt.Sprintf("Synthetic Pemohon %02d", i), "alamat": "Fixture street, not a real address", "jenis_kelamin": 29, "status": 1, "uuid": fmt.Sprintf("fa000001-0000-4000-8000-%012d", i)})
	}
	for _, m := range []struct{ table, name string }{{"pekerjaan_jenis", "Notaris"}, {"pekerjaan_kategori", "Synthetic Category"}, {"pengeluaran_jenis", "Synthetic Expense"}, {"pembayaran_jenis", "Fixture Cash"}, {"transaksi_status", "Fixture Open"}, {"pekerjaan_notaris", "Synthetic Notarial Job"}} {
		v := map[string]any{"nama": m.name, "status": 1}
		if m.table == "pekerjaan_kategori" {
			v["uuid"] = "fa000002-0000-4000-8000-000000000001"
		}
		if m.table == "pengeluaran_jenis" {
			v["uuid"] = "fa000003-0000-4000-8000-000000000001"
		}
		add(m.table, 1, v)
	}
	add("pekerjaan_notaris_proses", 1, map[string]any{"pekerjaan_notaris_id": 1, "nama": "Synthetic Process", "detail": "Fixture only", "status": 1})
	add("pekerjaan_notaris_harga", 1, map[string]any{"pekerjaan_notaris_id": 1, "kategori_pekerjaan_id": 1, "harga": "100000", "estimasi_waktu": "1 day", "status": 1})
	add("konfigurasi_umum", 1, map[string]any{"notaris_bersangkutan": "NOTARISDEV SYNTHETIC v1", "status": 1})
	for i := 1; i <= 4; i++ {
		number := fmt.Sprintf("FIXTURE-%04d", i)
		add("transaksi", 500+i, map[string]any{"no_akta": number, "nomor_akta": number, "tanggal_daftar": "2020-01-01", "tanggal_selesai": "2020-01-03", "jatuh_tempo": "2020-01-10", "biaya_layanan": 100000, "biaya_lainnya": 0, "petugas_id": 100 + i, "sub_total": "100000", "potongan_biaya": "0", "total": 100000, "pemohon_id": 300 + i, "jenis_pekerjaan_id": 1, "pekerjaan_id": 1, "kategori_pekerjaan_id": 1, "status_id": 1, "jenis_pembayaran_id": 1, "status": 1, "uuid": fmt.Sprintf("fa000004-0000-4000-8000-%012d", i)})
		add("transaksi_detail_proses", 600+i, map[string]any{"transaksi_id": 500 + i, "jenis_pekerjaan_id": 1, "prosesId": 1, "pekerjaanNama": "Synthetic Notarial Job", "kategoriNama": "Synthetic Category", "prosesNama": "Synthetic Process", "atribut": "[]", "catatan": "Fixture only", "status": 1, "uuid": fmt.Sprintf("fa000005-0000-4000-8000-%012d", i)})
		add("transaksi_riwayat_pembayaran", 700+i, map[string]any{"tanggal_pembayaran": "2020-01-02", "no_transaksi": number, "jumlah_dibayar": 25000, "pembayaran_ke": 1, "keterangan": "Synthetic installment", "status": 1})
	}
	return rows
}

func Validate(rows []Row) error {
	index := map[string]map[string]bool{}
	for _, r := range rows {
		for k, v := range r.Values {
			key := r.Table + "." + k
			if index[key] == nil {
				index[key] = map[string]bool{}
			}
			index[key][fmt.Sprint(v)] = true
		}
	}
	ids := map[string]bool{}
	for _, r := range rows {
		key := fmt.Sprintf("%s:%v", r.Table, r.Values["id"])
		if ids[key] {
			return fmt.Errorf("duplicate fixture PK %s", key)
		}
		ids[key] = true
	}
	for _, e := range Edges {
		for _, r := range rows {
			if r.Table != e.Table {
				continue
			}
			v, ok := r.Values[e.Column]
			if ok && v != nil && !index[e.Parent+"."+e.Key][fmt.Sprint(v)] {
				return fmt.Errorf("broken fixture edge %s.%s", e.Table, e.Column)
			}
		}
	}
	return nil
}
func Quote(s string) string { return `"` + strings.ReplaceAll(s, `"`, `""`) + `"` }
func SQL(rows []Row) (string, error) {
	if err := Validate(rows); err != nil {
		return "", err
	}
	var b strings.Builder
	b.WriteString("BEGIN;\nSET LOCAL search_path=public;\n")
	b.WriteString(`DO $$ DECLARE r record; n bigint; BEGIN
 IF current_database()<>'notarisdev' AND current_database() !~ '^notaris_fixture_test_[a-f0-9]+$' THEN RAISE EXCEPTION 'Fixture target refused'; END IF;
 IF (SELECT count(*) FROM pg_tables WHERE schemaname='public')<>38 THEN RAISE EXCEPTION 'Expected reviewed 38-table schema'; END IF;
 FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP EXECUTE format('SELECT count(*) FROM public.%I',r.tablename) INTO n; IF n<>0 THEN RAISE EXCEPTION 'Fixture requires entirely empty schema'; END IF; END LOOP;
 END $$;` + "\n")
	for _, r := range rows {
		keys := make([]string, 0, len(r.Values))
		for k := range r.Values {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		cols := []string{}
		vals := []string{}
		for _, k := range keys {
			cols = append(cols, Quote(k))
			v := r.Values[k]
			switch x := v.(type) {
			case int:
				vals = append(vals, fmt.Sprint(x))
			case string:
				vals = append(vals, "'"+strings.ReplaceAll(x, "'", "''")+"'")
			default:
				return "", fmt.Errorf("unsupported fixture type")
			}
		}
		fmt.Fprintf(&b, "INSERT INTO public.%s (%s) VALUES (%s);\n", Quote(r.Table), strings.Join(cols, ","), strings.Join(vals, ","))
	}
	// Identity sequence values are target-local metadata, never source identity.
	b.WriteString(`DO $$ DECLARE r record; s text; n bigint; BEGIN FOR r IN SELECT table_name FROM information_schema.columns WHERE table_schema='public' AND column_name='id' AND column_default LIKE 'nextval%' LOOP s:=pg_get_serial_sequence(format('public.%I',r.table_name),'id'); EXECUTE format('SELECT max(id) FROM public.%I',r.table_name) INTO n; IF n IS NOT NULL THEN PERFORM setval(s,n,true); END IF; END LOOP; END $$;` + "\nCOMMIT;\n")
	return b.String(), nil
}
