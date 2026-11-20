package main

// Dedicated new, Windows-owner-bound read-only catalog acceptance only.
import (
	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/internal/devfixture"
	"backend-notaris-go/middleware"
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

const profileV1PG = 55800
const profileV1HTTP = 55888

func profileV1Bootstrap(id string) error {
	root, s, e := profileV1Root(id)
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
	owner, e := profileV1Open(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(owner)
	name := profileV1ManifestFor(id).Database
	for _, sql := range []string{"CREATE DATABASE " + name, "COMMENT ON DATABASE " + name + " IS 'NOTARIS PROFILE V1 DISPOSABLE " + id + "'", "CREATE ROLE profile_v1_app LOGIN PASSWORD '" + s.App + "'"} {
		if owner.Exec(sql).Error != nil {
			return rejected
		}
	}
	db, e := profileV1Open(id, true, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	e = db.Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec(`CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index integer,status smallint,created_at timestamptz);
CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,sidebar_id bigint,group_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(101,'Administrator Katalog','superadmin',1),(102,'Pemulihan Katalog','superadmin',1),(201,'Pembaca Katalog','user',1),(202,'Admin Biasa','user',1),(204,'Group Nonaktif','user',0);`).Error; e != nil {
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
		}{{101, "admin.profile"}, {102, "recovery.profile"}, {201, "user.profile"}, {202, "admin.biasa"}} {
			hash, e := bcrypt.GenerateFromPassword([]byte(s.Passwords[u.name]), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			if e := tx.Exec("INSERT INTO users(id,group_id,username,email,nama,password,status) VALUES(?,?,?,?,?,?,1)", u.id, u.id, u.name, u.name+"@example.invalid", u.name, string(hash)).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(`INSERT INTO users(id,group_id,username,email,nama,password,status) SELECT 203,201,'inactive.profile','inactive@example.invalid','Akun Nonaktif',password,0 FROM users WHERE id=201;INSERT INTO users(id,group_id,username,email,nama,password,status) SELECT 204,204,'groupinactive.profile','groupinactive@example.invalid','Group Nonaktif',password,1 FROM users WHERE id=201;
UPDATE users SET nama='Rani Profil',no_telp=NULL,alamat=NULL WHERE id=201;
CREATE TABLE protected_financial(id bigint PRIMARY KEY,amount bigint NOT NULL);INSERT INTO protected_financial VALUES(1,500000);
CREATE TABLE protected_materai(id bigint PRIMARY KEY,stock bigint NOT NULL);INSERT INTO protected_materai VALUES(1,20);`).Error; e != nil {
			return e
		}
		if e := tx.Exec(`INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT s.id,g,1,1,1,1 FROM sidebar s CROSS JOIN(VALUES(101),(102))v(g) WHERE s.status=1 AND s.id<>40;
INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(40,201,1,0,0,0),(40,101,1,0,0,0),(40,102,1,0,0,0);`).Error; e != nil {
			return e
		}
		for _, name := range []string{"inactive.profile", "groupinactive.profile"} {
			hash, e := bcrypt.GenerateFromPassword([]byte(s.Passwords[name]), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			if tx.Exec("UPDATE users SET password=? WHERE username=?", string(hash), name).Error != nil {
				return rejected
			}
		}
		if e := tx.Exec(string(raw)).Error; e != nil {
			return e
		}
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC;GRANT USAGE ON SCHEMA public TO profile_v1_app;
GRANT SELECT ON users,groups,sidebar,sidebar_akses,konfigurasi_umum,transaksi TO profile_v1_app;
GRANT UPDATE(nama,no_telp,alamat,revision,updated_at,updated_by) ON users TO profile_v1_app;
GRANT INSERT ON administrative_audit TO profile_v1_app;
GRANT USAGE ON SEQUENCE administrative_audit_id_seq TO profile_v1_app;`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED"}`))
}
func profileV1Handler(id string, db *gorm.DB, s profileV1Secrets) http.Handler {
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
	pc := controllers.NewProfileController(cfg)
	profile := r.Group("/api/v1/profile", pc.Prepare, auth)
	profile.GET("", pc.Get)
	profile.PATCH("", func(c *gin.Context) {
		uid, _ := c.Get("user_id")
		var revision int64
		if uid != uint(201) || db.Raw("SELECT revision FROM users WHERE id=201").Scan(&revision).Error != nil || revision != 1 {
			c.AbortWithStatusJSON(403, gin.H{"code": "acceptance_budget_closed"})
			return
		}
		pc.Patch(c)
	})
	r.GET("/api/v1/development/profile-v1", auth, func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		var u struct{ ID, GroupID uint }
		uid, _ := c.Get("user_id")
		if e != nil || db.Table("users").Select("id,group_id").Where("id=? AND status=1", uid).Take(&u).Error != nil || name != profileV1ManifestFor(id).Database || host != "127.0.0.1" || port != profileV1PG || marker != "NOTARIS PROFILE V1 DISPOSABLE "+id {
			c.Status(503)
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": "profile-v1/" + id, "database": name, "host": host, "port": port, "marker": marker, "account_id": u.ID, "group_id": u.GroupID, "cloud_sync": false})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, q)
	})
}
func profileV1HTTPCheck(id string, s profileV1Secrets, base string) error {
	client := groupsV2Client()
	for _, name := range []string{"user.profile", "admin.biasa", "admin.profile", "recovery.profile"} {
		token, e := groupsV2Login(client, base, name, s.Passwords[name])
		if e != nil {
			return e
		}
		q, _ := http.NewRequest("GET", base+"/api/v1/profile", nil)
		q.Header.Set("Authorization", "Bearer "+token)
		res, e := client.Do(q)
		if e != nil {
			return rejected
		}
		var envelope struct {
			Success bool
			Data    services.SelfProfile
		}
		e = json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&envelope)
		res.Body.Close()
		if e != nil || res.StatusCode != 200 || !envelope.Success || envelope.Data.Username != name {
			return rejected
		}
		if name == "user.profile" {
			q, _ = http.NewRequest("PATCH", base+"/api/v1/profile", strings.NewReader(`{"expected_revision":1,"nama":"Forbidden","no_telp":null,"alamat":null,"group_id":101}`))
			q.Header.Set("Authorization", "Bearer "+token)
			res, e = client.Do(q)
			if e != nil {
				return rejected
			}
			res.Body.Close()
			if res.StatusCode != 400 && res.StatusCode != 403 {
				return rejected
			}
		}
	}
	return nil
}
func runProfileV1(args []string) error {
	if len(args) == 1 && args[0] == "profile-v1-init" {
		return profileV1Init()
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, s, e := profileV1Root(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "profile-v1-bootstrap":
		return profileV1Bootstrap(id)
	case "profile-v1-validate":
		return json.NewEncoder(os.Stdout).Encode(profileV1ManifestFor(id))
	case "profile-v1-credential":
		if len(args) != 3 || s.Passwords[args[2]] == "" {
			return rejected
		}
		content, _ := windows.UTF16PtrFromString(args[2] + "\n" + s.Passwords[args[2]])
		title, _ := windows.UTF16PtrFromString("Profile V1 · kredensial disposable · jangan rekam dialog")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	db, e := profileV1Open(id, args[0] == "profile-v1-state", false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	switch args[0] {
	case "profile-v1-state":
		v, e := profileV1State(db)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(v)
	case "profile-v1-http-check":
		return profileV1HTTPCheck(id, s, "http://127.0.0.1:55888")
	case "profile-v1-self-check":
		server := httptest.NewServer(profileV1Handler(id, db, s))
		defer server.Close()
		return profileV1HTTPCheck(id, s, server.URL)
	case "profile-v1-serve":
		listener, e := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(profileV1HTTP))
		if e != nil {
			return rejected
		}
		fmt.Println("PROFILE_V1_BACKEND_READY scope=profile-v1/" + id)
		return (&http.Server{Handler: profileV1Handler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	}
	return rejected
}

// Reuse reviewed DPAPI secret representation, never its profile or credentials.
type profileV1Secrets = groupsV2Secrets
type profileV1Manifest = groupsV2Manifest

func profileV1ManifestFor(id string) groupsV2Manifest {
	return groupsV2Manifest{Profile: id, Scope: "profile-v1/" + id, Database: "profile_v1_" + id, BaseURL: "http://127.0.0.1:55888/api/v1", Port: profileV1PG, Schema: 27, Catalog: "profile-v1"}
}
func profileV1Root(id string) (string, profileV1Secrets, error) {
	var s profileV1Secrets
	root, e := profileRoot(id)
	if e != nil {
		return "", s, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", s, rejected
	}
	marker, e := readOwnedFile(root, "profile-v1-owner")
	if e != nil || string(marker) != id {
		return "", s, rejected
	}
	if unseal(root, id, "profile-v1-secrets", &s) != nil {
		return "", s, rejected
	}
	raw, e := readOwnedFile(root, "profile-v1.json")
	var m profileV1Manifest
	if e != nil || json.Unmarshal(raw, &m) != nil || m != profileV1ManifestFor(id) {
		return "", s, rejected
	}
	return root, s, nil
}
func profileV1Init() error {
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
	for n, v := range map[string][]byte{"owner": []byte(id), "profile-v1-owner": []byte(id), "public.key": pub} {
		if e = writeNew(filepath.Join(root, n), v); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	s := profileV1Secrets{Owner: hex.EncodeToString(randomBytes(32)), App: hex.EncodeToString(randomBytes(32)), JWT: hex.EncodeToString(randomBytes(32)), Migration: hex.EncodeToString(sum[:]), Passwords: map[string]string{}, FullCatalog: false}
	for _, name := range []string{"admin.profile", "recovery.profile", "user.profile", "admin.biasa", "inactive.profile", "groupinactive.profile"} {
		s.Passwords[name] = hex.EncodeToString(randomBytes(18))
	}
	if e = seal(root, id, "profile-v1-secrets", s, priv); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(s.Owner+"\n")); e != nil {
		return e
	}
	raw, _ := json.Marshal(profileV1ManifestFor(id))
	if e = writeNew(filepath.Join(root, "profile-v1.json"), raw); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root})
}
func profileV1Open(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := profileV1Root(id)
	if e != nil {
		return nil, e
	}
	m := profileV1ManifestFor(id)
	name := m.Database
	role, pwd := "profile_v1_app", s.App
	if owner {
		role, pwd = "profile_v1_owner", s.Owner
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	db, e := gorm.Open(postgres.Open(fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", profileV1PG, role, pwd, name)), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
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
	if e != nil || actual != name || host != "127.0.0.1" || port != profileV1PG || who != role {
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
	if !bootstrap && marker != "NOTARIS PROFILE V1 DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}

// Protect every table except the specifically approved own-field/revision/audit delta.
func profileV1State(db *gorm.DB) (map[string]any, error) {
	if (services.Administration{DB: db, Enabled: true}).Ready(context.Background()) != nil {
		return nil, rejected
	}
	hashes := map[string]string{}
	var tables []string
	if db.Raw("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename").Scan(&tables).Error != nil {
		return nil, rejected
	}
	for _, table := range tables {
		if table == "administrative_audit" {
			continue
		}
		var raw string
		query := "SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM " + `"` + table + `"` + " t"
		if table == "users" {
			query = `SELECT string_agg((CASE WHEN id=201 THEN to_jsonb(u)-ARRAY['nama','no_telp','alamat','revision','updated_at','updated_by'] ELSE to_jsonb(u) END)::text,E'\n' ORDER BY id) FROM users u`
		}
		if db.Raw(query).Scan(&raw).Error != nil {
			return nil, rejected
		}
		h := sha256.Sum256([]byte(raw))
		hashes[table] = hex.EncodeToString(h[:])
	}
	var sequences string
	if db.Raw("SELECT coalesce(json_agg(s ORDER BY sequencename)::text,'[]') FROM pg_sequences s WHERE schemaname='public' AND sequencename<>'administrative_audit_id_seq'").Scan(&sequences).Error != nil {
		return nil, rejected
	}
	h := sha256.Sum256([]byte(sequences))
	hashes["sequences"] = hex.EncodeToString(h[:])
	profile, e := (services.ProfileService{DB: db, Enabled: true}).Read(context.Background(), services.AdminActor{ID: 201, Version: 1})
	if e != nil {
		return nil, e
	}
	audits := []map[string]any{}
	var auditJSON string
	if db.Raw("SELECT coalesce(json_agg(t ORDER BY id)::text,'[]') FROM (SELECT id,actor_id,target_id,target_type,action,request_id,result,reason_code,before_state,after_state,source,occurred_at FROM administrative_audit)t").Scan(&auditJSON).Error != nil || json.Unmarshal([]byte(auditJSON), &audits) != nil {
		return nil, rejected
	}
	var sequence struct {
		LastValue int64
		IsCalled  bool
	}
	if db.Raw("SELECT last_value,is_called FROM administrative_audit_id_seq").Scan(&sequence).Error != nil {
		return nil, rejected
	}
	// Inspect effective privileges of the app connection, never its credentials.
	var databaseName string
	db.Raw("SELECT current_database()").Scan(&databaseName)
	app, e := profileV1Open(strings.TrimPrefix(databaseName, "profile_v1_"), false, false)
	if e != nil {
		return nil, e
	}
	defer closePromo(app)
	for _, column := range []string{"id", "group_id", "username", "email", "password", "status", "security_version", "image", "created_by", "created_at"} {
		var permitted bool
		if app.Raw("SELECT has_column_privilege(current_user,'users',?,'UPDATE')", column).Scan(&permitted).Error != nil || permitted {
			return nil, rejected
		}
	}
	var unsafe bool
	if app.Raw(`SELECT bool_or(has_table_privilege(current_user,quote_ident(tablename),'UPDATE,DELETE,TRUNCATE')) FROM pg_tables WHERE schemaname='public'`).Scan(&unsafe).Error != nil || unsafe {
		return nil, rejected
	}
	return map[string]any{"protected": hashes, "profile": profile, "audits": audits, "audit_sequence": sequence, "integrity": "PASS", "recovery": "PASS", "least_privilege": "PASS"}, nil
}
