package routes

import (
	"backend-notaris-go/database"
	"github.com/golang-jwt/jwt/v5"
	"gorm.io/gorm"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"
)

func officeFixture(t *testing.T) usersFixture {
	f := usersSetup(t)
	if e := f.db.Exec(`CREATE TABLE konfigurasi_umum(id bigint PRIMARY KEY,status smallint,alamat text,telp_rumah text,telp_pertama text,telp_kedua text,email text,notaris_bersangkutan text,ppat_bersangkutan text,besaran_nilai_tidak_kena_pajak numeric,pengecekan numeric,surat_kuasa_membebankan_hak_tanggungan numeric,ploting_validasi numeric,harga_beli_materai numeric,harga_jual_materai numeric);
 INSERT INTO konfigurasi_umum VALUES(1,1,'Kantor Uji','001',NULL,'003','office@example.invalid','NOTARISDEV SYNTHETIC v1','PPAT Uji',18446744073709551615,0,NULL,400000,10000,12000);
 CREATE TABLE transaksi(id bigint PRIMARY KEY,locked_by bigint,locked_at timestamptz);INSERT INTO transaksi VALUES(1,3,now());
 INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(40,'Konfigurasi Umum','konfigurasi','/konfigurasi',1),(41,'Alias terlarang','konfigurasi_umum','/konfigurasi-umum',1);
 INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete")VALUES(2,40,1,0,0,0),(3,41,1,0,0,0);`).Error; e != nil {
		t.Fatal(e)
	}
	return f
}
func officeSnapshot(t *testing.T, f usersFixture) string {
	t.Helper()
	var s string
	if e := f.db.Raw(`SELECT json_build_object('configuration',(SELECT json_agg(t ORDER BY id)FROM konfigurasi_umum t),'locks',(SELECT json_agg(t ORDER BY id)FROM transaksi t),'users',(SELECT json_agg(t ORDER BY id)FROM users t),'groups',(SELECT json_agg(t ORDER BY id)FROM groups t),'sidebars',(SELECT json_agg(t ORDER BY id)FROM sidebar t),'grants',(SELECT json_agg(t ORDER BY id)FROM sidebar_akses t),'audits',(SELECT json_agg(t ORDER BY id)FROM administrative_audit t))::text`).Scan(&s).Error; e != nil {
		t.Fatal(e)
	}
	return s
}
func TestOfficeConfigurationRead(t *testing.T) {
	f := officeFixture(t)
	before := officeSnapshot(t, f)
	// Actual database-enforced read-only transaction: any accidental DML fails.
	tx := f.db.Begin()
	if tx.Error != nil {
		t.Fatal(tx.Error)
	}
	defer tx.Rollback()
	if e := tx.Exec("SET TRANSACTION READ ONLY").Error; e != nil {
		t.Fatal(e)
	}
	// Global repositories share the same transaction in this owned serial test.
	old := databaseDBSwap(tx)
	defer databaseDBSwap(old)
	result := f.req(t, "GET", "/konfigurasi", 3, nil, 200)["data"].(map[string]any)
	if len(result) != 15 || result["id"] != float64(1) || result["development_data"] != true || result["telp_pertama"] != nil || result["surat_kuasa_membebankan_hak_tanggungan"] != nil || result["besaran_nilai_tidak_kena_pajak"] != "18446744073709551615" || result["pengecekan"] != "0" {
		t.Fatal("typed DTO/null/large integer")
	}
	for _, key := range []string{"alamat", "telp_rumah", "telp_pertama", "telp_kedua", "email", "notaris_bersangkutan", "ppat_bersangkutan", "besaran_nilai_tidak_kena_pajak", "pengecekan", "surat_kuasa_membebankan_hak_tanggungan", "ploting_validasi", "harga_beli_materai", "harga_jual_materai"} {
		if _, ok := result[key]; !ok {
			t.Fatal(key)
		}
	}
	if officeSnapshot(t, f) != before {
		t.Fatal("GET mutated configuration/locks/identities/audits")
	}
}
func TestOfficeConfigurationSingleton(t *testing.T) {
	f := officeFixture(t)
	for _, tc := range []struct {
		sql    string
		status int
		code   string
	}{
		{"DELETE FROM konfigurasi_umum", 404, "configuration_missing"},
		{"INSERT INTO konfigurasi_umum(id,status)VALUES(2,1)", 422, "configuration_invalid"},
		{"INSERT INTO konfigurasi_umum(id,status)VALUES(1,1)", 409, "configuration_ambiguous"},
		{"DELETE FROM konfigurasi_umum WHERE id=2; UPDATE konfigurasi_umum SET status=0", 422, "configuration_invalid"},
		{"UPDATE konfigurasi_umum SET status=1,pengecekan=-1", 422, "configuration_invalid"},
		{"UPDATE konfigurasi_umum SET pengecekan=1.5", 422, "configuration_invalid"},
		{"UPDATE konfigurasi_umum SET pengecekan=18446744073709551616", 422, "configuration_invalid"},
	} {
		if e := f.db.Exec(tc.sql).Error; e != nil {
			t.Fatal(e)
		}
		if got := f.req(t, "GET", "/konfigurasi", 3, nil, tc.status)["code"]; got != tc.code {
			t.Fatal(got)
		}
	}
}
func TestOfficeConfigurationAuthorization(t *testing.T) {
	f := officeFixture(t)
	f.req(t, "GET", "/konfigurasi", 0, nil, 401)
	f.req(t, "GET", "/konfigurasi", 1, nil, 403) // Superadmin has no implicit bypass.
	f.req(t, "GET", "/konfigurasi", 4, nil, 403) // Alias is not canonical.
	for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }, func(c jwt.MapClaims) { delete(c, "exp") }, func(c jwt.MapClaims) { delete(c, "sv") }, func(c jwt.MapClaims) { c["sv"] = 0 }, func(c jwt.MapClaims) { c["sv"] = 2 }} {
		q := httptest.NewRequest("GET", "/api/v1/konfigurasi", nil)
		q.Header.Set("Authorization", "Bearer "+f.token(3, change))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		if w.Code != 401 {
			t.Fatal("JWT rejection", w.Code)
		}
	}
	if e := f.db.Exec(`DROP INDEX sidebar_group_grant_unique; INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete")VALUES(2,40,1,0,0,0)`).Error; e != nil {
		t.Fatal(e)
	}
	f.req(t, "GET", "/konfigurasi", 3, nil, 403)
	f.db.Exec(`DELETE FROM sidebar_akses WHERE id=(SELECT max(id) FROM sidebar_akses)`)
	f.db.Exec(`UPDATE sidebar_akses SET "read"=0 WHERE sidebar_id=40`)
	f.req(t, "GET", "/konfigurasi", 3, nil, 403)
	f.db.Exec(`UPDATE groups SET status=0 WHERE id=2`)
	f.req(t, "GET", "/konfigurasi", 3, nil, 401)
	for _, method := range []string{"POST", "PUT", "PATCH", "DELETE"} {
		q := httptest.NewRequest(method, "/api/v1/konfigurasi", nil)
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		if w.Code != 404 {
			t.Fatal("mutation route exists")
		}
	}
}
func TestOfficeConfigurationFlutterHTTP(t *testing.T) {
	if os.Getenv("NOTARIS_OFFICE_V1_FLUTTER_E2E") != "1" {
		t.Skip("Flutter HTTP opt-in")
	}
	f := officeFixture(t)
	before := officeSnapshot(t, f)
	server := httptest.NewServer(f.api)
	defer server.Close()
	token := f.token(3, func(c jwt.MapClaims) { c["gid"] = 2 })
	cmd := exec.Command("flutter.bat", "test", "--no-pub", "test/e2e/office_v1_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	cmd.Env = append(os.Environ(), "NOTARIS_OFFICE_V1_HTTP="+server.URL+"/api/v1", "NOTARIS_OFFICE_V1_TOKEN="+token)
	out, e := cmd.CombinedOutput()
	safe := strings.ReplaceAll(string(out), token, "[REDACTED]")
	if e != nil {
		t.Fatalf("Flutter HTTP: %s", safe)
	}
	t.Log(safe)
	if officeSnapshot(t, f) != before {
		t.Fatal("HTTP changed protected state")
	}

}

func databaseDBSwap(db *gorm.DB) *gorm.DB { old := database.DB; database.DB = db; return old }
