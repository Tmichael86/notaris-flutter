package routes

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"testing"
	"time"

	"backend-notaris-go/controllers"
	"backend-notaris-go/database"
	"backend-notaris-go/dto/request"
	"backend-notaris-go/internal/devfixture"
	"backend-notaris-go/middleware"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func accessState(t *testing.T, f usersFixture, id uint) services.GroupAccessSnapshot {
	t.Helper()
	s, e := (services.Administration{DB: f.db, Enabled: true}).GroupAccess(context.Background(), actor(1), id)
	if e != nil {
		t.Fatal(e)
	}
	return s
}
func accessItems(s services.GroupAccessSnapshot, enabled uint) []request.SidebarAccessItem {
	out := make([]request.SidebarAccessItem, 0)
	for _, r := range s.Entries {
		if r.Editable {
			p := request.SidebarAccessItem{SidebarID: r.Sidebar.ID}
			if r.Sidebar.ID == enabled {
				p.Read = 1
			}
			out = append(out, p)
		}
	}
	return out
}
func grantBody(s services.GroupAccessSnapshot, items []request.SidebarAccessItem) map[string]any {
	return map[string]any{"expected_revision": s.Group.Revision, "catalog_fingerprint": s.Catalog, "access": items}
}
func grantOnce(t *testing.T, f usersFixture, id uint, enabled uint) error {
	t.Helper()
	s := accessState(t, f, id)
	return (services.Administration{DB: f.db, Enabled: true}).Grants(context.Background(), actor(1), id, s.Group.Revision, accessItems(s, enabled), s.Catalog)
}
func TestGroupsV2SnapshotAndPreservation(t *testing.T) {
	f := usersSetup(t)
	f.db.Exec(`INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES(8,0,'Historis','historis','/historis','archive',8,0),(9,999,'Orphan','orphan','/orphan','',9,1),(10,0,'Parent','parent','#','folder',10,1),(11,10,'Child','child','/child','file',11,1),(12,11,'Deep','deep','/deep','file',12,1); INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(2,8,1,1,0,0),(2,9,1,0,1,0)`)
	var frozen []models.SidebarAccess
	f.db.Where("group_id=2 AND sidebar_id IN (8,9)").Order("id").Find(&frozen)
	s := accessState(t, f, 2)
	if s.Group.Revision != 1 || s.Group.ActiveMembers != 2 || len(s.Entries) != 10 || len(s.Catalog) != 64 {
		t.Fatalf("snapshot projection %+v", s.Group)
	}
	for _, r := range s.Entries {
		if (r.Sidebar.ID == 8 || r.Sidebar.ID == 9) && r.Editable {
			t.Fatal("hidden entry editable")
		}
		if r.Sidebar.ID == 12 && !r.Editable {
			t.Fatal("deep valid hierarchy lost")
		}
	}
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, accessItems(s, 4)), 200)
	var after []models.SidebarAccess
	f.db.Where("group_id=2 AND sidebar_id IN (8,9)").Order("id").Find(&after)
	if !reflect.DeepEqual(frozen, after) {
		t.Fatal("hidden grants mutated")
	}
	next := accessState(t, f, 2)
	if next.Group.Revision != 2 || next.Catalog != s.Catalog {
		t.Fatal("revision/catalog")
	}
	var count int64
	f.db.Table("users").Where("group_id=2 AND security_version=1").Count(&count)
	if count != 3 {
		t.Fatal("membership/security version changed")
	}
	var audit struct{ Before, After json.RawMessage }
	f.db.Raw("SELECT before_state AS before,after_state AS after FROM administrative_audit WHERE action='group_grants' AND result='success'").Scan(&audit)
	if len(audit.Before) == 0 || len(audit.After) == 0 {
		t.Fatal("audit absent")
	}
	var a, b services.GroupAccessSnapshot
	json.Unmarshal(audit.Before, &a)
	json.Unmarshal(audit.After, &b)
	if a.Group.Revision != 1 || b.Group.Revision != 2 {
		t.Fatal("audit revision missing")
	}
}
func TestGroupsV2Payload(t *testing.T) {
	for _, kind := range []string{"missing", "null", "malformed", "duplicate", "unknown", "partial", "flag", "missing_flag", "cud_without_read", "empty", "hidden"} {
		t.Run(kind, func(t *testing.T) {
			f := usersSetup(t)
			s := accessState(t, f, 2)
			p := accessItems(s, 4)
			b := grantBody(s, p)
			want := 400
			switch kind {
			case "missing":
				delete(b, "access")
			case "null":
				b["access"] = nil
			case "malformed":
				b["access"] = map[string]any{}
			case "duplicate":
				p[1].SidebarID = p[0].SidebarID
				b["access"] = p
			case "unknown":
				p[0].SidebarID = 999
				b["access"] = p
				want = 422
			case "partial":
				b["access"] = p[:1]
			case "flag":
				p[0].Read = 2
				b["access"] = p
			case "missing_flag":
				b["access"] = []any{map[string]any{"sidebar_id": 1, "read": 0, "create": 0, "update": 0}}
			case "cud_without_read":
				p[0].Read = 0
				p[0].Create = 1
				b["access"] = p
			case "empty":
				b["access"] = []any{}
			case "hidden":
				f.db.Exec("UPDATE sidebar SET status=0 WHERE id=4")
				s = accessState(t, f, 2)
				p = accessItems(s, 0)
				p[0].SidebarID = 4
				b = grantBody(s, p)
				want = 422
			}
			f.req(t, "PUT", "/groups/2/sidebar-access", 1, b, want)
			if accessState(t, f, 2).Group.Revision != 1 {
				t.Fatal("partial mutation")
			}
		})
	}
}
func TestGroupsV2AuthorizationAndConflicts(t *testing.T) {
	f := usersSetup(t)
	s := accessState(t, f, 2)
	p := accessItems(s, 4)
	for _, id := range []uint{3, 4} {
		f.req(t, "PUT", "/groups/2/sidebar-access", id, grantBody(s, p), 403)
	}
	protected := accessState(t, f, 1)
	f.req(t, "PUT", "/groups/1/sidebar-access", 1, grantBody(protected, accessItems(protected, 0)), 403)
	for _, field := range []string{"sidebar_nama", "sidebar_kode", "sidebar_route", "sidebar_icon", "sidebar_index", "sidebar_parent_id", "status"} {
		// Each authoritative metadata change must invalidate the original hash.
		tx := f.db.Begin()
		value := any("Changed")
		if field == "sidebar_index" {
			value = 9
		}
		if field == "sidebar_parent_id" {
			value = 5
		}
		if field == "status" {
			value = 0
		}
		if e := tx.Exec("UPDATE sidebar SET "+field+"=? WHERE id=4", value).Error; e != nil {
			t.Fatal(e)
		}
		tx.Commit()
		e := (services.Administration{DB: f.db, Enabled: true}).Grants(context.Background(), actor(1), 2, 1, p, s.Catalog)
		assertCode(t, e, "stale_catalog")
		s = accessState(t, f, 2)
		p = accessItems(s, 4)
	}
	f.db.Exec("UPDATE groups SET revision=2 WHERE id=2")
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, p), 409)
	f.db.Exec("UPDATE groups SET status=0 WHERE id=2")
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, p), 404)
}
func TestGroupsV2RevocationAndRollback(t *testing.T) {
	f := usersSetup(t)
	f.req(t, "GET", "/petugas/references/users/1", 3, nil, 200)
	if e := grantOnce(t, f, 2, 0); e != nil {
		t.Fatal(e)
	}
	f.req(t, "GET", "/petugas/references/users/1", 3, nil, 403)
	if e := grantOnce(t, f, 2, 4); e != nil {
		t.Fatal(e)
	}
	f.req(t, "GET", "/petugas/references/users/1", 3, nil, 200)
	before := accessState(t, f, 2)
	f.db.Exec(`CREATE FUNCTION reject_grants_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='group_grants' AND NEW.result='success' THEN RAISE EXCEPTION 'test';END IF;RETURN NEW;END$$; CREATE TRIGGER reject_grants_audit BEFORE INSERT ON administrative_audit FOR EACH ROW EXECUTE FUNCTION reject_grants_audit()`)
	assertCode(t, grantOnce(t, f, 2, 0), "admin_operation_failed")
	after := accessState(t, f, 2)
	if !reflect.DeepEqual(before, after) {
		t.Fatal("audit failure left partial grant update")
	}
}
func TestGroupsV2ConcurrentSnapshots(t *testing.T) {
	f := usersSetup(t)
	s := accessState(t, f, 2)
	p := accessItems(s, 4)
	svc := services.Administration{DB: f.db, Enabled: true}
	ch := make(chan error, 2)
	for i := 0; i < 2; i++ {
		go func() { ch <- svc.Grants(context.Background(), actor(1), 2, 1, p, s.Catalog) }()
	}
	a, b := <-ch, <-ch
	if (a == nil) == (b == nil) {
		t.Fatal("one revision winner required")
	}
	if a != nil {
		assertCode(t, a, "stale_revision")
	}
	if b != nil {
		assertCode(t, b, "stale_revision")
	}
}

