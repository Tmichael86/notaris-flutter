package main

// Dedicated new, Windows-owner-bound read-only catalog acceptance only.
import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/internal/devfixture"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"golang.org/x/sys/windows"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unsafe"
)

const officeV1PG = 55799
const officeV1HTTP = 55887

func officeV1Bootstrap(id string) error {
	root, s, e := officeV1Root(id)
	if e != nil {
		return e
	}
	raw, e := os.ReadFile("migration_proposals/20261119_users_security.sql")
	sum := sha256.Sum256(raw)
	if e != nil || hex.EncodeToString(sum[:]) != s.Migration {
		return rejected
	}
	if writeNew(filepath.Join(root, "bootstrap-attempted.lock"), []byte(id)) != nil {
		return rejected
	}
	owner, e := officeV1Open(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(owner)
	name := officeV1ManifestFor(id).Database
	for _, sql := range []string{"CREATE DATABASE " + name, "COMMENT ON DATABASE " + name + " IS 'NOTARIS OFFICE V1 DISPOSABLE " + id + "'", "CREATE ROLE office_v1_app LOGIN PASSWORD '" + s.App + "'"} {
		if owner.Exec(sql).Error != nil {
			return rejected
		}
	}
	db, e := officeV1Open(id, true, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	e = db.Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec(`CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index integer,status smallint,created_at timestamptz);
CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,sidebar_id bigint,group_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(101,'Administrator Katalog','superadmin',1),(102,'Pemulihan Katalog','superadmin',1),(201,'Pembaca Katalog','user',1),(202,'Tanpa Izin Katalog','user',1);`).Error; e != nil {
			return e
		}
		for _, row := range devfixture.SidebarsAcceptanceCatalog() {
			var icon any = row.SidebarIcon
			if row.ID == 38 {
				icon = nil
			}
			if e := tx.Exec("INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status,created_at) VALUES(?,?,?,?,?,?,?,?, '2026-11-20T00:00:00Z')", row.ID, row.SidebarParentID, row.SidebarNama, row.SidebarKode, row.SidebarRoute, icon, row.SidebarIndex, row.Status).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(`INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES(40,0,'Konfigurasi Umum','konfigurasi','/konfigurasi','settings',40,1);
CREATE TABLE konfigurasi_umum(id bigserial PRIMARY KEY,alamat varchar(255),telp_rumah varchar(13),telp_pertama varchar(13),telp_kedua varchar(13),email varchar(255),notaris_bersangkutan varchar(255),ppat_bersangkutan varchar(255),besaran_nilai_tidak_kena_pajak numeric(20,0),pengecekan numeric(20,0),surat_kuasa_membebankan_hak_tanggungan numeric(20,0),ploting_validasi numeric(20,0),harga_beli_materai numeric(20,0),harga_jual_materai numeric(20,0),status smallint);
INSERT INTO konfigurasi_umum VALUES(1,'Kantor Demonstrasi, Jalan Uji 12','021000001',NULL,'021000003','kantor@example.invalid','NOTARISDEV SYNTHETIC v1','PPAT Demonstrasi',80000000,0,NULL,18446744073709551615,10000,12000,1);
CREATE TABLE transaksi(id bigint PRIMARY KEY,locked_by bigint,locked_at timestamptz);
INSERT INTO transaksi VALUES(1,201,'2026-11-20T00:00:00Z');`).Error; e != nil {
			return e
		}
		for _, u := range []struct {
			id   int
			name string
		}{{101, "admin.office"}, {102, "recovery.office"}, {201, "reader.office"}, {202, "denied.office"}} {
			hash, e := bcrypt.GenerateFromPassword([]byte(s.Passwords[u.name]), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			if e := tx.Exec("INSERT INTO users(id,group_id,username,email,nama,password,status) VALUES(?,?,?,?,?,?,1)", u.id, u.id, u.name, u.name+"@example.invalid", u.name, string(hash)).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(`INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT s.id,g,1,1,1,1 FROM sidebar s CROSS JOIN(VALUES(101),(102))v(g) WHERE s.status=1 AND s.id<>40;
INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(40,201,1,0,0,0),(40,101,1,0,0,0),(40,102,1,0,0,0);`).Error; e != nil {
			return e
		}
		if e := tx.Exec(string(raw)).Error; e != nil {
			return e
		}
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC;GRANT USAGE ON SCHEMA public TO office_v1_app;
GRANT SELECT ON users,groups,sidebar,sidebar_akses,konfigurasi_umum,transaksi TO office_v1_app;
ALTER ROLE office_v1_app SET default_transaction_read_only=on;`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED"}`))
}
func officeV1Handler(id string, db *gorm.DB, s officeV1Secrets) http.Handler {
	database.DB = db
	cfg := config.Config{JWTSecret: s.JWT, JWTExpireMinutes: 120, UsersSecurityEnabled: true}
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.POST("/api/v1/auth/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	auth := middleware.JWTAuth(cfg)
	me := controllers.NewMeController()
	r.GET("/api/v1/auth/me", auth, me.Me)
	r.GET("/api/v1/auth/me/sidebar-access", auth, me.SidebarAccess)
	permission := middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "konfigurasi", "read")
	r.GET("/api/v1/konfigurasi", controllers.RequireOfficeSecurity(cfg), auth, permission, controllers.OfficeConfigurationRead)
	r.GET("/api/v1/development/office-v1", auth, func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		var u struct{ ID, GroupID uint }
		uid, _ := c.Get("user_id")
		if e != nil || db.Table("users").Select("id,group_id").Where("id=? AND status=1", uid).Take(&u).Error != nil || name != officeV1ManifestFor(id).Database || host != "127.0.0.1" || port != officeV1PG || marker != "NOTARIS OFFICE V1 DISPOSABLE "+id {
			c.Status(503)
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": "office-v1/" + id, "database": name, "host": host, "port": port, "marker": marker, "account_id": u.ID, "group_id": u.GroupID, "cloud_sync": false})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, q)
	})
}
func officeV1HTTPCheck(id string, s officeV1Secrets, base string) error {
	client := groupsV2Client()
	for _, name := range []string{"reader.office", "denied.office"} {
		token, e := groupsV2Login(client, base, name, s.Passwords[name])
		if e != nil {
			return e
		}
		for _, path := range []string{"/api/v1/development/office-v1", "/api/v1/konfigurasi"} {
			q, _ := http.NewRequest("GET", base+path, nil)
			q.Header.Set("Authorization", "Bearer "+token)
			res, e := client.Do(q)
			if e != nil {
				return rejected
			}
			var v map[string]any
			e = json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&v)
			res.Body.Close()
			if strings.Contains(path, "development") {
				if e != nil || res.StatusCode != 200 || v["profile"] != id || v["scope"] != "office-v1/"+id {
					return rejected
				}
			} else if name == "denied.office" {
				if res.StatusCode != 403 {
					return rejected
				}
			} else if e != nil || res.StatusCode != 200 || v["success"] != true {
				return rejected
			}
		}
	}
	return nil
}
func runOfficeV1(args []string) error {
	if len(args) == 1 && args[0] == "office-v1-init" {
		return officeV1Init()
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, s, e := officeV1Root(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "office-v1-bootstrap":
		return officeV1Bootstrap(id)
	case "office-v1-validate":
		return json.NewEncoder(os.Stdout).Encode(officeV1ManifestFor(id))
	case "office-v1-credential":
		if len(args) != 3 || s.Passwords[args[2]] == "" {
			return rejected
		}
		content, _ := windows.UTF16PtrFromString(args[2] + "\n" + s.Passwords[args[2]])
		title, _ := windows.UTF16PtrFromString("Konfigurasi Umum V1 · kredensial disposable · jangan rekam dialog")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	db, e := officeV1Open(id, args[0] == "office-v1-state", false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	switch args[0] {
	case "office-v1-state":
		v, e := officeV1State(db)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(v)
	case "office-v1-http-check":
		return officeV1HTTPCheck(id, s, "http://127.0.0.1:55887")
	case "office-v1-self-check":
		server := httptest.NewServer(officeV1Handler(id, db, s))
		defer server.Close()
		return officeV1HTTPCheck(id, s, server.URL)
	case "office-v1-serve":
		listener, e := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(officeV1HTTP))
		if e != nil {
			return rejected
		}
		fmt.Println("OFFICE_V1_BACKEND_READY scope=office-v1/" + id)
		return (&http.Server{Handler: officeV1Handler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	}
	return rejected
}

// Reuse reviewed DPAPI secret representation, never its profile or credentials.
type officeV1Secrets = groupsV2Secrets
type officeV1Manifest = groupsV2Manifest

func officeV1ManifestFor(id string) groupsV2Manifest {
	return groupsV2Manifest{Profile: id, Scope: "office-v1/" + id, Database: "office_v1_" + id, BaseURL: "http://127.0.0.1:55887/api/v1", Port: officeV1PG, Schema: 27, Catalog: "office-v1"}
}
func officeV1Root(id string) (string, officeV1Secrets, error) {
	var s officeV1Secrets
	root, e := profileRoot(id)
	if e != nil {
		return "", s, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", s, rejected
	}
	marker, e := readOwnedFile(root, "office-v1-owner")
	if e != nil || string(marker) != id {
		return "", s, rejected
	}
	if unseal(root, id, "office-v1-secrets", &s) != nil {
		return "", s, rejected
	}
	raw, e := readOwnedFile(root, "office-v1.json")
	var m officeV1Manifest
	if e != nil || json.Unmarshal(raw, &m) != nil || m != officeV1ManifestFor(id) {
		return "", s, rejected
	}
	return root, s, nil
}
func officeV1Init() error {
	migration, e := os.ReadFile("migration_proposals/20261119_users_security.sql")
	if e != nil {
		return rejected
	}
	pub, priv, e := ed25519.GenerateKey(rand.Reader)
	if e != nil {
		return e
	}
	defer clear(priv)
	id := profileID(pub)
	root, e := profileRoot(id)
	if e != nil {
		return e
	}
	if e = os.Mkdir(root, 0700); e != nil {
		return e
	}
	user, e := windows.GetCurrentProcessToken().GetTokenUser()
	if e != nil {
		return e
	}
	sd, e := windows.SecurityDescriptorFromString("D:P(A;OICI;FA;;;" + user.User.Sid.String() + ")(A;OICI;FA;;;SY)")
	if e != nil {
		return e
	}
	dacl, _, e := sd.DACL()
	if e != nil {
		return e
	}
	if e = windows.SetNamedSecurityInfo(root, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION, nil, nil, dacl, nil); e != nil {
		return e
	}
	for n, v := range map[string][]byte{"owner": []byte(id), "office-v1-owner": []byte(id), "public.key": pub} {
		if e = writeNew(filepath.Join(root, n), v); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	s := officeV1Secrets{Owner: hex.EncodeToString(randomBytes(32)), App: hex.EncodeToString(randomBytes(32)), JWT: hex.EncodeToString(randomBytes(32)), Migration: hex.EncodeToString(sum[:]), Passwords: map[string]string{}, FullCatalog: false}
	for _, name := range []string{"admin.office", "recovery.office", "reader.office", "denied.office"} {
		s.Passwords[name] = hex.EncodeToString(randomBytes(18))
	}
	if e = seal(root, id, "office-v1-secrets", s, priv); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(s.Owner+"\n")); e != nil {
		return e
	}
	raw, _ := json.Marshal(officeV1ManifestFor(id))
	if e = writeNew(filepath.Join(root, "office-v1.json"), raw); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root})
}
func officeV1Open(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := officeV1Root(id)
	if e != nil {
		return nil, e
	}
	m := officeV1ManifestFor(id)
	name := m.Database
	role, pwd := "office_v1_app", s.App
	if owner {
		role, pwd = "office_v1_owner", s.Owner
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	db, e := gorm.Open(postgres.Open(fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", officeV1PG, role, pwd, name)), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if e != nil {
		return nil, rejected
	}
	pool, e := db.DB()
	if e != nil {
		return nil, rejected
	}
	pool.SetMaxOpenConns(5)
	var actual, host, who, marker string
	var port int
	e = pool.QueryRow(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),current_user,coalesce(shobj_description(oid,'pg_database'),'') FROM pg_database WHERE datname=current_database()`).Scan(&actual, &host, &port, &who, &marker)
	if e != nil || actual != name || host != "127.0.0.1" || port != officeV1PG || who != role {
		pool.Close()
		return nil, rejected
	}
	if owner {
		var dir string
		e = pool.QueryRow("SHOW data_directory").Scan(&dir)
		if e != nil || !strings.EqualFold(filepath.Clean(dir), filepath.Join(root, "pgdata")) {
			pool.Close()
			return nil, rejected
		}
	}
	if !bootstrap && marker != "NOTARIS OFFICE V1 DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}

// Full owned-cluster fingerprints include configuration, lock witnesses, grants,
// audits and sequence states. Only digests, never password hashes, are emitted.
func officeV1State(db *gorm.DB) (map[string]any, error) {
	state, e := groupsV2State(db)
	if e != nil {
		return nil, e
	}
	hashes := map[string]string{}
	var tables []string
	if e = db.Raw("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename").Scan(&tables).Error; e != nil {
		return nil, rejected
	}
	for _, table := range tables {
		var raw string
		if e = db.Raw("SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY row_to_json(t)::text),'') FROM " + `"` + strings.ReplaceAll(table, `"`, `""`) + `"` + " t").Scan(&raw).Error; e != nil {
			return nil, rejected
		}
		hash := sha256.Sum256([]byte(raw))
		hashes[table] = hex.EncodeToString(hash[:])
	}
	var sequences string
	if e = db.Raw("SELECT coalesce(json_agg(s ORDER BY sequencename)::text,'[]') FROM pg_sequences s WHERE schemaname='public'").Scan(&sequences).Error; e != nil {
		return nil, rejected
	}
	hash := sha256.Sum256([]byte(sequences))
	hashes["sequences"] = hex.EncodeToString(hash[:])
	state["all_table_fingerprints"] = hashes
	app, e := officeV1Open(strings.TrimPrefix(dbNameForOffice(db), "office_v1_"), false, false)
	if e != nil {
		return nil, e
	}
	defer closePromo(app)
	var writable bool
	var mode string
	if app.Raw(`SELECT bool_or(has_table_privilege(current_user,quote_ident(tablename),'INSERT,UPDATE,DELETE,TRUNCATE')) FROM pg_tables WHERE schemaname='public'`).Scan(&writable).Error != nil || writable {
		return nil, rejected
	}
	if app.Raw("SHOW transaction_read_only").Scan(&mode).Error != nil || mode != "on" {
		return nil, rejected
	}
	var count int64
	var marker string
	if db.Raw("SELECT count(*) FROM konfigurasi_umum").Scan(&count).Error != nil || count != 1 {
		return nil, rejected
	}
	if db.Raw("SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1 AND status=1").Scan(&marker).Error != nil || marker != "NOTARISDEV SYNTHETIC v1" {
		return nil, rejected
	}
	state["configuration_marker_preserved"] = true
	state["fixture_counts"] = map[string]int{"configuration": 1, "users": 4, "groups": 4, "sidebars": 26, "transaction_lock_witness": 1}
	state["runtime_read_only"] = true
	return state, nil
}
func dbNameForOffice(db *gorm.DB) string {
	var name string
	db.Raw("SELECT current_database()").Scan(&name)
	return name
}
