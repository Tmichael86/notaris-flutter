package main

// New, Windows-owner-bound Groups acceptance only. No caller-selected DSN,
// existing profile reuse, public bootstrap, or operational fallback.
import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
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

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/middleware"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"

	"golang.org/x/crypto/bcrypt"
	"golang.org/x/sys/windows"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const groupsV2PG = 55797
const groupsV2HTTP = 55885

type groupsV2Secrets struct {
	Owner, App, JWT, Migration string
	Passwords                  map[string]string
}
type groupsV2Manifest struct {
	Profile, Scope, Database, BaseURL string
	Port, Schema                      int
}

func groupsV2ManifestFor(id string) groupsV2Manifest {
	return groupsV2Manifest{id, "groups-v2/" + id, "groups_v2_" + id, "http://127.0.0.1:55885/api/v1", groupsV2PG, 27}
}
func groupsV2Root(id string) (string, groupsV2Secrets, error) {
	var s groupsV2Secrets
	root, e := profileRoot(id)
	if e != nil {
		return "", s, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", s, rejected
	}
	marker, e := readOwnedFile(root, "groups-v2-owner")
	if e != nil || string(marker) != id {
		return "", s, rejected
	}
	if unseal(root, id, "groups-v2-secrets", &s) != nil {
		return "", s, rejected
	}
	raw, e := readOwnedFile(root, "groups-v2.json")
	var m groupsV2Manifest
	if e != nil || json.Unmarshal(raw, &m) != nil || m != groupsV2ManifestFor(id) {
		return "", s, rejected
	}
	return root, s, nil
}
func groupsV2Init() error {
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
	for n, v := range map[string][]byte{"owner": []byte(id), "groups-v2-owner": []byte(id), "public.key": pub} {
		if e = writeNew(filepath.Join(root, n), v); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	s := groupsV2Secrets{hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(32)), hex.EncodeToString(sum[:]), map[string]string{}}
	for _, name := range []string{"admin.groups", "recovery.groups", "admin.biasa", "petugas.groups"} {
		s.Passwords[name] = hex.EncodeToString(randomBytes(18))
	}
	for i := 1; i <= 12; i++ {
		s.Passwords[fmt.Sprintf("operator.%02d", i)] = hex.EncodeToString(randomBytes(18))
	}
	s.Passwords["inactive.users"] = hex.EncodeToString(randomBytes(18))
	if e = seal(root, id, "groups-v2-secrets", s, priv); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(s.Owner+"\n")); e != nil {
		return e
	}
	raw, _ := json.Marshal(groupsV2ManifestFor(id))
	if e = writeNew(filepath.Join(root, "groups-v2.json"), raw); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root})
}
func groupsV2Open(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := groupsV2Root(id)
	if e != nil {
		return nil, e
	}
	m := groupsV2ManifestFor(id)
	name := m.Database
	role, pwd := "groups_v2_app", s.App
	if owner {
		role, pwd = "groups_v2_owner", s.Owner
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	db, e := gorm.Open(postgres.Open(fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", groupsV2PG, role, pwd, name)), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
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
	if e != nil || actual != name || host != "127.0.0.1" || port != groupsV2PG || who != role {
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
	if !bootstrap && marker != "NOTARIS GROUPS V2 DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}
func groupsV2Bootstrap(id string) error {
	root, s, e := groupsV2Root(id)
	if e != nil {
		return e
	}
	raw, e := os.ReadFile("migration_proposals/20261119_users_security.sql")
	hash := sha256.Sum256(raw)
	if e != nil || hex.EncodeToString(hash[:]) != s.Migration {
		return rejected
	}
	if e = writeNew(filepath.Join(root, "bootstrap-attempted.lock"), []byte(id)); e != nil {
		return rejected
	}
	owner, e := groupsV2Open(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(owner)
	name := groupsV2ManifestFor(id).Database
	for _, sql := range []string{"CREATE DATABASE " + name, "COMMENT ON DATABASE " + name + " IS 'NOTARIS GROUPS V2 DISPOSABLE " + id + "'", "CREATE ROLE groups_v2_app LOGIN PASSWORD '" + s.App + "'"} {
		if owner.Exec(sql).Error != nil {
			return rejected
		}
	}
	db, e := groupsV2Open(id, true, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	e = db.Transaction(func(tx *gorm.DB) error {
		ddl := `CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index integer,status smallint);
 CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,sidebar_id bigint,group_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(101,'Administrator Uji','superadmin',1),(102,'Pemulihan Terproteksi','superadmin',1),(201,'CS','user',1),(202,'Pelayanan','user',1),(203,'Arsip','user',1),(204,'Nonaktif','user',0);
 INSERT INTO groups(id,group_nama,group_jenis,status) SELECT i,'Grup Arsip '||(i-300)::text,'user',1 FROM generate_series(301,312)i;
 INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES
 (1,0,'Users','users','/users','people',1,1),(2,0,'Groups','groups','/groups','groups',2,1),(3,0,'Sidebars','sidebars','/sidebars','menu',3,1),
 (4,10,'Petugas','petugas','/petugas','badge',4,1),(10,0,'Master','master','#','folder',10,1),(11,10,'Pemohon','pemohon','/pemohon','person',11,1),
 (20,0,'Historis','historis','/historis','archive',20,0),(21,999,'Parent tidak tersedia','unsupported','/unsupported','folder',21,1);
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT s.id,g,1,1,1,1 FROM sidebar s CROSS JOIN (VALUES(101),(102))v(g) WHERE s.status=1;
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT id,201,0,0,0,0 FROM sidebar WHERE id NOT IN(20,21);
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(20,201,1,1,0,0),(21,201,1,0,1,0),(4,202,1,0,0,0);`
		if e := tx.Exec(ddl).Error; e != nil {
			return e
		}
		type fixture struct {
			id, group      int
			username, name string
			status         int
		}
		rows := []fixture{{101, 101, "admin.groups", "Administrator Uji", 1}, {102, 102, "recovery.groups", "Pemulihan Terproteksi", 1}, {201, 201, "admin.biasa", "Admin Biasa", 1}, {202, 202, "petugas.groups", "Petugas Pelayanan", 1}, {399, 201, "inactive.users", "Akun Nonaktif", 0}}
		for i := 1; i <= 12; i++ {
			g := 201
			if i%2 == 0 {
				g = 202
			}
			rows = append(rows, fixture{300 + i, g, fmt.Sprintf("operator.%02d", i), fmt.Sprintf("Operator %02d", i), 1})
		}
		for _, r := range rows {
			h, e := bcrypt.GenerateFromPassword([]byte(s.Passwords[r.username]), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			if e = tx.Exec("INSERT INTO users(id,group_id,username,email,nama,password,status) VALUES(?,?,?,?,?,?,?)", r.id, r.group, r.username, r.username+"@example.invalid", r.name, string(h), r.status).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(string(raw)).Error; e != nil {
			return e
		}
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC;GRANT USAGE ON SCHEMA public TO groups_v2_app;
 GRANT SELECT ON users,groups,sidebar,sidebar_akses TO groups_v2_app;GRANT UPDATE(revision) ON groups TO groups_v2_app;
 GRANT INSERT ON sidebar_akses TO groups_v2_app;GRANT UPDATE("read","create","update","delete",updated_by,updated_at) ON sidebar_akses TO groups_v2_app;
 GRANT INSERT ON administrative_audit TO groups_v2_app;GRANT USAGE ON SEQUENCE sidebar_akses_id_seq,administrative_audit_id_seq TO groups_v2_app;
 SELECT setval('users_id_seq',1000);SELECT setval('groups_id_seq',1000);SELECT setval('sidebar_id_seq',21);`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED"}`))
}
func groupsV2Handler(id string, db *gorm.DB, s groupsV2Secrets) http.Handler {
	database.DB = db
	cfg := config.Config{JWTSecret: s.JWT, JWTExpireMinutes: 120, UsersSecurityEnabled: true}
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.POST("/api/v1/auth/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	me := controllers.NewMeController()
	auth := middleware.JWTAuth(cfg)
	admin := controllers.NewAdministrationController(cfg)
	r.GET("/api/v1/auth/me", auth, me.Me)
	r.GET("/api/v1/auth/me/sidebar-access", auth, me.SidebarAccess)
	r.GET("/api/v1/groups", auth, admin.Guard("groups", "read"), admin.Groups)
	r.GET("/api/v1/groups/:id", auth, admin.Guard("groups", "read"), admin.GroupDetail)
	r.GET("/api/v1/groups/:id/sidebar-access", auth, admin.Guard("groups", "read"), admin.GroupAccess)
	r.PUT("/api/v1/groups/:id/sidebar-access", auth, admin.Guard("groups", "update"), admin.Grants)
	r.GET("/api/v1/users/assignable-groups", auth, admin.Guard("users", "read"), admin.Assignable)
	r.GET("/api/v1/development/groups-v2", auth, func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		var account struct{ ID, GroupID uint }
		uid, _ := c.Get("user_id")
		if e != nil || db.Table("users").Select("id,group_id").Where("id=? AND status=1", uid).Take(&account).Error != nil || name != groupsV2ManifestFor(id).Database || host != "127.0.0.1" || port != groupsV2PG || marker != "NOTARIS GROUPS V2 DISPOSABLE "+id {
			c.JSON(503, gin.H{"code": "users_target_mismatch"})
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": "groups-v2/" + id, "database": name, "host": host, "port": port, "marker": marker, "account_id": account.ID, "group_id": account.GroupID, "cloud_sync": false})
	})
	for _, action := range []string{"read", "create", "update", "delete"} {
		r.GET("/api/v1/development/groups-v2/probe/"+action, auth, middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "petugas", action), func(c *gin.Context) { c.JSON(200, gin.H{"allowed": true}) })
	}
	return http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, q)
	})
}
func groupsV2Login(client *http.Client, base, name, pwd string) (string, error) {
	b, _ := json.Marshal(map[string]string{"username": name, "password": pwd})
	res, e := client.Post(base+"/api/v1/auth/login", "application/json", strings.NewReader(string(b)))
	if e != nil {
		return "", rejected
	}
	defer res.Body.Close()
	var v struct{ Data struct{ Token string } }
	if res.StatusCode != 200 || json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&v) != nil || v.Data.Token == "" {
		return "", rejected
	}
	return v.Data.Token, nil
}
func groupsV2Client() *http.Client {
	return &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: nil}, CheckRedirect: func(*http.Request, []*http.Request) error { return rejected }}
}
func groupsV2HTTPCheck(id string, s groupsV2Secrets, base string) error {
	client := groupsV2Client()
	token, e := groupsV2Login(client, base, "admin.groups", s.Passwords["admin.groups"])
	if e != nil {
		return e
	}
	for _, path := range []string{"/api/v1/development/groups-v2", "/api/v1/groups?page=1&page_size=10"} {
		q, _ := http.NewRequest("GET", base+path, nil)
		q.Header.Set("Authorization", "Bearer "+token)
		res, e := client.Do(q)
		if e != nil {
			return rejected
		}
		var v map[string]any
		e = json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&v)
		res.Body.Close()
		if e != nil || res.StatusCode != 200 {
			return rejected
		}
		if strings.Contains(path, "development") && (v["profile"] != id || v["account_id"] != float64(101) || v["group_id"] != float64(101)) {
			return rejected
		}
	}
	return nil
}
func groupsV2State(db *gorm.DB) (map[string]any, error) {
	if (services.Administration{DB: db, Enabled: true}).Ready(context.Background()) != nil {
		return nil, rejected
	}
	hashes := map[string]string{}
	for key, query := range map[string]string{
		"sidebar":          "SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM sidebar t",
		"grants":           "SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM sidebar_akses t WHERE group_id<>201 OR sidebar_id IN(20,21)",
		"protected_groups": "SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM (SELECT * FROM groups WHERE id<>201)t",
		"user_identity":    "SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM (SELECT id,group_id,username,email,nama,password,status,revision,created_at,created_by,updated_at,updated_by,image,no_telp,alamat FROM users)t",
	} {
		var raw string
		if db.Raw(query).Scan(&raw).Error != nil {
			return nil, rejected
		}
		h := sha256.Sum256([]byte(raw))
		hashes[key] = hex.EncodeToString(h[:])
	}
	groupsV2 := []map[string]any{}
	users := []map[string]any{}
	audits := []map[string]any{}
	if db.Raw("SELECT id,group_nama,group_jenis,status,revision FROM groups ORDER BY id").Scan(&groupsV2).Error != nil {
		return nil, rejected
	}
	if db.Raw("SELECT id,group_id,status,revision,security_version FROM users ORDER BY id").Scan(&users).Error != nil {
		return nil, rejected
	}
	counts := []map[string]any{}
	if db.Raw("SELECT group_id,count(*) AS count FROM sidebar_akses GROUP BY group_id ORDER BY group_id").Scan(&counts).Error != nil {
		return nil, rejected
	}
	if db.Raw("SELECT id,actor_id,target_id,target_type,action,result,reason_code,request_id,before_state,after_state FROM administrative_audit ORDER BY id").Scan(&audits).Error != nil {
		return nil, rejected
	}
	var bad int64
	if db.Raw(`SELECT (SELECT count(*) FROM users u LEFT JOIN groups g ON g.id=u.group_id WHERE g.id IS NULL OR u.revision<1 OR u.security_version<1)+(SELECT count(*) FROM sidebar_akses a LEFT JOIN groups g ON g.id=a.group_id LEFT JOIN sidebar s ON s.id=a.sidebar_id WHERE g.id IS NULL OR s.id IS NULL)+(SELECT count(*) FROM pg_constraint WHERE NOT convalidated AND connamespace='public'::regnamespace)`).Scan(&bad).Error != nil || bad != 0 {
		return nil, rejected
	}
	snapshot, e := (services.Administration{DB: db, Enabled: true}).GroupAccess(context.Background(), services.AdminActor{ID: 101, Version: 1}, 201)
	if e != nil {
		return nil, rejected
	}
	return map[string]any{"grant_counts": counts, "access": snapshot, "groups": groupsV2, "users": users, "audits": audits, "fingerprints": hashes, "integrity": "PASS", "recovery": "PASS"}, nil
}
func runGroupsV2(args []string) error {
	if len(args) == 1 && args[0] == "groups-v2-init" {
		return groupsV2Init()
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, s, e := groupsV2Root(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "groups-v2-bootstrap":
		return groupsV2Bootstrap(id)
	case "groups-v2-validate":
		return json.NewEncoder(os.Stdout).Encode(groupsV2ManifestFor(id))
	case "groups-v2-credential":
		if len(args) != 3 || s.Passwords[args[2]] == "" {
			return rejected
		}
		content, _ := windows.UTF16PtrFromString(args[2] + "\n" + s.Passwords[args[2]])
		title, _ := windows.UTF16PtrFromString("Groups V2 · kredensial disposable · jangan rekam dialog")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	db, e := groupsV2Open(id, args[0] == "groups-v2-state", false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	switch args[0] {
	case "groups-v2-state":
		state, e := groupsV2State(db)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(state)
	case "groups-v2-http-check":
		if e = groupsV2HTTPCheck(id, s, "http://127.0.0.1:55885"); e != nil {
			return e
		}
		fmt.Println(`{"http":"PASS"}`)
		return nil
	case "groups-v2-probe":
		client := groupsV2Client()
		base := "http://127.0.0.1:55885"
		if groupsV2HTTPCheck(id, s, base) != nil {
			return rejected
		}
		token, e := groupsV2Login(client, base, "admin.biasa", s.Passwords["admin.biasa"])
		if e != nil {
			return e
		}
		result := map[string]int{}
		for _, action := range []string{"read", "create", "update", "delete"} {
			q, _ := http.NewRequest("GET", base+"/api/v1/development/groups-v2/probe/"+action, nil)
			q.Header.Set("Authorization", "Bearer "+token)
			r, e := client.Do(q)
			if e != nil {
				return rejected
			}
			r.Body.Close()
			if r.StatusCode != 200 && r.StatusCode != 403 {
				return rejected
			}
			result[action] = r.StatusCode
		}
		return json.NewEncoder(os.Stdout).Encode(result)
	case "groups-v2-self-check":
		server := httptest.NewServer(groupsV2Handler(id, db, s))
		defer server.Close()
		return groupsV2HTTPCheck(id, s, server.URL)
	case "groups-v2-serve":
		if (services.Administration{DB: db, Enabled: true}).Ready(context.Background()) != nil {
			return rejected
		}
		listener, e := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(groupsV2HTTP))
		if e != nil {
			return rejected
		}
		fmt.Println("GROUPS_V2_BACKEND_READY scope=groups-v2/" + id)
		return (&http.Server{Handler: groupsV2Handler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	case "groups-v2-conflict":
		// Explicit one-time ordinary target update, never an implicit postcheck write.
		if e = writeNew(filepath.Join(root, "conflict-attempted.lock"), []byte(id)); e != nil {
			return rejected
		}
		client := groupsV2Client()
		token, e := groupsV2Login(client, "http://127.0.0.1:55885", "admin.groups", s.Passwords["admin.groups"])
		if e != nil {
			return e
		}
		q, _ := http.NewRequest("GET", "http://127.0.0.1:55885/api/v1/groups/201/sidebar-access", nil)
		q.Header.Set("Authorization", "Bearer "+token)
		got, e := client.Do(q)
		if e != nil {
			return rejected
		}
		var payload struct{ Data services.GroupAccessSnapshot }
		e = json.NewDecoder(io.LimitReader(got.Body, 1<<20)).Decode(&payload)
		got.Body.Close()
		if e != nil || got.StatusCode != 200 || payload.Data.Group.ID != 201 || payload.Data.Group.Revision != 3 {
			return rejected
		}
		items := []request.SidebarAccessItem{}
		for _, row := range payload.Data.Entries {
			if row.Editable {
				p := request.SidebarAccessItem{SidebarID: row.Sidebar.ID}
				if p.SidebarID == 4 {
					p.Read = 1
				}
				items = append(items, p)
			}
		}
		body, _ := json.Marshal(map[string]any{"expected_revision": 3, "catalog_fingerprint": payload.Data.Catalog, "access": items})
		q, _ = http.NewRequest("PUT", "http://127.0.0.1:55885/api/v1/groups/201/sidebar-access", strings.NewReader(string(body)))
		q.Header.Set("Authorization", "Bearer "+token)
		q.Header.Set("Content-Type", "application/json")
		res, e := client.Do(q)
		if e != nil {
			return rejected
		}
		defer res.Body.Close()
		if res.StatusCode != 200 {
			return rejected
		}
		fmt.Println("GROUPS_V2_CONCURRENT_EDIT_COMMITTED")
		return nil
	}
	return rejected
}