func TestGroupsV2SnapshotConsistency(t *testing.T) {
	f := usersSetup(t)
	svc := services.Administration{DB: f.db, Enabled: true}
	done := make(chan error, 1)
	go func() {
		for i := 0; i < 8; i++ {
			s, e := svc.GroupAccess(context.Background(), actor(1), 2)
			if e != nil {
				done <- e
				return
			}
			enabled := uint(0)
			if (s.Group.Revision+1)%2 == 1 {
				enabled = 4
			}
			if e = svc.Grants(context.Background(), actor(1), 2, s.Group.Revision, accessItems(s, enabled), s.Catalog); e != nil {
				done <- e
				return
			}
		}
		done <- nil
	}()
	for i := 0; i < 16; i++ {
		s := accessState(t, f, 2)
		for _, r := range s.Entries {
			if r.Sidebar.ID == 4 && int64(r.Read) != s.Group.Revision%2 {
				t.Fatal("torn revision/grants read")
			}
		}
	}
	if e := <-done; e != nil {
		t.Fatal(e)
	}
}
func TestGroupsV2EmptyCatalogAndCommitRecheck(t *testing.T) {
	t.Run("explicit zero-editable catalog is an audited no-op; hidden rows retained", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec("UPDATE sidebar SET sidebar_parent_id=999")
		s := accessState(t, f, 2)
		items := accessItems(s, 0)
		if len(items) != 0 {
			t.Fatal("unsupported rows editable")
		}
		f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, items), 200)
		after := accessState(t, f, 2)
		if after.Group.Revision != 2 || !reflect.DeepEqual(s.Entries, after.Entries) {
			t.Fatal("zero-editable preservation")
		}
	})
	t.Run("catalog changed during reconciliation rolls back", func(t *testing.T) {
		f := usersSetup(t)
		s := accessState(t, f, 2)
		f.db.Exec(`CREATE FUNCTION change_catalog_during_grants() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN UPDATE sidebar SET sidebar_nama='Changed during write' WHERE id=4;RETURN NEW;END$$; CREATE TRIGGER change_catalog_during_grants BEFORE UPDATE ON sidebar_akses FOR EACH ROW EXECUTE FUNCTION change_catalog_during_grants()`)
		assertCode(t, grantOnce(t, f, 2, 0), "stale_catalog")
		if after := accessState(t, f, 2); !reflect.DeepEqual(s, after) {
			t.Fatal("catalog/grant partial write")
		}
	})
	t.Run("large catalog fails closed without truncation", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec(`INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) SELECT i,'Menu '||i::text,'menu_'||i::text,'/menu/'||i::text,1 FROM generate_series(20,1020)i`)
		_, e := (services.Administration{DB: f.db, Enabled: true}).GroupAccess(context.Background(), actor(1), 2)
		assertCode(t, e, "catalog_too_large")
	})
}

