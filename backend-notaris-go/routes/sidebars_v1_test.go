package routes

import (
	"backend-notaris-go/dto/response"
	"backend-notaris-go/internal/devfixture"
	"backend-notaris-go/services"
	"context"
	"encoding/json"
	"github.com/golang-jwt/jwt/v5"
	"net/http/httptest"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"testing"
	"time"
)

func sidebarsFixture(t *testing.T) usersFixture {
	f := usersSetup(t)
	groupsV21Fixture(t, f)
	if e := f.db.Exec("ALTER TABLE sidebar ADD COLUMN created_at timestamptz; INSERT INTO sidebar_akses(group_id,sidebar_id,\"read\",\"create\",\"update\",\"delete\") VALUES(2,3,1,0,0,0) ON CONFLICT(group_id,sidebar_id) DO UPDATE SET \"read\"=1").Error; e != nil {
		t.Fatal(e)
	}
	for _, row := range devfixture.SidebarsAcceptanceCatalog()[21:] {
		if e := f.db.Exec("INSERT INTO sidebar(id,sidebar_parent_id,sidebar_nama,sidebar_kode,sidebar_route,sidebar_icon,sidebar_index,status) VALUES(?,?,?,?,?,?,?,?)", row.ID, row.SidebarParentID, row.SidebarNama, row.SidebarKode, row.SidebarRoute, row.SidebarIcon, row.SidebarIndex, row.Status).Error; e != nil {
			t.Fatal(e)
		}
	}
	if e := f.db.Exec("UPDATE sidebar SET created_at='2026-11-20T00:00:00Z'; UPDATE sidebar SET sidebar_icon=NULL,created_at=NULL WHERE id=38").Error; e != nil {
		t.Fatal(e)
	}
	return f
}
func catalogPage(t *testing.T, f usersFixture, path string) response.SidebarCatalogPage {
	t.Helper()
	raw := f.req(t, "GET", "/sidebars/catalog"+path, 3, nil, 200)
	b, _ := json.Marshal(raw["data"])
	var page response.SidebarCatalogPage
	if json.Unmarshal(b, &page) != nil {
		t.Fatal("DTO")
	}
	return page
}
func TestSidebarsV1Catalog(t *testing.T) {
	f := sidebarsFixture(t)
	before := accessState(t, f, 2)
	var catalogBefore, usersBefore, grantsBefore string
	f.db.Raw("SELECT json_agg(s ORDER BY id)::text FROM sidebar s").Scan(&catalogBefore)
	f.db.Raw("SELECT json_agg(u ORDER BY id)::text FROM users u").Scan(&usersBefore)
	f.db.Raw("SELECT json_agg(a ORDER BY id)::text FROM sidebar_akses a").Scan(&grantsBefore)
	all := catalogPage(t, f, "")
	if all.Total != 25 || all.TotalPages != 3 || len(all.Items) != 10 || all.Items[4].ID != 35 {
		t.Fatalf("count/order: %+v", all)
	}
	ids := map[uint]bool{}
	for _, q := range []string{"?page=1", "?page=2", "?page=3"} {
		for _, row := range catalogPage(t, f, q).Items {
			if ids[row.ID] {
				t.Fatal("duplicate page")
			}
			ids[row.ID] = true
		}
	}
	if len(ids) != 25 {
		t.Fatal("missing rows")
	}
	if p := catalogPage(t, f, "?status=active"); p.Total != 23 || p.TotalPages != 3 {
		t.Fatal("active count")
	}
	if p := catalogPage(t, f, "?status=inactive"); p.Total != 2 || p.TotalPages != 1 {
		t.Fatal("inactive count")
	}
	for _, q := range []string{"?search=%25_", "?search=literal_catalog"} {
		p := catalogPage(t, f, q)
		if p.Total != 1 || p.Items[0].ID != 37 {
			t.Fatal("literal search")
		}
	}
	for _, q := range []string{"?search=%27%20OR%201=1--", "?search=does-not-exist", "?page=100"} {
		if len(catalogPage(t, f, q).Items) != 0 {
			t.Fatal("search/bounds")
		}
	}
	if p := catalogPage(t, f, "?search=Parent%20tidak"); p.Items[0].ParentExists || *p.Items[0].ParentID != 999 {
		t.Fatal("orphan lost")
	}
	if p := catalogPage(t, f, "?search=anak_arsip"); !p.Items[0].ParentExists || *p.Items[0].ParentStatus != 0 {
		t.Fatal("inactive parent lost")
	}
	if p := catalogPage(t, f, "?search=detail_tingkat"); *p.Items[0].ParentID != 36 || p.Items[0].Icon != nil && *p.Items[0].Icon != "" {
		t.Fatal("deep/empty icon")
	}
	legacy := f.req(t, "GET", "/sidebars", 3, nil, 200)["data"].([]any)
	if len(legacy) != 23 {
		t.Fatal("legacy active-only contract changed")
	}
	for _, v := range legacy {
		if v.(map[string]any)["status"] != float64(1) {
			t.Fatal("inactive row leaked to legacy endpoint")
		}
	}
	tree := f.req(t, "GET", "/sidebars/tree", 3, nil, 200)["data"].([]any)
	if len(tree) != 9 {
		t.Fatal("legacy two-level tree changed")
	}
	detail := f.req(t, "GET", "/sidebars/20", 3, nil, 200)["data"].(map[string]any)
	if detail["status"] != float64(0) {
		t.Fatal("legacy ID lookup changed")
	}
	data := f.req(t, "GET", "/sidebars/catalog", 3, nil, 200)["data"].(map[string]any)
	for _, v := range data["items"].([]any) {
		for _, forbidden := range []string{"password", "created_by", "updated_by", "security_version", "read", "create", "update", "delete"} {
			if _, ok := v.(map[string]any)[forbidden]; ok {
				t.Fatal("protected field leaked")
			}
		}
	}
	if !reflect.DeepEqual(before, accessState(t, f, 2)) {
		t.Fatal("Groups snapshot changed")
	}
	for query, want := range map[string]string{"SELECT json_agg(s ORDER BY id)::text FROM sidebar s": catalogBefore, "SELECT json_agg(u ORDER BY id)::text FROM users u": usersBefore, "SELECT json_agg(a ORDER BY id)::text FROM sidebar_akses a": grantsBefore} {
		var got string
		f.db.Raw(query).Scan(&got)
		if got != want {
			t.Fatal("read wrote data")
		}
	}
	var audits int64
	f.db.Table("administrative_audit").Count(&audits)
	if audits != 0 {
		t.Fatal("read audit mutation")
	}
}

