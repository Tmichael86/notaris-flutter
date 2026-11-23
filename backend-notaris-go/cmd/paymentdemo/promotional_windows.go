package main

// Dedicated online promotional profile. Existing offline acceptance commands,
// identities and signatures are unchanged. There is no public bootstrap route.
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
	"strings"
	"time"
	"unsafe"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/middleware"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"golang.org/x/sys/windows"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const promoPGPort = 55794
const promoHTTPPort = 55882
const promoUser = "superadmin.promo"
const promoActor = 104

type promotionalSecrets struct {
	OwnerPassword   string
	AppPassword     string
	JWTSecret       string
	LoginPassword   string
	MigrationSHA256 string
}
type promotionalManifest struct {
	Profile  string `json:"profile"`
	Database string `json:"database"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	BaseURL  string `json:"base_url"`
	Scope    string `json:"scope"`
	Schema   int    `json:"sqlite_schema"`
}

func promoManifest(id string) promotionalManifest {
	return promotionalManifest{id, "promotional_" + id, "127.0.0.1", promoPGPort,
		"http://127.0.0.1:55882/api/v1", "promotional/" + id, 27}
}
func promotionalRoot(id string) (string, promotionalSecrets, error) {
	var secrets promotionalSecrets
	root, e := profileRoot(id)
	if e != nil {
		return "", secrets, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", secrets, rejected
	}
	marker, e := readOwnedFile(root, "promotional-owner")
	if e != nil || string(marker) != id {
		return "", secrets, rejected
	}
	if e = unseal(root, id, "promotional-secrets", &secrets); e != nil {
		return "", secrets, rejected
	}
	raw, e := readOwnedFile(root, "promotional.json")
	var manifest promotionalManifest
	if e != nil || json.Unmarshal(raw, &manifest) != nil || manifest != promoManifest(id) {
		return "", secrets, rejected
	}
	return root, secrets, nil
}
func promoInit() error {
	migration, e := os.ReadFile("migration_proposals/20261119_users_security.sql")
	if e != nil {
		return rejected
	}
	public, private, e := ed25519.GenerateKey(rand.Reader)
	if e != nil {
		return e
	}
	defer clear(private)
	id := profileID(public)
	root, e := profileRoot(id)
	if e != nil {
		return e
	}
	if e = os.Mkdir(root, 0700); e != nil {
		return e
	}
	// Restrict inheritance before any plaintext initdb handoff is created.
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
	if e = windows.SetNamedSecurityInfo(root, windows.SE_FILE_OBJECT,
		windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION, nil, nil, dacl, nil); e != nil {
		return e
	}
	for name, value := range map[string][]byte{"owner": []byte(id), "promotional-owner": []byte(id), "public.key": public} {
		if e = writeNew(filepath.Join(root, name), value); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	secrets := promotionalSecrets{hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(32)),
		hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(18)), hex.EncodeToString(sum[:])}
	if e = seal(root, id, "promotional-secrets", secrets, private); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(secrets.OwnerPassword+"\n")); e != nil {
		return e
	}
	data, _ := json.Marshal(promoManifest(id))
	if e = writeNew(filepath.Join(root, "promotional.json"), data); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root, "manifest": promoManifest(id)})
}
func promoOpen(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := promotionalRoot(id)
	if e != nil {
		return nil, e
	}
	name := promoManifest(id).Database
	role, password := "promo_app", s.AppPassword
	if owner {
		role, password = "promo_owner", s.OwnerPassword
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	// No environment, service file, default DSN or caller-supplied host is accepted.
	dsn := fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", promoPGPort, role, password, name)
	db, e := gorm.Open(postgres.Open(dsn), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if e != nil {
		return nil, rejected
	}
	pool, e := db.DB()
	if e != nil {
		return nil, rejected
	}
	pool.SetMaxOpenConns(5)
	pool.SetConnMaxLifetime(5 * time.Minute)
	var actual, host, marker, roleName string
	var port int
	e = pool.QueryRow(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),current_user,
 coalesce(shobj_description(oid,'pg_database'),'') FROM pg_database WHERE datname=current_database()`).Scan(&actual, &host, &port, &roleName, &marker)
	if e != nil || actual != name || host != "127.0.0.1" || port != promoPGPort || roleName != role {
		pool.Close()
		return nil, rejected
	}
	if owner {
		var dir string
		e = pool.QueryRow("SHOW data_directory").Scan(&dir)
		expected := filepath.Join(root, "pgdata")
		resolved, err := filepath.EvalSymlinks(expected)
		if e != nil || err != nil || !strings.EqualFold(filepath.Clean(dir), expected) || !strings.EqualFold(resolved, expected) {
			pool.Close()
			return nil, rejected
		}
	}
	if !bootstrap && marker != "NOTARIS PROMOTIONAL DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}