func TestGroupsV2GroupIsolationAndAmbiguity(t *testing.T) {
	t.Run("ordinary zero-grant group uses only explicit editable IDs", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec("INSERT INTO groups(id,group_nama,group_jenis,status) VALUES(5,'CS baru','user',1)")
		protected := accessState(t, f, 2)
		fresh := accessState(t, f, 5)
		for _, r := range fresh.Entries {
			if r.Read != 0 || r.Create != 0 || r.Update != 0 || r.Delete != 0 {
				t.Fatal("automatic permission")
			}
		}
		f.req(t, "PUT", "/groups/5/sidebar-access", 1, grantBody(fresh, accessItems(fresh, 4)), 200)
		if !reflect.DeepEqual(protected, accessState(t, f, 2)) {
			t.Fatal("cross-group mutation")
		}
		var n int64
		f.db.Table("sidebar_akses").Where("group_id=5").Count(&n)
		if n != int64(len(accessItems(fresh, 4))) {
			t.Fatal("extra grants")
		}
	})
	t.Run("ambiguous stored grants fail closed", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec("DROP INDEX sidebar_group_grant_unique")
		f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(2,4,1,0,0,0)`)
		_, e := (services.Administration{DB: f.db, Enabled: true}).GroupAccess(context.Background(), actor(1), 2)
		assertCode(t, e, "invalid_grant_snapshot")
	})
}

func TestGroupsV2ParentSemanticsAndWriters(t *testing.T) {
	t.Run("parent is not inherited; sidebars UPDATE is not required", func(t *testing.T) {
		f := usersSetup(t)
		f.db.Exec(`INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES(10,'Master','master','#',1);UPDATE sidebar SET sidebar_parent_id=10 WHERE id=4;UPDATE sidebar_akses SET "update"=0 WHERE group_id=1 AND sidebar_id=3`)
		if e := grantOnce(t, f, 2, 10); e != nil {
			t.Fatal(e)
		}
		f.req(t, "GET", "/petugas/references/users/1", 3, nil, 403)
		if e := grantOnce(t, f, 2, 4); e != nil {
			t.Fatal(e)
		}
		f.req(t, "GET", "/petugas/references/users/1", 3, nil, 200)
	})
	for _, other := range []string{"deactivate", "assignment"} {
		t.Run("grants versus "+other, func(t *testing.T) {
			f := usersSetup(t)
			svc := services.Administration{DB: f.db, Enabled: true}
			if other == "assignment" {
				f.db.Exec("UPDATE users SET group_id=4 WHERE id=5")
			}
			s := accessState(t, f, 2)
			token := membership(t, f, 2)
			ch := make(chan error, 2)
			go func() { ch <- svc.Grants(context.Background(), actor(1), 2, 1, accessItems(s, 4), s.Catalog) }()
			go func() {
				if other == "deactivate" {
					ch <- svc.GroupChange(context.Background(), actor(1), models.Group{ID: 2}, 1, true, token)
				} else {
					_, e := svc.SaveUser(context.Background(), actor(1), models.User{ID: 5, GroupID: 2, Username: "user5", Email: "user5@example.invalid", Nama: "Assigned"}, 1, "")
					ch <- e
				}
			}()
			a, b := <-ch, <-ch
			if other == "deactivate" {
				if (a == nil) == (b == nil) {
					t.Fatal("one target revision winner required")
				}
			} else if a != nil || b != nil {
				t.Fatalf("assignment and grant changes must serialize: %v %v", a, b)
			}
			if e := svc.Read(context.Background(), actor(1), "groups"); e != nil {
				t.Fatal("recovery lost")
			}
		})
	}
}

func TestGroupsV2FlutterHTTP(t *testing.T) {
	testGroupsV2FlutterHTTP(t, false)
}
func TestGroupsV21FlutterHTTP(t *testing.T) {
	testGroupsV2FlutterHTTP(t, true)
}
func testGroupsV2FlutterHTTP(t *testing.T, full bool) {
	if os.Getenv("NOTARIS_GROUPS_V2_FLUTTER_E2E") != "1" {
		t.Skip("Groups V2 Flutter opt-in")
	}
	f := usersSetup(t)
	if full {
		groupsV21Fixture(t, f)
	} else {
		f.db.Exec(`INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES(10,0,'Master','master','#','folder',10,1),(11,0,'Historis','historis','/historis','archive',11,0); UPDATE sidebar SET sidebar_parent_id=10 WHERE id=4; INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(2,11,1,1,0,0)`)
	}
	before := accessState(t, f, 2)
	role := fmt.Sprintf("groups_access_runtime_%d", time.Now().UnixNano())
	var schema string
	f.db.Raw("SELECT current_schema()").Scan(&schema)
	if e := f.db.Exec("CREATE ROLE " + role + ";GRANT USAGE ON SCHEMA " + schema + " TO " + role + ";GRANT SELECT ON users,groups,sidebar,sidebar_akses TO " + role + ";GRANT UPDATE(revision) ON groups TO " + role + ";GRANT INSERT ON sidebar_akses,administrative_audit TO " + role + ";GRANT UPDATE(\"read\",\"create\",\"update\",\"delete\",updated_by,updated_at) ON sidebar_akses TO " + role + ";GRANT USAGE ON SEQUENCE sidebar_akses_id_seq,administrative_audit_id_seq TO " + role).Error; e != nil {
		t.Fatal(e)
	}
	cfg, e := pgx.ParseConfig(os.Getenv("NOTARIS_USERS_SECURITY_TEST_DSN"))
	if e != nil {
		t.Fatal("owned test config")
	}
	cfg.RuntimeParams["role"] = role
	cfg.RuntimeParams["search_path"] = schema
	pool := stdlib.OpenDB(*cfg)
	limited, e := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if e != nil {
		t.Fatal("runtime DB")
	}
	t.Cleanup(func() {
		pool.Close()
		database.DB = f.db
		f.db.Exec("DROP OWNED BY " + role)
		f.db.Exec("DROP ROLE " + role)
	})
	var current string
	if limited.Raw("SELECT current_user").Scan(&current).Error != nil || current != role {
		t.Fatal("runtime role bypass")
	}
	database.DB = limited
	f.api = SetupRouter(f.cfg, controllers.NewHealthController(), nil, nil, nil, nil, controllers.NewGroupController(), controllers.NewUserController(), controllers.NewAuthController(services.NewAuthService(f.cfg)), controllers.NewMeController(), controllers.NewSidebarController(), controllers.NewSidebarAccessController(services.NewSidebarService()))
	server := httptest.NewServer(f.api)
	defer server.Close()
	file := "test/e2e/groups_v2_http_test.dart"
	if full {
		file = "test/e2e/groups_v21_http_test.dart"
	}
	cmd := exec.Command("flutter.bat", "test", "--no-pub", file, "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	token := f.token(1, nil)
	member := f.token(3, nil)
	if full {
		// Match real AuthService.login claims, required by local financial reads.
		member = f.token(3, func(c jwt.MapClaims) { c["gid"] = 2 })
	}
	cmd.Env = append(os.Environ(), "NOTARIS_GROUPS_V2_HTTP="+server.URL+"/api/v1", "NOTARIS_GROUPS_V2_TOKEN="+token, "NOTARIS_GROUPS_V2_MEMBER="+member)
	if full {
		// Surface bounded, token-redacted test diagnostics while native I/O is
		// running rather than concealing a teardown failure until the timeout.
		pipe, err := cmd.StdoutPipe()
		if err != nil {
			t.Fatal("test output pipe")
		}
		cmd.Stderr = cmd.Stdout
		if cmd.Start() != nil {
			t.Fatal("start Flutter test")
		}
		scan := bufio.NewScanner(pipe)
		scan.Buffer(make([]byte, 4096), 1<<20)
		for scan.Scan() {
			t.Log(strings.ReplaceAll(strings.ReplaceAll(scan.Text(), token, "[REDACTED]"), member, "[REDACTED]"))
		}
		if err := cmd.Wait(); err != nil || scan.Err() != nil {
			t.Fatal("Groups V2.1 Flutter HTTP failed; see sanitized output")
		}
	} else {
		output, e := cmd.CombinedOutput()
		safe := strings.ReplaceAll(strings.ReplaceAll(string(output), token, "[REDACTED]"), member, "[REDACTED]")
		if e != nil {
			t.Fatalf("Groups V2 Flutter HTTP: %s", safe)
		}
		t.Log(safe)
	}
	after := accessState(t, f, 2)
	if after.Group.Revision != 3 {
		t.Fatal("UI save/revoke not committed")
	}
	for i, row := range after.Entries {
		if !row.Editable && !reflect.DeepEqual(row, before.Entries[i]) {
			t.Fatal("historical grant lost")
		}
	}
	var count int64
	f.db.Table("administrative_audit").Where("action='group_grants' AND result='success'").Count(&count)
	if count != 2 {
		t.Fatal("audit count")
	}
}

func groupsV21Fixture(t *testing.T, f usersFixture) {
	t.Helper()
	if e := f.db.Exec("DELETE FROM sidebar_akses; DELETE FROM sidebar").Error; e != nil {
		t.Fatal(e)
	}
	rows := devfixture.GroupsAcceptanceCatalog()
	for _, row := range rows {
		if e := f.db.Exec("INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES(?,?,?,?,?,?,?,?)", row.ID, row.SidebarParentID, row.SidebarNama, row.SidebarKode, row.SidebarRoute, row.SidebarIcon, row.SidebarIndex, row.Status).Error; e != nil {
			t.Fatal(e)
		}
	}
	if e := f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT 1,id,1,1,1,1 FROM sidebar WHERE status=1;
INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT 2,id,0,0,0,0 FROM sidebar WHERE id NOT IN(20,21);
INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") VALUES(2,20,1,1,0,0),(2,21,1,0,1,0)`).Error; e != nil {
		t.Fatal(e)
	}
}