func TestSidebarsV1HistoricalMetadata(t *testing.T) {
	f := sidebarsFixture(t)
	// Simulate a pre-P0 legacy catalog in this test's owned schema only. The
	// catalog does not certify these definitions as valid authorization grants.
	if e := f.db.Exec(`ALTER TABLE sidebar DROP CONSTRAINT sidebar_security_valid; DROP INDEX sidebar_code_unique;
UPDATE sidebar SET sidebar_nama=NULL,sidebar_icon=NULL,sidebar_index=NULL,created_at=NULL,status=NULL,sidebar_kode='petugas' WHERE id=37`).Error; e != nil {
		t.Fatal(e)
	}
	var before, after string
	f.db.Raw("SELECT row_to_json(s)::text FROM sidebar s WHERE id=37").Scan(&before)
	p := catalogPage(t, f, "?search=petugas")
	if p.Total != 2 {
		t.Fatal("duplicate code discarded")
	}
	var found bool
	for _, r := range p.Items {
		if r.ID == 37 {
			found = true
			if r.Name != nil || r.Icon != nil || r.Status != nil || r.Index != nil {
				t.Fatal("legacy metadata normalized")
			}
		}
	}
	if !found {
		t.Fatal("historical record lost")
	}
	f.db.Raw("SELECT row_to_json(s)::text FROM sidebar s WHERE id=37").Scan(&after)
	if before != after {
		t.Fatal("catalog repaired source")
	}
}

func TestSidebarsV1TimestampWithoutZone(t *testing.T) {
	f := sidebarsFixture(t)
	if e := f.db.Exec("ALTER TABLE sidebar ALTER COLUMN created_at TYPE timestamp without time zone USING created_at AT TIME ZONE 'UTC'").Error; e != nil {
		t.Fatal(e)
	}
	p := catalogPage(t, f, "?search=literal_catalog")
	if p.Total != 1 || p.Items[0].CreatedAt == nil || *p.Items[0].CreatedAt != "2026-11-20T00:00:00" {
		t.Fatal("timestamp was rejected or assigned an invented zone")
	}
}
func TestSidebarsV1AuthorizationAndFilters(t *testing.T) {
	f := sidebarsFixture(t)
	for _, q := range []string{"?page=0", "?page=-1", "?page=1000001", "?page_size=51", "?page_size=0", "?status=2", "?status=", "?page=x", "?page=1&page=2", "?unexpected=1", "?search=" + strings.Repeat("a", 201)} {
		f.req(t, "GET", "/sidebars/catalog"+q, 3, nil, 400)
	}
	f.req(t, "GET", "/sidebars/catalog", 0, nil, 401)
	f.req(t, "GET", "/sidebars/catalog", 3, nil, 200) // ordinary user, not Superadmin
	for _, change := range []func(jwt.MapClaims){func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }, func(c jwt.MapClaims) { c["sv"] = 0 }} {
		r := httptest.NewRequest("GET", "/api/v1/sidebars/catalog", nil)
		r.Header.Set("Authorization", "Bearer "+f.token(3, change))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, r)
		if w.Code != 401 {
			t.Fatal("invalid token accepted")
		}
	}
	f.db.Exec("UPDATE sidebar_akses SET \"read\"=0 WHERE group_id=2 AND sidebar_id=3")
	f.req(t, "GET", "/sidebars/catalog", 3, nil, 403)
	f.db.Exec("UPDATE groups SET status=0 WHERE id=2")
	f.req(t, "GET", "/sidebars/catalog", 3, nil, 401)
}
func TestSidebarsV1FlutterHTTP(t *testing.T) {
	if os.Getenv("NOTARIS_SIDEBARS_V1_FLUTTER_E2E") != "1" {
		t.Skip("HTTP Flutter opt-in")
	}
	f := sidebarsFixture(t)
	before := accessState(t, f, 2)
	server := httptest.NewServer(f.api)
	defer server.Close()
	token := f.token(3, func(c jwt.MapClaims) { c["gid"] = 2 })
	cmd := exec.Command("flutter.bat", "test", "--no-pub", "test/e2e/sidebars_v1_http_test.dart", "--reporter", "expanded")
	cmd.Dir = "../../frontend_notaris"
	cmd.Env = append(os.Environ(), "NOTARIS_SIDEBARS_V1_HTTP="+server.URL+"/api/v1", "NOTARIS_SIDEBARS_V1_TOKEN="+token)
	output, e := cmd.CombinedOutput()
	safe := strings.ReplaceAll(string(output), token, "[REDACTED]")
	if e != nil {
		t.Fatalf("Flutter HTTP: %s", safe)
	}
	t.Log(safe)
	if !reflect.DeepEqual(before, accessState(t, f, 2)) {
		t.Fatal("UI read changed grants")
	}
	if (services.Administration{DB: f.db, Enabled: true}).Ready(context.Background()) != nil {
		t.Fatal("security regression")
	}
}
