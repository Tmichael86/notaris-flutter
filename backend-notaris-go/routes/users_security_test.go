package routes

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"backend-notaris-go/config"
	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type usersFixture struct {
	db  *gorm.DB
	api *gin.Engine
	cfg config.Config
}

func usersSetup(t *testing.T) usersFixture {
	return usersSetupBeforeP0(t, nil)
}

// Reuse the same owned cluster/schema and proposal for legacy type coverage.
func usersSetupBeforeP0(t *testing.T, prepare func(*gorm.DB)) usersFixture {
	t.Helper()
	dsn := os.Getenv("NOTARIS_USERS_SECURITY_TEST_DSN")
	if dsn == "" {
		t.Skip("owned Users PostgreSQL DSN unset")
	}
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil || cfg.Host != "127.0.0.1" || cfg.Port != 55793 || cfg.Database != "users_security_disposable" {
		t.Fatal("owned Users cluster required")
	}
	pool := stdlib.OpenDB(*cfg)
	t.Cleanup(func() { pool.Close() })
	var marker string
	if err = pool.QueryRow("SELECT shobj_description(oid,'pg_database') FROM pg_database WHERE datname=current_database()").Scan(&marker); err != nil || marker != "NOTARIS USERS SECURITY DISPOSABLE" {
		t.Fatal("marker mismatch")
	}
	schema := fmt.Sprintf("users_%d", time.Now().UnixNano())
	if _, err = pool.Exec("CREATE SCHEMA " + schema); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pool.Exec("DROP SCHEMA " + schema + " CASCADE") })
	cfg.RuntimeParams["search_path"] = schema
	scoped := stdlib.OpenDB(*cfg)
	t.Cleanup(func() { scoped.Close() })
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: scoped}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	old := database.DB
	database.DB = db
	t.Cleanup(func() { database.DB = old })
	ddl := `CREATE TABLE groups(id bigserial PRIMARY KEY,group_nama text,group_jenis text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE users(id bigserial PRIMARY KEY,group_id bigint,username text,email text,password text,nama text,no_telp text,alamat text,image text,status smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 CREATE TABLE sidebar(id bigserial PRIMARY KEY,sidebar_parent_id bigint,sidebar_nama text,sidebar_kode text,sidebar_route text,sidebar_icon text,sidebar_index int,status smallint);
 CREATE TABLE sidebar_akses(id bigserial PRIMARY KEY,group_id bigint,sidebar_id bigint,"read" smallint,"create" smallint,"update" smallint,"delete" smallint,created_by bigint,updated_by bigint,created_at timestamptz,updated_at timestamptz);
 INSERT INTO groups VALUES(1,'Recovery','superadmin',1),(2,'Operator','user',1),(3,'No grants','superadmin',1),(4,'Inactive','user',0);
 INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES (1,'Users','users','/users',1),(2,'Groups','groups','/groups',1),(3,'Sidebar','sidebars','/sidebars',1),(4,'Petugas','petugas','/petugas',1),(5,'Transaksi','transaksi','/transaksi',1);
 INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT g,s,1,1,1,1 FROM generate_series(1,2) g CROSS JOIN generate_series(1,5) s;
 SELECT setval('groups_id_seq',10);`
	if err = db.Exec(ddl).Error; err != nil {
		t.Fatal(err)
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte("disposable-strong-password"), bcrypt.MinCost)
	for id := 1; id <= 6; id++ {
		group := 2
		status := 1
		if id <= 2 {
			group = 1
		}
		if id == 4 {
			group = 3
		}
		if id == 6 {
			status = 0
		}
		if err = db.Exec(`INSERT INTO users(id,group_id,username,email,password,nama,status) VALUES(?,?,?,?,?,?,?)`, id, group, fmt.Sprintf("user%d", id), fmt.Sprintf("user%d@example.invalid", id), string(hash), fmt.Sprintf("User %d", id), status).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err = db.Exec("SELECT setval('users_id_seq',10)").Error; err != nil {
		t.Fatal(err)
	}
	if prepare != nil {
		prepare(db)
	}
	migration, err := os.ReadFile("../migration_proposals/20261119_users_security.sql")
	if err != nil {
		t.Fatal(err)
	}
	if err = db.Transaction(func(tx *gorm.DB) error { return tx.Exec(string(migration)).Error }); err != nil {
		t.Fatal(err)
	}
	runtime := config.Config{JWTSecret: "users-disposable-test-signing", JWTExpireMinutes: 30, UsersSecurityEnabled: true}
	if err = (services.Administration{DB: db, Enabled: true}).Ready(context.Background()); err != nil {
		t.Fatal(err)
	}
	gin.SetMode(gin.TestMode)
	api := SetupRouter(runtime, controllers.NewHealthController(), nil, nil, nil, nil, controllers.NewGroupController(), controllers.NewUserController(), controllers.NewAuthController(services.NewAuthService(runtime)), controllers.NewMeController(), controllers.NewSidebarController(), controllers.NewSidebarAccessController(services.NewSidebarService()))
	return usersFixture{db, api, runtime}
}
func (f usersFixture) token(id uint, change func(jwt.MapClaims)) string {
	c := jwt.MapClaims{"uid": id, "gid": 1, "sv": 1, "iss": "backend-notaris-go", "exp": time.Now().Add(time.Hour).Unix()}
	if change != nil {
		change(c)
	}
	token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(f.cfg.JWTSecret))
	return token
}
func (f usersFixture) req(t *testing.T, method, path string, id uint, body any, want int) map[string]any {
	t.Helper()
	raw, _ := json.Marshal(body)
	r := httptest.NewRequest(method, "/api/v1"+path, bytes.NewReader(raw))
	r.Header.Set("Content-Type", "application/json")
	if id != 0 {
		r.Header.Set("Authorization", "Bearer "+f.token(id, nil))
	}
	w := httptest.NewRecorder()
	f.api.ServeHTTP(w, r)
	if w.Code != want {
		t.Fatalf("%s %s: status %d wanted %d", method, path, w.Code, want)
	}
	var data map[string]any
	json.Unmarshal(w.Body.Bytes(), &data)
	return data
}
func userBody(rev int) map[string]any {
	return map[string]any{"group_id": 2, "username": "user5", "email": "user5@example.invalid", "nama": "Edited", "expected_revision": rev}
}
func assertCode(t *testing.T, e error, want string) {
	t.Helper()
	var p *services.AdminError
	if !errors.As(e, &p) || p.Code != want {
		t.Fatalf("wanted %s, got %v", want, e)
	}
}
func actor(id uint) services.AdminActor {
	return services.AdminActor{ID: id, Version: 1, RequestID: services.AdminRequestID()}
}