func TestGroupsV21FullCatalog(t *testing.T) {
	f := usersSetup(t)
	groupsV21Fixture(t, f)
	s := accessState(t, f, 2)
	if len(s.Entries) != 21 || len(accessItems(s, 0)) != 19 {
		t.Fatal("full catalog coverage")
	}
	codes := map[string]bool{}
	for _, row := range s.Entries {
		codes[row.Sidebar.Code] = true
	}
	for _, code := range []string{"transaksi", "monitoring", "pengeluaran", "piutang", "penghasilan", "pekerjaan_notaris", "pekerjaan_ppat", "kategori_pekerjaan", "jenis_pengeluaran", "laporan", "laporan_materai", "laporan_pendapatan", "system", "users", "groups", "sidebars", "petugas", "pemohon", "master"} {
		if !codes[code] {
			t.Fatal("missing canonical code", code)
		}
	}
	for _, alias := range []string{"materai", "pendapatan", "konfigurasi", "konfigurasi_umum", "pekerjaan-notaris", "dashboard", "recycle_bin"} {
		if codes[alias] {
			t.Fatal("unsupported/duplicate permission", alias)
		}
	}
	// Read grant is necessary, never sufficient for Superadmin administration.
	items := accessItems(s, 0)
	for i := range items {
		items[i].Read = 1
	}
	f.req(t, "GET", "/sidebars", 3, nil, 403)
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, items), 200)
	f.req(t, "GET", "/sidebars", 3, nil, 200)
	f.req(t, "GET", "/users", 3, nil, 403)
	f.req(t, "GET", "/groups", 3, nil, 403)
	f.req(t, "GET", "/petugas/references/users/1", 3, nil, 200)
	after := accessState(t, f, 2)
	for i, row := range after.Entries {
		if !row.Editable && !reflect.DeepEqual(row, s.Entries[i]) {
			t.Fatal("frozen grant changed")
		}
	}
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, items), 409)
	f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(after, accessItems(after, 0)), 200)
	f.req(t, "GET", "/sidebars", 3, nil, 403)
	f.req(t, "GET", "/petugas/references/users/1", 3, nil, 403)
}

