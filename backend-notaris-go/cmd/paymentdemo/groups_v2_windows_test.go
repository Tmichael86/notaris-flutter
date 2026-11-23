package main

import (
	"net/http/httptest"
	"os"
	"reflect"
	"testing"
)

func TestGroupsV2ManifestIsolation(t *testing.T) {
	id := "00000000000000000000000000000000"
	v2, v1 := groupsV2ManifestFor(id), groupsManifestFor(id)
	if v2.Port == v1.Port || v2.BaseURL == v1.BaseURL || v2.Scope == v1.Scope || v2.Database == v1.Database {
		t.Fatal("V1 target reused")
	}
	if _, _, e := groupsV2Root("../daily"); e == nil {
		t.Fatal("unscoped path accepted")
	}
	full := groupsV2CatalogManifest(id, true)
	if full.Catalog != "full-v2.1" || full == v2 || groupsV2CatalogManifest(id, false) != v2 {
		t.Fatal("catalog mode not independently bound")
	}
}
func TestGroupsV2OwnedReadOnly(t *testing.T) {
	id := os.Getenv("NOTARIS_GROUPS_V2_TEST_PROFILE")
	if id == "" {
		t.Skip("new owned Groups V2 profile opt-in unset")
	}
	_, secrets, e := groupsV2Root(id)
	if e != nil {
		t.Fatal("profile binding")
	}
	owner, e := groupsV2Open(id, true, false)
	if e != nil {
		t.Fatal("owner target")
	}
	defer closePromo(owner)
	app, e := groupsV2Open(id, false, false)
	if e != nil {
		t.Fatal("runtime target")
	}
	defer closePromo(app)
	before, e := groupsV2State(owner)
	if e != nil {
		t.Fatal("state")
	}
	server := httptest.NewServer(groupsV2Handler(id, app, secrets))
	defer server.Close()
	if e = groupsV2HTTPCheck(id, secrets, server.URL); e != nil {
		t.Fatal("actual HTTP binding/auth")
	}
	var p struct{ Metadata, Members, Grants, Revision bool }
	if e = app.Raw(`SELECT has_table_privilege(current_user,'sidebar','UPDATE,DELETE,INSERT') AS metadata,has_table_privilege(current_user,'users','UPDATE,DELETE,INSERT') AS members,has_column_privilege(current_user,'sidebar_akses','read','UPDATE') AS grants,has_column_privilege(current_user,'groups','revision','UPDATE') AS revision`).Scan(&p).Error; e != nil || p.Metadata || p.Members || !p.Grants || !p.Revision {
		t.Fatal("runtime privilege drift")
	}
	after, e := groupsV2State(owner)
	if e != nil || !reflect.DeepEqual(before, after) {
		t.Fatal("read-only check mutated data")
	}
}