func TestUsersSecurityHTTP(t *testing.T) {
	t.Run("RBAC default deny and sanitized read", func(t *testing.T) {
		f := usersSetup(t)
		login := f.req(t, "POST", "/auth/login", 0, map[string]any{"username": "user1", "password": "disposable-strong-password"}, 200)
		issued := login["data"].(map[string]any)["token"].(string)
		parsed := &services.Claims{}
		if _, e := jwt.ParseWithClaims(issued, parsed, func(token *jwt.Token) (any, error) { return []byte(f.cfg.JWTSecret), nil }, jwt.WithExpirationRequired()); e != nil || parsed.Version == nil || *parsed.Version != 1 {
			t.Fatal("login issued invalid version")
		}
		f.req(t, "POST", "/auth/login", 0, map[string]any{"username": "user1", "password": "invalid"}, 401)
		f.req(t, "GET", "/auth/me", 3, nil, 200)
		f.req(t, "GET", "/auth/me/sidebar-access", 3, nil, 200)
		f.req(t, "GET", "/users", 0, nil, 401)
		f.req(t, "GET", "/users", 3, nil, 403)
		f.req(t, "GET", "/users", 4, nil, 403)
		data := f.req(t, "GET", "/users", 1, nil, 200)
		b, _ := json.Marshal(data)
		if strings.Contains(string(b), "password") || strings.Contains(string(b), "security_version") {
			t.Fatal("secret returned")
		}
		f.db.Exec("UPDATE sidebar SET status=0 WHERE id=1")
		f.req(t, "GET", "/users", 1, nil, 403)
	})
	t.Run("create unique group policy and strict input", func(t *testing.T) {
		f := usersSetup(t)
		b := userBody(0)
		b["username"] = "new.user"
		b["email"] = "new@example.invalid"
		b["password"] = "a-strong-disposable-password"
		b["password_confirm"] = b["password"]
		result := f.req(t, "POST", "/users", 1, b, 201)
		id := uint(result["data"].(map[string]any)["id"].(float64))
		var u models.User
		f.db.First(&u, id)
		if bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(b["password"].(string))) != nil || u.Status != 1 || u.Revision != 1 {
			t.Fatal("invalid create")
		}
		b["username"] = " NEW.USER "
		f.req(t, "POST", "/users", 1, b, 409)
		b["username"] = "other"
		b["email"] = "other@example.invalid"
		b["group_id"] = 1
		f.req(t, "POST", "/users", 1, b, 422)
		b["group_id"] = 4
		f.req(t, "POST", "/users", 1, b, 422)
		b["group_id"] = 999
		f.req(t, "POST", "/users", 1, b, 422)
		b["group_id"] = 2
		delete(b, "password_confirm")
		f.req(t, "POST", "/users", 1, b, 400)
		b["password_confirm"] = b["password"]
		b["status"] = 1
		f.req(t, "POST", "/users", 1, b, 400)
		var audit string
		f.db.Raw("SELECT string_agg(row_to_json(a)::text,'') FROM administrative_audit a").Scan(&audit)
		if strings.Contains(audit, b["password"].(string)) || strings.Contains(audit, "$2a$") {
			t.Fatal("audit leaked credentials")
		}
	})
	t.Run("revision inactive state explicit reset and revocation", func(t *testing.T) {
		f := usersSetup(t)
		f.req(t, "PUT", "/users/5", 1, userBody(1), 200)
		f.req(t, "PUT", "/users/5", 1, userBody(1), 409)
		b := userBody(1)
		b["username"] = "user6"
		b["email"] = "user6@example.invalid"
		f.req(t, "PUT", "/users/6", 1, b, 200)
		var disabled models.User
		f.db.First(&disabled, 6)
		if disabled.Status != 0 {
			t.Fatal("reactivation")
		}
		reset := map[string]any{"expected_revision": 2, "password": "new-disposable-password", "password_confirm": "new-disposable-password"}
		f.req(t, "POST", "/users/5/password-reset", 1, reset, 200)
		f.req(t, "GET", "/auth/me", 5, nil, 401)
		f.req(t, "GET", "/auth/me/sidebar-access", 5, nil, 401)
		f.req(t, "POST", "/transaksi-notaris/sync/create", 5, map[string]any{}, 401)
		_, token, e := services.NewAuthService(f.cfg).Login(" USER5 ", "new-disposable-password")
		if e != nil || token == "" {
			t.Fatal("fresh version login failed")
		}
		if _, _, e = services.NewAuthService(f.cfg).Login("user5", "wrong"); e == nil {
			t.Fatal("password accepted")
		}
	})
	t.Run("self security promotion and soft deletion", func(t *testing.T) {
		f := usersSetup(t)
		f.req(t, "DELETE", "/users/1", 1, map[string]any{"expected_revision": 1}, 403)
		b := userBody(1)
		b["username"] = "user1"
		b["email"] = "user1@example.invalid"
		f.req(t, "PUT", "/users/1", 1, b, 403)
		b = userBody(1)
		b["group_id"] = 1
		f.req(t, "PUT", "/users/5", 1, b, 422)
		f.req(t, "DELETE", "/users/5", 1, map[string]any{"expected_revision": 1}, 200)
		var u models.User
		f.db.First(&u, 5)
		if u.ID != 5 || u.Status != 0 || u.SecurityVersion != 2 {
			t.Fatal("not soft deactivated/revoked")
		}
	})
	t.Run("mandatory expiry signature issuer version and current group", func(t *testing.T) {
		f := usersSetup(t)
		for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { delete(c, "exp") }, func(c jwt.MapClaims) { c["exp"] = 1 }, func(c jwt.MapClaims) { c["iss"] = "unknown" }, func(c jwt.MapClaims) { delete(c, "sv") }, func(c jwt.MapClaims) { c["sv"] = 2 }, func(c jwt.MapClaims) { c["uid"] = 0 }, func(c jwt.MapClaims) { c["gid"] = 0 }} {
			r := httptest.NewRequest("GET", "/api/v1/auth/me", nil)
			r.Header.Set("Authorization", "Bearer "+f.token(1, change))
			w := httptest.NewRecorder()
			f.api.ServeHTTP(w, r)
			if w.Code != 401 {
				t.Fatal("invalid token accepted")
			}
		}
		r := httptest.NewRequest("GET", "/api/v1/auth/me", nil)
		r.Header.Set("Authorization", "Bearer "+f.token(1, nil)+"x")
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, r)
		if w.Code != 401 {
			t.Fatal("bad signature accepted")
		}
		f.db.Exec("UPDATE users SET group_id=2 WHERE id=1")
		f.req(t, "GET", "/users", 1, nil, 403) // stale gid claim never grants admin
		f.db.Exec("UPDATE groups SET status=0 WHERE id=2")
		f.req(t, "GET", "/auth/me", 3, nil, 401)
		if _, _, e := services.NewAuthService(f.cfg).Login("user3", "disposable-strong-password"); e == nil {
			t.Fatal("disabled group login")
		}
		if _, _, e := services.NewAuthService(f.cfg).Login("user6", "disposable-strong-password"); e == nil {
			t.Fatal("disabled user login")
		}
	})
	t.Run("narrow Petugas reference without Users privilege", func(t *testing.T) {
		f := usersSetup(t)
		value := f.req(t, "GET", "/petugas/references/users/5", 3, nil, 200)["data"].(map[string]any)
		if len(value) != 2 || value["id"] != float64(5) {
			t.Fatal("reference leaked fields")
		}
		f.req(t, "GET", "/petugas/references/users/6", 3, nil, 404)
		f.req(t, "GET", "/users", 3, nil, 403)
		f.db.Exec(`UPDATE sidebar_akses SET "read"=0 WHERE group_id=2 AND sidebar_id=4`)
		f.req(t, "GET", "/petugas/references/users/5", 3, nil, 403)
	})
	t.Run("ambiguous grants fail closed and cutover off blocks writes", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec("DROP INDEX sidebar_group_grant_unique")
		f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(1,1,1,1,1,1)`)
		f.req(t, "GET", "/users", 1, nil, 403)
		cfg := f.cfg
		cfg.UsersSecurityEnabled = false
		controller := controllers.NewAdministrationController(cfg)
		api := gin.New()
		api.POST("/users", func(c *gin.Context) { c.Set("user_id", uint(1)); c.Next() }, controller.Guard("users", "create"), controller.CreateUser)
		w := httptest.NewRecorder()
		api.ServeHTTP(w, httptest.NewRequest("POST", "/users", nil))
		if w.Code != 503 {
			t.Fatal("unapproved activation")
		}
	})
}

func TestUsersSecurityAtomic(t *testing.T) {
	t.Run("group assignment race and authorization recheck", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		f.db.Exec("INSERT INTO groups(id,group_nama,group_jenis,status,revision) VALUES(5,'Ordinary destination','user',1,1)")
		ch := make(chan error, 2)
		for _, group := range []uint{2, 5} {
			go func(group uint) {
				_, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: group, Username: "user5", Email: "user5@example.invalid", Nama: "Assigned"}, 1, "")
				ch <- e
			}(group)
		}
		a, b := <-ch, <-ch
		if (a == nil) == (b == nil) {
			t.Fatal("concurrent assignment lost update")
		}
		err := s.Mutate(context.Background(), actor(1), "users", "update", "test_recheck", "user", 1, func(tx *gorm.DB) (any, any, error) {
			return nil, nil, tx.Exec("UPDATE users SET group_id=2 WHERE id=1").Error
		})
		assertCode(t, err, "admin_forbidden")
		var u models.User
		f.db.First(&u, 1)
		if u.GroupID != 1 {
			t.Fatal("revoked authorization committed")
		}
	})
	t.Run("non-recovery admin cannot deactivate final recovery account", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		f.db.Exec("UPDATE users SET status=0 WHERE id=2")
		f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(3,1,1,1,1,1)`)
		assertCode(t, s.UserSecurity(context.Background(), actor(4), 1, 1, ""), "last_recovery_administrator")
		var u models.User
		f.db.First(&u, 1)
		if u.Status != 1 {
			t.Fatal("last account lost")
		}
	})
	t.Run("shared paths and safe grant success audit", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		if err := s.GroupChange(context.Background(), actor(1), models.Group{GroupNama: "New ordinary", GroupJenis: "user"}, 0, false); err != nil {
			t.Fatal(err)
		}
		var target uint
		f.db.Raw("SELECT target_id FROM administrative_audit WHERE action='group_create'").Scan(&target)
		if target == 0 {
			t.Fatal("missing group audit identity")
		}
		if err := grantOnce(t, f, 2, 4); err != nil {
			t.Fatal(err)
		}
		state := accessState(t, f, 2)
		body := grantBody(state, accessItems(state, 4))
		body["expected_revision"] = 1
		f.req(t, "PUT", "/groups/2/sidebar-access", 1, body, 409)
		if err := services.NewUserService().Deactivate(&models.User{ID: 1}, 1); err == nil {
			t.Fatal("legacy bypass")
		}
		if err := services.NewGroupService().Deactivate(&models.Group{ID: 1}, 1); err == nil {
			t.Fatal("legacy bypass")
		}
		if err := services.NewSidebarService().ReplaceGroupAccess(1, 1, nil); err == nil {
			t.Fatal("legacy grant bypass")
		}
		f.req(t, "DELETE", "/sidebars/3", 1, map[string]any{}, 404)
	})
	t.Run("parallel edits one success one conflict", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		results := make(chan error, 2)
		var wg sync.WaitGroup
		for i := 0; i < 2; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				_, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: 2, Username: "user5", Email: "user5@example.invalid", Nama: "Changed"}, 1, "")
				results <- e
			}()
		}
		wg.Wait()
		close(results)
		good, bad := 0, 0
		for e := range results {
			if e == nil {
				good++
			} else {
				assertCode(t, e, "stale_revision")
				bad++
			}
		}
		if good != 1 || bad != 1 {
			t.Fatal("lost update")
		}
	})
	t.Run("parallel account deactivation cannot remove recovery", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		ch := make(chan error, 2)
		go func() { ch <- s.UserSecurity(context.Background(), actor(1), 2, 1, "") }()
		go func() { ch <- s.UserSecurity(context.Background(), actor(2), 1, 1, "") }()
		a, b := <-ch, <-ch
		if (a == nil) == (b == nil) {
			t.Fatal("must have exactly one success")
		}
		if s.Read(context.Background(), actor(1), "users") != nil && s.Read(context.Background(), actor(2), "users") != nil {
			t.Fatal("no recovery actor")
		}
	})
	t.Run("groups grants and audit rollback", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		assertCode(t, s.GroupChange(context.Background(), actor(1), models.Group{ID: 1}, 1, true), "protected_group")
		assertCode(t, s.Grants(context.Background(), actor(1), 1, 1, nil), "protected_group")
		assertCode(t, s.GroupChange(context.Background(), actor(1), models.Group{ID: 2, GroupNama: "Escalate", GroupJenis: "superadmin"}, 1, false), "privileged_transition_blocked")
		var count int64
		f.db.Table("administrative_audit").Where("result='denied'").Count(&count)
		if count != 3 {
			t.Fatal("denials rolled back")
		}
		if e := f.db.Exec("DELETE FROM administrative_audit").Error; e == nil {
			t.Fatal("audit mutable")
		}
		if e := f.db.Exec(`CREATE FUNCTION reject_success_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.result='success' THEN RAISE EXCEPTION 'test failure';END IF;RETURN NEW;END$$;
 CREATE TRIGGER audit_failure BEFORE INSERT ON administrative_audit FOR EACH ROW EXECUTE FUNCTION reject_success_audit()`).Error; e != nil {
			t.Fatal(e)
		}
		_, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: 2, Username: "user5", Email: "user5@example.invalid", Nama: "Must rollback"}, 1, "")
		assertCode(t, e, "admin_operation_failed")
		var u models.User
		f.db.First(&u, 5)
		if u.Nama != "User 5" || u.Revision != 1 {
			t.Fatal("partial update")
		}
	})
	t.Run("concurrent group and grant recovery removal", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		// Split recovery users across independent groups, then race cross-group actions.
		f.db.Exec("INSERT INTO groups(id,group_nama,group_jenis,status,revision) VALUES(5,'Second recovery','superadmin',1,1)")
		f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT 5,sidebar_id,"read","create","update","delete" FROM sidebar_akses WHERE group_id=1`)
		f.db.Exec("UPDATE users SET group_id=5 WHERE id=2")
		ch := make(chan error, 2)
		go func() { ch <- s.GroupChange(context.Background(), actor(1), models.Group{ID: 5}, 1, true) }()
		go func() { ch <- s.Grants(context.Background(), actor(2), 1, 1, []request.SidebarAccessItem{}) }()
		a, b := <-ch, <-ch
		assertCode(t, a, "protected_group")
		assertCode(t, b, "protected_group")
	})
}

func TestUsersSecurityMigrationGuards(t *testing.T) {
	f := usersSetup(t)
	proposal, _ := os.ReadFile("../migration_proposals/20261119_users_security.sql")
	if err := f.db.Transaction(func(tx *gorm.DB) error { return tx.Exec(string(proposal)).Error }); err == nil {
		t.Fatal("reapply must fail")
	}
	if err := (services.Administration{DB: f.db, Enabled: true}).Ready(context.Background()); err != nil {
		t.Fatal("failed migration damaged existing schema")
	}
	// Unnormalized identities and duplicate grants are rejected at the database boundary.
	if e := f.db.Exec("INSERT INTO users(group_id,username,email,nama,status) VALUES(2,' USER5 ','other@example.invalid','X',1)").Error; e == nil {
		t.Fatal("identity uniqueness missing")
	}
	if e := f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(1,1,1,1,1,1)`).Error; e == nil {
		t.Fatal("grant uniqueness missing")
	}
	var invalid int64
	f.db.Raw("SELECT count(*) FROM users u LEFT JOIN groups g ON g.id=u.group_id WHERE g.id IS NULL").Scan(&invalid)
	if invalid != 0 {
		t.Fatal("FK invalid")
	}
}

