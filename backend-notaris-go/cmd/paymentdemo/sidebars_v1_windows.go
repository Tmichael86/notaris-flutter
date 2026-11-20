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

const sidebarsV1PG = 55798
const sidebarsV1HTTP = 55886

func sidebarsV1Bootstrap(id string) error {
	root, s, e := sidebarsV1Root(id)
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
	owner, e := sidebarsV1Open(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(owner)
	name := sidebarsV1ManifestFor(id).Database
	for _, sql := range []string{"CREATE DATABASE " + name, "COMMENT ON DATABASE " + name + " IS 'NOTARIS SIDEBARS V1 DISPOSABLE " + id + "'", "CREATE ROLE sidebars_v1_app LOGIN PASSWORD '" + s.App + "'"} {
		if owner.Exec(sql).Error != nil {
			return rejected
		}
	}
	db, e := sidebarsV1Open(id, true, false)
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
		for _, u := range []struct {
			id   int
			name string
		}{{101, "admin.catalog"}, {102, "recovery.catalog"}, {201, "reader.catalog"}, {202, "denied.catalog"}} {
			hash, e := bcrypt.GenerateFromPassword([]byte(s.Passwords[u.name]), bcrypt.DefaultCost)
			if e != nil {
				return e
			}
			if e := tx.Exec("INSERT INTO users(id,group_id,username,email,nama,password,status) VALUES(?,?,?,?,?,?,1)", u.id, u.id, u.name, u.name+"@example.invalid", u.name, string(hash)).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(`INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT s.id,g,1,1,1,1 FROM sidebar s CROSS JOIN(VALUES(101),(102))v(g) WHERE s.status=1;
INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(3,201,1,0,0,0);`).Error; e != nil {
			return e
		}
		if e := tx.Exec(string(raw)).Error; e != nil {
			return e
		}
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC;GRANT USAGE ON SCHEMA public TO sidebars_v1_app;
GRANT SELECT ON users,groups,sidebar,sidebar_akses TO sidebars_v1_app;
ALTER ROLE sidebars_v1_app SET default_transaction_read_only=on;`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED"}`))
}
func sidebarsV1Handler(id string, db *gorm.DB, s sidebarsV1Secrets) http.Handler {
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
	catalog := controllers.NewSidebarController()
	permission := middleware.RequirePermission(repositories.NewSidebarAccessRepository(), "sidebars", "read")
	r.GET("/api/v1/sidebars/catalog", auth, permission, catalog.Catalog)
	r.GET("/api/v1/sidebars", auth, permission, catalog.GetAll)
	r.GET("/api/v1/sidebars/tree", auth, permission, catalog.GetTree)
	r.GET("/api/v1/sidebars/:id", auth, permission, catalog.GetByID)
	r.GET("/api/v1/development/sidebars-v1", auth, func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		var u struct{ ID, GroupID uint }
		uid, _ := c.Get("user_id")
		if e != nil || db.Table("users").Select("id,group_id").Where("id=? AND status=1", uid).Take(&u).Error != nil || name != sidebarsV1ManifestFor(id).Database || host != "127.0.0.1" || port != sidebarsV1PG || marker != "NOTARIS SIDEBARS V1 DISPOSABLE "+id {
			c.Status(503)
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": "sidebars-v1/" + id, "database": name, "host": host, "port": port, "marker": marker, "account_id": u.ID, "group_id": u.GroupID, "cloud_sync": false})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, q)
	})
}
func sidebarsV1HTTPCheck(id string, s sidebarsV1Secrets, base string) error {
	client := groupsV2Client()
	for _, name := range []string{"reader.catalog", "denied.catalog"} {
		token, e := groupsV2Login(client, base, name, s.Passwords[name])
		if e != nil {
			return e
		}
		for _, path := range []string{"/api/v1/development/sidebars-v1", "/api/v1/sidebars/catalog?page=1&page_size=10"} {
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
				if e != nil || res.StatusCode != 200 || v["profile"] != id || v["scope"] != "sidebars-v1/"+id {
					return rejected
				}
			} else if name == "denied.catalog" {
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
func runSidebarsV1(args []string) error {
	if len(args) == 1 && args[0] == "sidebars-v1-init" {
		return sidebarsV1Init()
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, s, e := sidebarsV1Root(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "sidebars-v1-bootstrap":
		return sidebarsV1Bootstrap(id)
	case "sidebars-v1-validate":
		return json.NewEncoder(os.Stdout).Encode(sidebarsV1ManifestFor(id))
	case "sidebars-v1-credential":
		if len(args) != 3 || s.Passwords[args[2]] == "" {
			return rejected
		}
		content, _ := windows.UTF16PtrFromString(args[2] + "\n" + s.Passwords[args[2]])
		title, _ := windows.UTF16PtrFromString("Sidebars V1 · kredensial disposable · jangan rekam dialog")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	db, e := sidebarsV1Open(id, args[0] == "sidebars-v1-state", false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	switch args[0] {
	case "sidebars-v1-state":
		v, e := groupsV2State(db)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(v)
	case "sidebars-v1-http-check":
		return sidebarsV1HTTPCheck(id, s, "http://127.0.0.1:55886")
	case "sidebars-v1-self-check":
		server := httptest.NewServer(sidebarsV1Handler(id, db, s))
		defer server.Close()
		return sidebarsV1HTTPCheck(id, s, server.URL)
	case "sidebars-v1-serve":
		listener, e := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(sidebarsV1HTTP))
		if e != nil {
			return rejected
		}
		fmt.Println("SIDEBARS_V1_BACKEND_READY scope=sidebars-v1/" + id)
		return (&http.Server{Handler: sidebarsV1Handler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	}
	return rejected
}

// Reuse reviewed DPAPI secret representation, never its profile or credentials.
type sidebarsV1Secrets = groupsV2Secrets
type sidebarsV1Manifest = groupsV2Manifest

func sidebarsV1ManifestFor(id string) groupsV2Manifest {
	return groupsV2Manifest{Profile: id, Scope: "sidebars-v1/" + id, Database: "sidebars_v1_" + id, BaseURL: "http://127.0.0.1:55886/api/v1", Port: sidebarsV1PG, Schema: 27, Catalog: "sidebars-v1"}
}
func sidebarsV1Root(id string) (string, sidebarsV1Secrets, error) {
	var s sidebarsV1Secrets
	root, e := profileRoot(id)
	if e != nil {
		return "", s, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", s, rejected
	}
	marker, e := readOwnedFile(root, "sidebars-v1-owner")
	if e != nil || string(marker) != id {
		return "", s, rejected
	}
	if unseal(root, id, "sidebars-v1-secrets", &s) != nil {
		return "", s, rejected
	}
	raw, e := readOwnedFile(root, "sidebars-v1.json")
	var m sidebarsV1Manifest
	if e != nil || json.Unmarshal(raw, &m) != nil || m != sidebarsV1ManifestFor(id) {
		return "", s, rejected
	}
	return root, s, nil
}
func sidebarsV1Init() error {
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
	for n, v := range map[string][]byte{"owner": []byte(id), "sidebars-v1-owner": []byte(id), "public.key": pub} {
		if e = writeNew(filepath.Join(root, n), v); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	s := sidebarsV1Secrets{Owner: hex.EncodeToString(randomBytes(32)), App: hex.EncodeToString(randomBytes(32)), JWT: hex.EncodeToString(randomBytes(32)), Migration: hex.EncodeToString(sum[:]), Passwords: map[string]string{}, FullCatalog: false}
	for _, name := range []string{"admin.catalog", "recovery.catalog", "reader.catalog", "denied.catalog"} {
		s.Passwords[name] = hex.EncodeToString(randomBytes(18))
	}
	if e = seal(root, id, "sidebars-v1-secrets", s, priv); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(s.Owner+"\n")); e != nil {
		return e
	}
	raw, _ := json.Marshal(sidebarsV1ManifestFor(id))
	if e = writeNew(filepath.Join(root, "sidebars-v1.json"), raw); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root})
}
func sidebarsV1Open(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := sidebarsV1Root(id)
	if e != nil {
		return nil, e
	}
	m := sidebarsV1ManifestFor(id)
	name := m.Database
	role, pwd := "sidebars_v1_app", s.App
	if owner {
		role, pwd = "sidebars_v1_owner", s.Owner
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	db, e := gorm.Open(postgres.Open(fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", sidebarsV1PG, role, pwd, name)), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
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
	if e != nil || actual != name || host != "127.0.0.1" || port != sidebarsV1PG || who != role {
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
	if !bootstrap && marker != "NOTARIS SIDEBARS V1 DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}