func closePromo(db *gorm.DB) {
	if pool, e := db.DB(); e == nil {
		pool.Close()
	}
}
func promoBootstrap(id string) error {
	root, s, e := promotionalRoot(id)
	if e != nil {
		return e
	}
	migration, e := os.ReadFile("migration_proposals/20261119_users_security.sql")
	sum := sha256.Sum256(migration)
	if e != nil || hex.EncodeToString(sum[:]) != s.MigrationSHA256 {
		return rejected
	}
	// An attempted bootstrap is not retried automatically, including ambiguous DDL.
	if e = writeNew(filepath.Join(root, "bootstrap-attempted.lock"), []byte(id)); e != nil {
		return rejected
	}
	admin, e := promoOpen(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(admin)
	name := promoManifest(id).Database
	if e = admin.Exec("CREATE DATABASE " + name).Error; e != nil {
		return rejected
	}
	if e = admin.Exec("COMMENT ON DATABASE " + name + " IS 'NOTARIS PROMOTIONAL DISPOSABLE " + id + "'").Error; e != nil {
		return rejected
	}
	// Generated hexadecimal passwords cannot introduce SQL literals. DDL runs only
	// after data_directory and exact owned-cluster identity were verified above.
	if e = admin.Exec("CREATE ROLE promo_app LOGIN PASSWORD '" + s.AppPassword + "'").Error; e != nil {
		return rejected
	}
	db, e := promoOpen(id, true, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	hash, e := bcrypt.GenerateFromPassword([]byte(s.LoginPassword), bcrypt.DefaultCost)
	if e != nil {
		return e
	}
	e = db.Transaction(func(tx *gorm.DB) error {
		ddl := `CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
   CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
   CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index integer,status smallint);
   CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,sidebar_id bigint,group_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);`
		if e := tx.Exec(ddl).Error; e != nil {
			return e
		}
		if e := tx.Exec("INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(104,'Superadmin Promosi','superadmin',1)").Error; e != nil {
			return e
		}
		if e := tx.Exec("INSERT INTO users(id,group_id,username,email,nama,password,status) VALUES(104,104,?,'promo@example.invalid','Rani Wulandari',?,1)", promoUser, string(hash)).Error; e != nil {
			return e
		}
		for i, menu := range presentationMenus {
			create, update, remove := promotionalGrant(menu.code, menu.write)
			if e := tx.Exec("INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_index,status) VALUES(?,?,?,?,?,1)", i+1, menu.name, menu.code, "/"+menu.code, i+1).Error; e != nil {
				return e
			}
			if e := tx.Exec(`INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(?,104,1,?,?,?)`, i+1, create, update, remove).Error; e != nil {
				return e
			}
		}
		if e := tx.Exec(string(migration)).Error; e != nil {
			return e
		}
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC; GRANT USAGE ON SCHEMA public TO promo_app;
   GRANT SELECT ON users,groups,sidebar,sidebar_akses,administrative_audit TO promo_app;
   GRANT INSERT ON administrative_audit TO promo_app; GRANT USAGE ON SEQUENCE administrative_audit_id_seq TO promo_app;
   SELECT setval('users_id_seq',104); SELECT setval('groups_id_seq',104); SELECT setval('sidebar_id_seq',21);`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED","security_version":1}`))
}
func promoConfig(s promotionalSecrets) config.Config {
	return config.Config{JWTSecret: s.JWTSecret, JWTExpireMinutes: 120, UsersSecurityEnabled: true}
}
func promotionalGrant(code string, write int) (int, int, int) {
	if code == "users" || code == "groups" {
		return 1, 1, 1
	}
	if code == "laporan_materai" {
		return 1, 0, 0
	}
	return write, write, write
}
func promotionalAllowed(r *http.Request) bool {
	if r.Method == "POST" {
		return r.URL.Path == "/api/v1/auth/login"
	}
	if r.Method != "GET" || r.URL.RawQuery != "" {
		return false
	}
	switch r.URL.Path {
	case "/api/v1/health", "/api/v1/auth/me", "/api/v1/auth/me/sidebar-access", "/api/v1/development/promotional", "/api/v1/users", "/api/v1/groups", "/api/v1/sidebars":
		return true
	}
	return false
}
func promotionalHandler(id string, db *gorm.DB, s promotionalSecrets) http.Handler {
	database.DB = db
	cfg := promoConfig(s)
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/api/v1/health", func(c *gin.Context) { c.JSON(200, gin.H{"scope": promoManifest(id).Scope}) })
	r.POST("/api/v1/auth/login", controllers.NewAuthController(services.NewAuthService(cfg)).Login)
	me := controllers.NewMeController()
	auth := middleware.JWTAuth(cfg)
	r.GET("/api/v1/auth/me", auth, me.Me)
	r.GET("/api/v1/auth/me/sidebar-access", auth, me.SidebarAccess)
	admin := controllers.NewAdministrationController(cfg)
	r.GET("/api/v1/users", auth, admin.Guard("users", "read"), admin.Users)
	r.GET("/api/v1/groups", auth, admin.Guard("groups", "read"), controllers.NewGroupController().GetAll)
	r.GET("/api/v1/sidebars", auth, admin.Guard("sidebars", "read"), controllers.NewSidebarController().GetAll)
	r.GET("/api/v1/development/promotional", auth, admin.Guard("users", "read"), func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database() AS name, host(inet_server_addr()) AS host,
   inet_server_port() AS port,shobj_description(oid,'pg_database') AS marker FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		if e != nil || name != promoManifest(id).Database || host != "127.0.0.1" || port != promoPGPort || marker != "NOTARIS PROMOTIONAL DISPOSABLE "+id {
			c.JSON(503, gin.H{"code": "demo_target_mismatch"})
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": promoManifest(id).Scope, "database": name, "host": host, "port": port, "marker": marker, "account_id": promoActor, "group_id": promoActor, "security_version": 1, "http_writes": "auth_only", "cloud_sync": false})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, rq *http.Request) {
		if !promotionalAllowed(rq) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(403)
			io.WriteString(w, `{"code":"promotional_read_only"}`)
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, rq)
	})
}

// Verifies real HTTP auth and current DB permissions without printing JWTs.
func promotionalContext(id string, db *gorm.DB, s promotionalSecrets, base string) (verifiedSession, error) {
	payload := fmt.Sprintf(`{"username":%q,"password":%q}`, promoUser, s.LoginPassword)
	client := &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: nil}, CheckRedirect: func(*http.Request, []*http.Request) error { return rejected }}
	response, e := client.Post(base+"/api/v1/auth/login", "application/json", strings.NewReader(payload))
	if e != nil {
		return verifiedSession{}, rejected
	}
	defer response.Body.Close()
	var envelope struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	if response.StatusCode != 200 || json.NewDecoder(io.LimitReader(response.Body, 65536)).Decode(&envelope) != nil {
		return verifiedSession{}, rejected
	}
	claims := &services.Claims{}
	token, e := jwt.ParseWithClaims(envelope.Data.Token, claims, func(*jwt.Token) (any, error) { return []byte(s.JWTSecret), nil }, jwt.WithValidMethods([]string{"HS256"}), jwt.WithIssuer("backend-notaris-go"), jwt.WithExpirationRequired())
	if e != nil || !token.Valid || claims.UID != promoActor || claims.GID != promoActor || claims.Version == nil || *claims.Version != 1 {
		return verifiedSession{}, rejected
	}
	request, _ := http.NewRequest("GET", base+"/api/v1/auth/me/sidebar-access", nil)
	request.Header.Set("Authorization", "Bearer "+envelope.Data.Token)
	result, e := client.Do(request)
	if e != nil {
		return verifiedSession{}, rejected
	}
	defer result.Body.Close()
	var info struct {
		Data struct {
			User struct {
				ID        uint   `json:"id"`
				Group     uint   `json:"group_id"`
				Name      string `json:"nama"`
				Username  string `json:"username"`
				GroupName string `json:"group_nama"`
			} `json:"user"`
			Role     string   `json:"group_jenis"`
			Sidebars []access `json:"sidebars"`
		} `json:"data"`
	}
	if result.StatusCode != 200 || json.NewDecoder(io.LimitReader(result.Body, 65536)).Decode(&info) != nil {
		return verifiedSession{}, rejected
	}
	d := info.Data
	if d.User.ID != promoActor || d.User.Group != promoActor || d.User.Username != promoUser || d.Role != "superadmin" || len(d.Sidebars) != len(presentationMenus) {
		return verifiedSession{}, rejected
	}
	for _, menu := range presentationMenus {
		found := 0
		create, update, remove := promotionalGrant(menu.code, menu.write)
		for _, p := range d.Sidebars {
			if p.Sidebar.Code == menu.code && p.Sidebar.Name == menu.name && p.Read == 1 && p.Sidebar.Status == 1 && p.Create == create && p.Update == update && p.Delete == remove {
				found++
			}
		}
		if found != 1 {
			return verifiedSession{}, rejected
		}
	}
	if e := (services.Administration{DB: db, Enabled: true}).Ready(context.Background()); e != nil {
		return verifiedSession{}, rejected
	}
	return verifiedSession{id, promoUser, promoActor, promoActor, d.User.Name, d.User.GroupName, d.Role, time.Now().UTC(), claims.ExpiresAt.Time, d.Sidebars}, nil
}
func runPromotional(args []string) error {
	if len(args) == 1 && args[0] == "promo-init" {
		return promoInit()
	}
	if len(args) != 2 {
		return rejected
	}
	id := args[1]
	root, s, e := promotionalRoot(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "promo-bootstrap":
		return promoBootstrap(id)
	case "promo-credential":
		content, _ := windows.UTF16PtrFromString(promoUser + "\n" + s.LoginPassword)
		title, _ := windows.UTF16PtrFromString("Kredensial promosi terisolasi · tutup sebelum rekaman")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	case "promo-validate-profile":
		return json.NewEncoder(os.Stdout).Encode(promoManifest(id))
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	owner := args[0] == "promo-db-check"
	db, e := promoOpen(id, owner, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	if e = (services.Administration{DB: db, Enabled: true}).Ready(context.Background()); e != nil {
		return e
	}
	switch args[0] {
	case "promo-db-check":
		var count int64
		db.Table("users").Count(&count)
		if count != 1 {
			return rejected
		}
		hashes := map[string]string{}
		for _, table := range []string{"users", "groups", "sidebar", "sidebar_akses", "administrative_audit"} {
			var rows string
			if e = db.Raw("SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM " + table + " t").Scan(&rows).Error; e != nil {
				return rejected
			}
			sum := sha256.Sum256([]byte(rows))
			hashes[table] = hex.EncodeToString(sum[:])
		}
		var canUpdate bool
		if e = db.Raw("SELECT has_table_privilege('promo_app','users','UPDATE')").Scan(&canUpdate).Error; e != nil || canUpdate {
			return rejected
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"database": promoManifest(id).Database, "scope": promoManifest(id).Scope, "security_version": 1, "users": count, "recovery": "PASS", "fingerprints": hashes, "app_business_write": false})
	case "promo-fixture-context":
		server := httptest.NewServer(promotionalHandler(id, db, s))
		defer server.Close()
		info, e := promotionalContext(id, db, s, server.URL)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(info)
	case "promo-http-check":
		info, e := promotionalContext(id, db, s, "http://127.0.0.1:55882")
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "role": info.GroupType, "menus": len(info.Sidebars), "expires_at": info.ExpiresAt, "http": "PASS"})
	case "promo-serve":
		listener, e := net.Listen("tcp4", fmt.Sprintf("127.0.0.1:%d", promoHTTPPort))
		if e != nil {
			return rejected
		}
		fmt.Println("PROMOTIONAL_BACKEND_READY scope=" + promoManifest(id).Scope)
		return (&http.Server{Handler: promotionalHandler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	}
	return rejected
}