func TestUsersSecurityListingV1(t *testing.T) {
	f := usersSetup(t)
	page := func(path string) map[string]any { return f.req(t, "GET", path, 1, nil, 200)["data"].(map[string]any) }
	first := page("/users?page=1&page_size=2")
	second := page("/users?page=2&page_size=2")
	if first["total"] != float64(6) || len(first["items"].([]any)) != 2 || second["items"].([]any)[0].(map[string]any)["id"] != float64(3) {
		t.Fatal("unstable bounded pagination")
	}
	filtered := page("/users?group_id=2&status=0")
	if filtered["total"] != float64(1) || filtered["items"].([]any)[0].(map[string]any)["id"] != float64(6) {
		t.Fatal("inactive/group filter")
	}
	if page("/users?search=user5")["total"] != float64(1) || page("/users?search=%27%20OR%201=1--")["total"] != float64(0) || page("/users?search=%25")["total"] != float64(0) {
		t.Fatal("literal search")
	}
	empty := page("/users?page=100")
	if empty["total"] != float64(6) || len(empty["items"].([]any)) != 0 {
		t.Fatal("empty page total lost")
	}
	record := f.req(t, "GET", "/users/6", 1, nil, 200)["data"].(map[string]any)
	if record["status"] != float64(0) || record["revision"] != float64(1) || record["group_jenis"] != "user" || record["group_nama"] != "Operator" {
		t.Fatal("invalid safe projection")
	}
	if len(f.req(t, "GET", "/users/assignable-groups", 1, nil, 200)["data"].([]any)) != 1 {
		t.Fatal("assignable groups leaked protected/inactive groups")
	}
	for _, query := range []string{"?page=0", "?page_size=51", "?status=2", "?group_id=0"} {
		f.req(t, "GET", "/users"+query, 1, nil, 400)
	}
	f.req(t, "GET", "/users/999", 1, nil, 404)
	f.req(t, "GET", "/users/5", 3, nil, 403)
}
