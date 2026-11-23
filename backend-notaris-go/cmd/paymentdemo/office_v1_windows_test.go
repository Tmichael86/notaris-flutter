package main

import (
	"net/http/httptest"
	"os"
	"reflect"
	"testing"
)

func TestOfficeV1ManifestIsolation(t *testing.T) {
	id := "00000000000000000000000000000000"
	s, g := officeV1ManifestFor(id), groupsV2ManifestFor(id)
	if s.Port == g.Port || s.BaseURL == g.BaseURL || s.Database == g.Database || s.Scope == g.Scope {
		t.Fatal("Groups target reused")
	}
	if _, _, e := officeV1Root("../daily"); e == nil {
		t.Fatal("unscoped path accepted")
	}
}
func TestOfficeV1OwnedReadOnly(t *testing.T) {
	id := os.Getenv("NOTARIS_OFFICE_V1_TEST_PROFILE")
	if id == "" {
		t.Skip("owned Sidebars profile opt-in")
	}
	_, secret, e := officeV1Root(id)
	if e != nil {
		t.Fatal("profile binding")
	}
	owner, e := officeV1Open(id, true, false)
	if e != nil {
		t.Fatal("owner binding")
	}
	defer closePromo(owner)
	app, e := officeV1Open(id, false, false)
	if e != nil {
		t.Fatal("app binding")
	}
	defer closePromo(app)
	before, e := officeV1State(owner)
	if e != nil {
		t.Fatal("baseline")
	}
	server := httptest.NewServer(officeV1Handler(id, app, secret))
	defer server.Close()
	if officeV1HTTPCheck(id, secret, server.URL) != nil {
		t.Fatal("real HTTP authorized/denied check")
	}
	var writable bool
	if app.Raw(`SELECT bool_or(has_table_privilege(current_user,quote_ident(tablename),'INSERT,UPDATE,DELETE,TRUNCATE')) FROM pg_tables WHERE schemaname='public'`).Scan(&writable).Error != nil || writable {
		t.Fatal("runtime write privilege")
	}
	var mode string
	app.Raw("SHOW transaction_read_only").Scan(&mode)
	if mode != "on" {
		t.Fatal("runtime not read-only")
	}
	after, e := officeV1State(owner)
	if e != nil || !reflect.DeepEqual(before, after) {
		t.Fatal("HTTP reads changed protected state")
	}
}