func TestGroupsV21CanonicalMiddleware(t *testing.T) {
	f := usersSetup(t)
	groupsV21Fixture(t, f)
	// Authorization middleware only, not invented operational CRUD endpoints.
	probe := gin.New()
	for _, code := range []string{"transaksi", "petugas", "pemohon", "pekerjaan_notaris", "pekerjaan_ppat", "kategori_pekerjaan", "jenis_pengeluaran", "master", "pekerjaan-notaris"} {
		for _, action := range []string{"read", "create", "update", "delete"} {
			probe.GET("/"+code+"/"+action, middleware.JWTAuth(f.cfg), middleware.RequirePermission(repositories.NewSidebarAccessRepository(), code, action), func(c *gin.Context) { c.Status(204) })
		}
	}
	for _, enabled := range []bool{false, true, false} {
		s := accessState(t, f, 2)
		items := accessItems(s, 0)
		if enabled {
			for i := range items {
				items[i].Read = 1
				items[i].Create = 1
				items[i].Update = 1
				items[i].Delete = 1
			}
		}
		f.req(t, "PUT", "/groups/2/sidebar-access", 1, grantBody(s, items), 200)
		for _, code := range []string{"transaksi", "petugas", "pemohon", "pekerjaan_notaris", "pekerjaan_ppat", "kategori_pekerjaan", "jenis_pengeluaran", "master", "pekerjaan-notaris"} {
			for _, action := range []string{"read", "create", "update", "delete"} {
				r := httptest.NewRequest("GET", "/"+code+"/"+action, nil)
				r.Header.Set("Authorization", "Bearer "+f.token(3, nil))
				w := httptest.NewRecorder()
				probe.ServeHTTP(w, r)
				want := 403
				if enabled && code != "master" && code != "pekerjaan-notaris" {
					want = 204
				}
				if w.Code != want {
					t.Fatalf("%s/%s: %d wanted %d", code, action, w.Code, want)
				}
			}
		}
	}
}
