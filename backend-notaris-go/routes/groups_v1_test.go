package routes

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"os/exec"
	"strings"
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
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func membership(t *testing.T, f usersFixture, id uint) string {
	t.Helper()
	var token string
	if e := f.db.Raw("SELECT "+services.GroupMembershipSQL+" FROM users m WHERE m.group_id=?", id).Scan(&token).Error; e != nil {
		t.Fatal(e)
	}
	return token
}
func renameBody(rev int, name string) map[string]any {
	return map[string]any{"group_nama": name, "group_jenis": "user", "expected_revision": rev}
}
func TestGroupsV1Authorization(t *testing.T) {
	f := usersSetup(t)
	for _, path := range []string{"/groups", "/groups/2", "/groups/2/sidebar-access"} {
		f.req(t, "GET", path, 0, nil, 401)
		f.req(t, "GET", path, 3, nil, 403)
		f.req(t, "GET", path, 4, nil, 403)
		f.req(t, "GET", path, 6, nil, 401)
		f.req(t, "GET", path, 1, nil, 200)
	}
	for _, uid := range []uint{3, 4} {
		f.req(t, "POST", "/groups", uid, renameBody(0, "Denied"), 403)
		f.req(t, "PUT", "/groups/2", uid, renameBody(1, "Denied"), 403)
		f.req(t, "DELETE", "/groups/2", uid, map[string]any{"expected_revision": 1, "expected_membership": membership(t, f, 2)}, 403)
	}
	f.req(t, "PUT", "/groups/1", 1, renameBody(1, "Forbidden"), 403)
	f.req(t, "DELETE", "/groups/3", 1, map[string]any{"expected_revision": 1}, 403)
	f.req(t, "POST", "/groups", 1, map[string]any{"group_nama": "Forbidden", "group_jenis": "superadmin"}, 422)
	// Current token security version and mandatory expiration are enforced on reads.
	for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { delete(c, "exp") }, func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }, func(c jwt.MapClaims) { c["sv"] = 2 }} {
		q := httptest.NewRequest("GET", "/api/v1/groups", nil)
		q.Header.Set("Authorization", "Bearer "+f.token(1, change))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, q)
		if w.Code != 401 {
			t.Fatal("invalid JWT accepted")
		}
	}
	disabled := controllers.NewAdministrationController(config.Config{})
	r := gin.New()
	r.GET("/groups", disabled.Guard("groups", "read"), disabled.Groups)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("GET", "/groups", nil))
	if w.Code != 503 {
		t.Fatal("default off bypass")
	}
	f.db.Exec("UPDATE groups SET status=0 WHERE id=2")
	f.req(t, "GET", "/groups", 3, nil, 401)
}
func TestGroupsV1Listing(t *testing.T) {
	f := usersSetup(t)
	for i := 0; i < 15; i++ {
		if e := f.db.Exec("INSERT INTO groups(group_nama,group_jenis,status) VALUES(?,'user',1)", fmt.Sprintf("Group %02d", i)).Error; e != nil {
			t.Fatal(e)
		}
	}
	f.db.Exec("INSERT INTO groups(group_nama,group_jenis,status) VALUES('100% literal','user',1),('100x literal','user',1),('Operator','user',1)")
	get := func(query string) map[string]any {
		return f.req(t, "GET", "/groups"+query, 1, nil, 200)["data"].(map[string]any)
	}
	p1, p2 := get("?status=all&page=1"), get("?status=all&page=2")
	if p1["total"] != float64(22) || len(p1["items"].([]any)) != 10 || len(p2["items"].([]any)) != 10 {
		t.Fatal("pagination")
	}
	seen := map[float64]bool{}
	for _, page := range []map[string]any{p1, p2, get("?status=all&page=3")} {
		for _, v := range page["items"].([]any) {
			r := v.(map[string]any)
			id := r["id"].(float64)
			if seen[id] {
				t.Fatal("duplicate page")
			}
			seen[id] = true
		}
	}
	if get("?search=%25")["total"] != float64(1) || get("?group_jenis=superadmin")["total"] != float64(2) || get("?status=0")["total"] != float64(1) || get("")["total"] != float64(21) {
		t.Fatal("filters")
	}
	row := f.req(t, "GET", "/groups/2", 1, nil, 200)["data"].(map[string]any)
	if row["active_members"] != float64(2) || row["total_members"] != float64(3) || len(row["membership"].(string)) != 32 {
		t.Fatal("members")
	}
	raw, _ := json.Marshal(row)
	if strings.Contains(string(raw), "password") || strings.Contains(string(raw), "username") || strings.Contains(string(raw), "email") {
		t.Fatal("PII")
	}
	for _, q := range []string{"?page=0", "?page_size=51", "?status=2", "?group_jenis=admin"} {
		f.req(t, "GET", "/groups"+q, 1, nil, 400)
	}
	f.req(t, "GET", "/groups/9999", 1, nil, 404)
}
func TestGroupsV1Lifecycle(t *testing.T) {
	f := usersSetup(t)
	f.req(t, "POST", "/groups", 1, renameBody(0, "  New ordinary  "), 200)
	var g models.Group
	f.db.Where("group_nama='New ordinary'").First(&g)
	if g.ID == 0 || g.GroupJenis != "user" || g.Revision != 1 || g.Status != 1 || g.CreatedBy == nil {
		t.Fatal("create contract")
	}
	var n int64
	f.db.Table("users").Where("group_id=?", g.ID).Count(&n)
	if n != 0 {
		t.Fatal("auto membership")
	}
	f.db.Table("sidebar_akses").Where("group_id=?", g.ID).Count(&n)
	if n != 0 {
		t.Fatal("auto grants")
	}
	f.req(t, "POST", "/groups", 1, renameBody(0, ""), 422)
	f.req(t, "POST", "/groups", 1, renameBody(0, strings.Repeat("a", 161)), 422)
	assigned := f.req(t, "GET", "/users/assignable-groups", 1, nil, 200)["data"].([]any)
	found := false
	for _, v := range assigned {
		r := v.(map[string]any)
		if r["id"] == float64(g.ID) {
			found = true
		}
		if r["group_jenis"] != "user" || r["status"] != float64(1) {
			t.Fatal("unsafe assignable")
		}
	}
	if !found {
		t.Fatal("new group unavailable")
	}
	f.req(t, "PUT", fmt.Sprintf("/groups/%d", g.ID), 1, renameBody(1, "Renamed"), 200)
	f.req(t, "PUT", fmt.Sprintf("/groups/%d", g.ID), 1, renameBody(1, "Stale"), 409)
	f.req(t, "PUT", fmt.Sprintf("/groups/%d", g.ID), 1, map[string]any{"group_nama": "X", "group_jenis": "superadmin", "expected_revision": 2}, 403)
	// A newly assigned member must invalidate an earlier confirmation token,
	// even though the group revision itself is unchanged by a User assignment.
	old := membership(t, f, g.ID)
	s := services.Administration{DB: f.db, Enabled: true}
	if _, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: g.ID, Username: "user5", Email: "user5@example.invalid", Nama: "Assigned"}, 1, ""); e != nil {
		t.Fatal(e)
	}
	f.req(t, "DELETE", fmt.Sprintf("/groups/%d", g.ID), 1, map[string]any{"expected_revision": 2, "expected_membership": old}, 409)
	f.req(t, "DELETE", fmt.Sprintf("/groups/%d", g.ID), 1, map[string]any{"expected_revision": 2, "expected_membership": membership(t, f, g.ID)}, 200)
	var u models.User
	f.db.First(&u, 5)
	if u.GroupID != g.ID || u.SecurityVersion != 3 {
		t.Fatal("member revoked or relationship lost")
	}
	f.req(t, "GET", "/auth/me", 5, nil, 401)
	f.req(t, "PUT", fmt.Sprintf("/groups/%d", g.ID), 1, renameBody(3, "Reactivation"), 409)
	f.req(t, "DELETE", fmt.Sprintf("/groups/%d", g.ID), 1, map[string]any{"expected_revision": 3, "expected_membership": membership(t, f, g.ID)}, 409)
	assigned = f.req(t, "GET", "/users/assignable-groups", 1, nil, 200)["data"].([]any)
	for _, v := range assigned {
		if v.(map[string]any)["id"] == float64(g.ID) {
			t.Fatal("inactive assignable")
		}
	}
	var successes int64
	f.db.Table("administrative_audit").Where("result='success'").Count(&successes)
	if successes != 4 {
		t.Fatal("audit success not atomic")
	}
}
func TestGroupsV1Concurrency(t *testing.T) {
	for _, race := range []string{"rename", "deactivate", "assignment", "grants"} {
		t.Run(race, func(t *testing.T) {
			f := usersSetup(t)
			s := services.Administration{DB: f.db, Enabled: true}
			if race == "assignment" {
				f.db.Exec("UPDATE users SET group_id=4 WHERE id=5")
			}
			token := membership(t, f, 2)
			ch := make(chan error, 2)
			go func() {
				ch <- s.GroupChange(context.Background(), actor(1), models.Group{ID: 2, GroupNama: "Renamed", GroupJenis: "user"}, 1, false)
			}()
			go func() {
				switch race {
				case "rename":
					ch <- s.GroupChange(context.Background(), actor(1), models.Group{ID: 2, GroupNama: "Other", GroupJenis: "user"}, 1, false)
				case "deactivate":
					ch <- s.GroupChange(context.Background(), actor(1), models.Group{ID: 2}, 1, true, token)
				case "assignment":
					_, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: 2, Username: "user5", Email: "user5@example.invalid", Nama: "Assigned"}, 1, "")
					ch <- e
				case "grants":
					ch <- s.Grants(context.Background(), actor(1), 2, 1, []request.SidebarAccessItem{{SidebarID: 4, Read: 1}})
				}
			}()
			a, b := <-ch, <-ch
			if race != "assignment" && (a == nil) == (b == nil) {
				t.Fatalf("one revision winner required: %v %v", a, b)
			}
			if race == "assignment" && (a != nil || b != nil) {
				t.Fatalf("independent rename and assignment should serialize: %v %v", a, b)
			}
			if e := s.Read(context.Background(), actor(1), "groups"); e != nil {
				t.Fatal("recovery lost")
			}
		})
	}
	t.Run("assignment versus deactivation confirmation", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec("UPDATE users SET group_id=4 WHERE id=5")
		s := services.Administration{DB: f.db, Enabled: true}
		token := membership(t, f, 2)
		ch := make(chan error, 2)
		go func() { ch <- s.GroupChange(context.Background(), actor(1), models.Group{ID: 2}, 1, true, token) }()
		go func() {
			_, e := s.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: 2, Username: "user5", Email: "user5@example.invalid", Nama: "Assigned"}, 1, "")
			ch <- e
		}()
		a, b := <-ch, <-ch
		if (a == nil) == (b == nil) {
			t.Fatalf("only assignment or confirmed deactivation can commit: %v %v", a, b)
		}
	})
	t.Run("group success audit failure rolls back", func(t *testing.T) {
		f := usersSetup(t)
		s := services.Administration{DB: f.db, Enabled: true}
		f.db.Exec(`CREATE FUNCTION reject_group_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.result='success' THEN RAISE EXCEPTION 'test';END IF;RETURN NEW;END$$; CREATE TRIGGER fail_group_audit BEFORE INSERT ON administrative_audit FOR EACH ROW EXECUTE FUNCTION reject_group_audit()`)
		assertCode(t, s.GroupChange(context.Background(), actor(1), models.Group{ID: 2, GroupNama: "Never committed", GroupJenis: "user"}, 1, false), "admin_operation_failed")
		var g models.Group
		f.db.First(&g, 2)
		if g.Revision != 1 || g.GroupNama != "Operator" {
			t.Fatal("partial update")
		}
		assertCode(t, s.GroupChange(context.Background(), actor(1), models.Group{ID: 2}, 1, true, membership(t, f, 2)), "admin_operation_failed")
		var sv int64
		f.db.Raw("SELECT min(security_version) FROM users WHERE group_id=2").Scan(&sv)
		f.db.First(&g, 2)
		if sv != 1 || g.Status != 1 || g.Revision != 1 {
			t.Fatal("audit failure left revoked members or inactive group")
		}

	})
}
func TestGroupsV1FlutterHTTP(t *testing.T) {
	if os.Getenv("NOTARIS_GROUPS_V1_FLUTTER_E2E") != "1" {
		t.Skip("Groups Flutter opt-in")
	}
	f := usersSetup(t)
	// Exercise the actual UI against the minimum Groups runtime SQL privileges,
	// not the provisioning owner. New role/schema only in the owned test cluster.
	role := fmt.Sprintf("groups_runtime_%d", time.Now().UnixNano())
	var schema string
	f.db.Raw("SELECT current_schema()").Scan(&schema)
	if e := f.db.Exec("CREATE ROLE " + role + "; GRANT USAGE ON SCHEMA " + schema + " TO " + role + "; GRANT SELECT ON users,groups,sidebar,sidebar_akses TO " + role + "; GRANT INSERT,UPDATE ON groups TO " + role + "; GRANT UPDATE(security_version) ON users TO " + role + "; GRANT INSERT ON administrative_audit TO " + role + "; GRANT USAGE ON SEQUENCE groups_id_seq,administrative_audit_id_seq TO " + role).Error; e != nil {
		t.Fatal(e)
	}
	cfg, e := pgx.ParseConfig(os.Getenv("NOTARIS_USERS_SECURITY_TEST_DSN"))
	if e != nil {
		t.Fatal("test DSN")
	}
	cfg.RuntimeParams["search_path"] = schema
	cfg.RuntimeParams["role"] = role
	pool := stdlib.OpenDB(*cfg)
	limited, e := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if e != nil {
		t.Fatal("limited DB")
	}
	t.Cleanup(func() {
		pool.Close()
		database.DB = f.db
		f.db.Exec("DROP OWNED BY " + role)
		f.db.Exec("DROP ROLE " + role)
	})
	var currentRole string
	if limited.Raw("SELECT current_user").Scan(&currentRole).Error != nil || currentRole != role {
		t.Fatal("runtime role bypass")
	}
	database.DB = limited
	f.api = SetupRouter(f.cfg, controllers.NewHealthController(), nil, nil, nil, nil, controllers.NewGroupController(), controllers.NewUserController(), controllers.NewAuthController(services.NewAuthService(f.cfg)), controllers.NewMeController(), controllers.NewSidebarController(), controllers.NewSidebarAccessController(services.NewSidebarService()))
	server := httptest.NewServer(f.api)
	defer server.Close()
	cmd := exec.Command("flutter.bat", "test", "--no-pub", "test/e2e/groups_v1_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	token := f.token(1, nil)
	cmd.Env = append(os.Environ(), "NOTARIS_GROUPS_V1_HTTP="+server.URL+"/api/v1", "NOTARIS_GROUPS_V1_TOKEN="+token)
	output, e := cmd.CombinedOutput()
	if e != nil {
		t.Fatalf("Groups Flutter HTTP: %s", strings.ReplaceAll(string(output), token, "[REDACTED]"))
	}
	t.Log(strings.ReplaceAll(string(output), token, "[REDACTED]"))
	var group models.Group
	f.db.Where("group_nama='HTTP Group Renamed'").First(&group)
	if group.ID == 0 || group.Status != 0 || group.Revision != 3 {
		t.Fatal("UI mutation not committed")
	}
	var count int64
	f.db.Table("administrative_audit").Where("result='success'").Count(&count)
	if count != 3 {
		t.Fatal("audit missing")
	}
}
func TestGroupsV1ExplicitGrants(t *testing.T) {
	for _, action := range []string{"read", "create", "update", "delete"} {
		t.Run(action, func(t *testing.T) {
			f := usersSetup(t)
			if e := f.db.Exec(`UPDATE sidebar_akses SET "` + action + `"=0 WHERE group_id=1 AND sidebar_id=2`).Error; e != nil {
				t.Fatal(e)
			}
			method, path, body := "GET", "/groups", map[string]any(nil)
			switch action {
			case "create":
				method = "POST"
				body = renameBody(0, "Denied")
			case "update":
				method = "PUT"
				path = "/groups/2"
				body = renameBody(1, "Denied")
			case "delete":
				method = "DELETE"
				path = "/groups/2"
				body = map[string]any{"expected_revision": 1, "expected_membership": membership(t, f, 2)}
			}
			f.req(t, method, path, 1, body, 403)
		})
	}
}
