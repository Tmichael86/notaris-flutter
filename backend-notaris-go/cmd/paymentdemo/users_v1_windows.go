package main

// New, Windows-owner-bound Users acceptance only. No caller-selected DSN,
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

const usersPG = 55795
const usersHTTP = 55883

type usersSecrets struct {
	Owner, App, JWT, Migration string
	Passwords                  map[string]string
}
type usersManifest struct {
	Profile, Scope, Database, BaseURL string
	Port, Schema                      int
}

func usersManifestFor(id string) usersManifest {
	return usersManifest{id, "users-v1/" + id, "users_v1_" + id, "http://127.0.0.1:55883/api/v1", usersPG, 27}
}
func usersRoot(id string) (string, usersSecrets, error) {
	var s usersSecrets
	root, e := profileRoot(id)
	if e != nil {
		return "", s, rejected
	}
	resolved, e := filepath.EvalSymlinks(root)
	if e != nil || !strings.EqualFold(resolved, root) {
		return "", s, rejected
	}
	marker, e := readOwnedFile(root, "users-v1-owner")
	if e != nil || string(marker) != id {
		return "", s, rejected
	}
	if unseal(root, id, "users-v1-secrets", &s) != nil {
		return "", s, rejected
	}
	raw, e := readOwnedFile(root, "users-v1.json")
	var m usersManifest
	if e != nil || json.Unmarshal(raw, &m) != nil || m != usersManifestFor(id) {
		return "", s, rejected
	}
	return root, s, nil
}
func usersInit() error {
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
	for n, v := range map[string][]byte{"owner": []byte(id), "users-v1-owner": []byte(id), "public.key": pub} {
		if e = writeNew(filepath.Join(root, n), v); e != nil {
			return e
		}
	}
	sum := sha256.Sum256(migration)
	s := usersSecrets{hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(32)), hex.EncodeToString(randomBytes(32)), hex.EncodeToString(sum[:]), map[string]string{}}
	for _, name := range []string{"admin.users", "recovery.users", "admin.biasa", "petugas.users", "operator.baru", "reset.operator.02"} {
		s.Passwords[name] = hex.EncodeToString(randomBytes(18))
	}
	for i := 1; i <= 12; i++ {
		s.Passwords[fmt.Sprintf("operator.%02d", i)] = hex.EncodeToString(randomBytes(18))
	}
	s.Passwords["inactive.users"] = hex.EncodeToString(randomBytes(18))
	if e = seal(root, id, "users-v1-secrets", s, priv); e != nil {
		return e
	}
	if e = writeNew(filepath.Join(root, "initdb-password"), []byte(s.Owner+"\n")); e != nil {
		return e
	}
	raw, _ := json.Marshal(usersManifestFor(id))
	if e = writeNew(filepath.Join(root, "users-v1.json"), raw); e != nil {
		return e
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"profile": id, "root": root})
}
func usersOpen(id string, owner, bootstrap bool) (*gorm.DB, error) {
	root, s, e := usersRoot(id)
	if e != nil {
		return nil, e
	}
	m := usersManifestFor(id)
	name := m.Database
	role, pwd := "users_app", s.App
	if owner {
		role, pwd = "users_owner", s.Owner
	}
	if bootstrap {
		if !owner {
			return nil, rejected
		}
		name = "postgres"
	}
	db, e := gorm.Open(postgres.Open(fmt.Sprintf("host=127.0.0.1 port=%d user=%s password=%s dbname=%s sslmode=disable connect_timeout=3", usersPG, role, pwd, name)), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
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
	if e != nil || actual != name || host != "127.0.0.1" || port != usersPG || who != role {
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
	if !bootstrap && marker != "NOTARIS USERS V1 DISPOSABLE "+id {
		pool.Close()
		return nil, rejected
	}
	return db, nil
}
func usersBootstrap(id string) error {
	root, s, e := usersRoot(id)
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
	owner, e := usersOpen(id, true, true)
	if e != nil {
		return e
	}
	defer closePromo(owner)
	name := usersManifestFor(id).Database
	for _, sql := range []string{"CREATE DATABASE " + name, "COMMENT ON DATABASE " + name + " IS 'NOTARIS USERS V1 DISPOSABLE " + id + "'", "CREATE ROLE users_app LOGIN PASSWORD '" + s.App + "'"} {
		if owner.Exec(sql).Error != nil {
			return rejected
		}
	}
	db, e := usersOpen(id, true, false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	e = db.Transaction(func(tx *gorm.DB) error {
		ddl := `CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index integer,status smallint);
 CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,sidebar_id bigint,group_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(101,'Administrator Uji','superadmin',1),(102,'Pemulihan Terproteksi','superadmin',1),(201,'Operasional','user',1),(202,'Pelayanan','user',1),(203,'Arsip','user',1),(204,'Nonaktif','user',0);
 INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_index,status) VALUES(1,'Users','users','/users',1,1),(2,'Groups','groups','/groups',2,1),(3,'Sidebars','sidebars','/sidebars',3,1),(4,'Petugas','petugas','/petugas',4,1);
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT s,g,1,1,1,1 FROM generate_series(1,4)s CROSS JOIN (VALUES(101),(102))v(g);
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT 1,g,1,1,1,1 FROM (VALUES(201),(202))v(g);
 INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") SELECT 4,g,1,0,0,0 FROM (VALUES(201),(202))v(g);`
		if e := tx.Exec(ddl).Error; e != nil {
			return e
		}
		type fixture struct {
			id, group      int
			username, name string
			status         int
		}
		rows := []fixture{{101, 101, "admin.users", "Administrator Uji", 1}, {102, 102, "recovery.users", "Pemulihan Terproteksi", 1}, {201, 201, "admin.biasa", "Admin Biasa", 1}, {202, 202, "petugas.users", "Petugas Pelayanan", 1}, {399, 201, "inactive.users", "Akun Nonaktif", 0}}
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
		if e := tx.Exec(`REVOKE ALL ON SCHEMA public FROM PUBLIC;GRANT USAGE ON SCHEMA public TO users_app;
 GRANT SELECT ON users,groups,sidebar,sidebar_akses TO users_app;GRANT INSERT,UPDATE ON users TO users_app;
 GRANT INSERT ON administrative_audit TO users_app;GRANT USAGE ON SEQUENCE users_id_seq,administrative_audit_id_seq TO users_app;
 SELECT setval('users_id_seq',1000);SELECT setval('groups_id_seq',204);SELECT setval('sidebar_id_seq',4);`).Error; e != nil {
			return e
		}
		return (services.Administration{DB: tx, Enabled: true}).Ready(context.Background())
	})
	if e != nil {
		return rejected
	}
	return writeNew(filepath.Join(root, "bootstrap-committed.json"), []byte(`{"status":"COMMITTED"}`))
}
func usersHandler(id string, db *gorm.DB, s usersSecrets) http.Handler {
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
	r.GET("/api/v1/users", auth, admin.Guard("users", "read"), admin.Users)
	r.GET("/api/v1/users/assignable-groups", auth, admin.Guard("users", "read"), admin.Assignable)
	r.GET("/api/v1/users/:id", auth, admin.Guard("users", "read"), admin.User)
	r.POST("/api/v1/users", auth, admin.Guard("users", "create"), admin.CreateUser)
	r.PUT("/api/v1/users/:id", auth, admin.Guard("users", "update"), admin.UpdateUser)
	r.DELETE("/api/v1/users/:id", auth, admin.Guard("users", "delete"), admin.UserSecurity)
	r.POST("/api/v1/users/:id/password-reset", auth, admin.Guard("users", "update"), admin.UserSecurity)
	r.GET("/api/v1/development/users-v1", auth, func(c *gin.Context) {
		var name, host, marker string
		var port int
		e := db.Raw(`SELECT current_database(),host(inet_server_addr()),inet_server_port(),shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()`).Row().Scan(&name, &host, &port, &marker)
		var account struct{ ID, GroupID uint }
		uid, _ := c.Get("user_id")
		if e != nil || db.Table("users").Select("id,group_id").Where("id=? AND status=1", uid).Take(&account).Error != nil || name != usersManifestFor(id).Database || host != "127.0.0.1" || port != usersPG || marker != "NOTARIS USERS V1 DISPOSABLE "+id {
			c.JSON(503, gin.H{"code": "users_target_mismatch"})
			return
		}
		c.JSON(200, gin.H{"profile": id, "scope": "users-v1/" + id, "database": name, "host": host, "port": port, "marker": marker, "account_id": account.ID, "group_id": account.GroupID, "cloud_sync": false})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, q *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		r.ServeHTTP(w, q)
	})
}
func usersLogin(client *http.Client, base, name, pwd string) (string, error) {
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
func usersClient() *http.Client {
	return &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: nil}, CheckRedirect: func(*http.Request, []*http.Request) error { return rejected }}
}
func usersHTTPCheck(id string, s usersSecrets, base string) error {
	client := usersClient()
	token, e := usersLogin(client, base, "admin.users", s.Passwords["admin.users"])
	if e != nil {
		return e
	}
	for _, path := range []string{"/api/v1/development/users-v1", "/api/v1/users?page=1&page_size=10"} {
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
func usersState(db *gorm.DB) (map[string]any, error) {
	if (services.Administration{DB: db, Enabled: true}).Ready(context.Background()) != nil {
		return nil, rejected
	}
	result := map[string]any{}
	hashes := map[string]string{}
	for _, t := range []string{"groups", "sidebar", "sidebar_akses"} {
		var rows string
		if db.Raw("SELECT coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'') FROM "+t+" t").Scan(&rows).Error != nil {
			return nil, rejected
		}
		h := sha256.Sum256([]byte(rows))
		hashes[t] = hex.EncodeToString(h[:])
	}
	var users []map[string]any
	if db.Raw("SELECT id,group_id,username,email,nama,status,revision,security_version FROM users ORDER BY id").Scan(&users).Error != nil {
		return nil, rejected
	}
	audits := []map[string]any{}
	if db.Raw("SELECT id,actor_id,target_id,target_type,action,result,reason_code,request_id,before_state,after_state FROM administrative_audit ORDER BY id").Scan(&audits).Error != nil {
		return nil, rejected
	}
	// Hash passwords internally, never expose bcrypt or account credentials.
	var protected string
	if db.Raw(`SELECT string_agg(row_to_json(t)::text,E'\n' ORDER BY id) FROM (SELECT * FROM users WHERE id NOT IN(301,302,1001))t`).Scan(&protected).Error != nil {
		return nil, rejected
	}
	h := sha256.Sum256([]byte(protected))
	hashes["protected_users"] = hex.EncodeToString(h[:])
	// Permit only the approved fields on the two mutable existing targets.
	for key, query := range map[string]string{
		"target301_identity": "SELECT row_to_json(t)::text FROM (SELECT id,group_id,username,email,password,status,security_version,created_at,created_by,image,no_telp,alamat FROM users WHERE id=301)t",
		"target302_identity": "SELECT row_to_json(t)::text FROM (SELECT id,group_id,username,email,nama,status,created_at,created_by,image,no_telp,alamat FROM users WHERE id=302)t",
	} {
		var value string
		if db.Raw(query).Scan(&value).Error != nil {
			return nil, rejected
		}
		sum := sha256.Sum256([]byte(value))
		hashes[key] = hex.EncodeToString(sum[:])
	}
	var bad int64
	err := db.Raw(`SELECT count(*) FROM users u LEFT JOIN groups g ON g.id=u.group_id WHERE g.id IS NULL OR u.revision<1 OR u.security_version<1`).Scan(&bad).Error
	if err != nil || bad != 0 {
		return nil, rejected
	}
	var valid int64
	err = db.Raw("SELECT count(*) FROM pg_constraint WHERE NOT convalidated AND connamespace='public'::regnamespace").Scan(&valid).Error
	if err != nil || valid != 0 {
		return nil, rejected
	}
	result["users"] = users
	result["audits"] = audits
	result["fingerprints"] = hashes
	result["integrity"] = "PASS"
	result["recovery"] = "PASS"
	return result, nil
}
func runUsersV1(args []string) error {
	if len(args) == 1 && args[0] == "users-v1-init" {
		return usersInit()
	}
	if len(args) < 2 || len(args) > 3 {
		return rejected
	}
	id := args[1]
	root, s, e := usersRoot(id)
	if e != nil {
		return e
	}
	switch args[0] {
	case "users-v1-bootstrap":
		return usersBootstrap(id)
	case "users-v1-validate":
		return json.NewEncoder(os.Stdout).Encode(usersManifestFor(id))
	case "users-v1-credential":
		if len(args) != 3 || s.Passwords[args[2]] == "" {
			return rejected
		}
		content, _ := windows.UTF16PtrFromString(args[2] + "\n" + s.Passwords[args[2]])
		title, _ := windows.UTF16PtrFromString("Users V1 · kredensial disposable · jangan rekam dialog")
		windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(content)), uintptr(unsafe.Pointer(title)), 0x10000)
		return nil
	}
	if _, e = readOwnedFile(root, "bootstrap-committed.json"); e != nil {
		return rejected
	}
	db, e := usersOpen(id, args[0] == "users-v1-state", false)
	if e != nil {
		return e
	}
	defer closePromo(db)
	switch args[0] {
	case "users-v1-state":
		var target struct {
			Password        string
			SecurityVersion int64
		}
		if db.Table("users").Select("password,security_version").Where("id=302").Take(&target).Error != nil {
			return rejected
		}
		if target.SecurityVersion == 2 && (bcrypt.CompareHashAndPassword([]byte(target.Password), []byte(s.Passwords["reset.operator.02"])) != nil || bcrypt.CompareHashAndPassword([]byte(target.Password), []byte(s.Passwords["operator.02"])) == nil) {
			return rejected
		}
		state, e := usersState(db)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(state)
	case "users-v1-http-check":
		if e = usersHTTPCheck(id, s, "http://127.0.0.1:55883"); e != nil {
			return e
		}
		fmt.Println(`{"http":"PASS"}`)
		return nil
	case "users-v1-reset-capture":
		var revision int64
		if db.Table("users").Select("revision").Where("id=302 AND security_version=1 AND status=1").Scan(&revision).Error != nil || revision != 1 {
			return rejected
		}
		token, e := usersLogin(usersClient(), "http://127.0.0.1:55883", "operator.02", s.Passwords["operator.02"])
		if e != nil {
			return e
		}
		cipher, e := dpapi([]byte(token), []byte("users-v1/reset-proof/"+id), true)
		if e != nil {
			return e
		}
		if e = writeNew(filepath.Join(root, "reset-old-session.bin"), cipher); e != nil {
			return e
		}
		fmt.Println("USERS_V1_RESET_SESSION_CAPTURED")
		return nil
	case "users-v1-reset-proof":
		raw, e := readOwnedFile(root, "reset-old-session.bin")
		if e != nil {
			return e
		}
		plain, e := dpapi(raw, []byte("users-v1/reset-proof/"+id), false)
		if e != nil {
			return e
		}
		defer clear(plain)
		claims := &services.Claims{}
		token, e := jwt.ParseWithClaims(string(plain), claims, func(*jwt.Token) (any, error) { return []byte(s.JWT), nil }, jwt.WithValidMethods([]string{"HS256"}), jwt.WithIssuer("backend-notaris-go"), jwt.WithExpirationRequired())
		if e != nil || !token.Valid || claims.UID != 302 || claims.Version == nil || *claims.Version != 1 {
			return rejected
		}
		q, _ := http.NewRequest("GET", "http://127.0.0.1:55883/api/v1/auth/me", nil)
		q.Header.Set("Authorization", "Bearer "+string(plain))
		res, e := usersClient().Do(q)
		if e != nil {
			return rejected
		}
		defer res.Body.Close()
		if res.StatusCode != 401 {
			return rejected
		}
		fmt.Println("USERS_V1_RESET_REVOCATION_PASS")
		return nil
	case "users-v1-self-check":
		server := httptest.NewServer(usersHandler(id, db, s))
		defer server.Close()
		return usersHTTPCheck(id, s, server.URL)
	case "users-v1-serve":
		if (services.Administration{DB: db, Enabled: true}).Ready(context.Background()) != nil {
			return rejected
		}
		listener, e := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(usersHTTP))
		if e != nil {
			return rejected
		}
		fmt.Println("USERS_V1_BACKEND_READY scope=users-v1/" + id)
		return (&http.Server{Handler: usersHandler(id, db, s), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}).Serve(listener)
	case "users-v1-conflict":
		// Explicit one-time ordinary target update, never an implicit postcheck write.
		if e = writeNew(filepath.Join(root, "conflict-attempted.lock"), []byte(id)); e != nil {
			return rejected
		}
		client := usersClient()
		token, e := usersLogin(client, "http://127.0.0.1:55883", "admin.users", s.Passwords["admin.users"])
		if e != nil {
			return e
		}
		q, _ := http.NewRequest("PUT", "http://127.0.0.1:55883/api/v1/users/301", strings.NewReader(`{"group_id":201,"nama":"Operator 01 Terbaru","username":"operator.01","email":"operator.01@example.invalid","expected_revision":1}`))
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
		fmt.Println("USERS_V1_CONCURRENT_EDIT_COMMITTED")
		return nil
	}
	return rejected
}
