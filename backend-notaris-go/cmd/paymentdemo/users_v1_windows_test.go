package main

import (
	"net/http/httptest"
	"os"
	"testing"
)

func TestUsersV1ManifestIsolation(t *testing.T) {
	id := "00000000000000000000000000000000"
	u, p := usersManifestFor(id), promoManifest(id)
	if u.Port == p.Port || u.BaseURL == p.BaseURL || u.Database == p.Database || u.Scope == p.Scope {
		t.Fatal("cross-profile target collision")
	}
	if _, _, e := usersRoot("../daily"); e == nil {
		t.Fatal("free-form root accepted")
	}
}

func TestUsersV1OwnedReadOnlyAttestation(t *testing.T) {
	id := os.Getenv("NOTARIS_USERS_V1_TEST_PROFILE")
	if id == "" {
		t.Skip("new Users-owned profile opt-in unset")
	}
	_, s, e := usersRoot(id)
	if e != nil {
		t.Fatal("Users owner/DPAPI/manifest mismatch")
	}
	app, e := usersOpen(id, false, false)
	if e != nil {
		t.Fatal("application target mismatch")
	}
	defer closePromo(app)
	owner, e := usersOpen(id, true, false)
	if e != nil {
		t.Fatal("owner target mismatch")
	}
	defer closePromo(owner)
	before, e := usersState(owner)
	if e != nil {
		t.Fatal("initial integrity")
	}
	handler := usersHandler(id, app, s)
	server := httptest.NewServer(handler)
	defer server.Close()
	if usersHTTPCheck(id, s, server.URL) != nil {
		t.Fatal("actual authenticated HTTP attestation/list")
	}
	for _, path := range []string{"/api/v1/groups", "/api/v1/groups/201/sidebar-access", "/api/v1/transaksi-notaris/sync/create"} {
		r := httptest.NewRecorder()
		handler.ServeHTTP(r, httptest.NewRequest("POST", path, nil))
		if r.Code != 404 {
			t.Fatal("unapproved writer registered")
		}
	}
	var privilege struct {
		Users  bool
		Groups bool
		Audit  bool
	}
	if app.Raw(`SELECT has_table_privilege(current_user,'users','INSERT,UPDATE') AS users,has_table_privilege(current_user,'groups','UPDATE') AS groups,has_table_privilege(current_user,'administrative_audit','UPDATE,DELETE') AS audit`).Scan(&privilege).Error != nil || !privilege.Users || privilege.Groups || privilege.Audit {
		t.Fatal("application grants")
	}
	after, e := usersState(owner)
	if e != nil {
		t.Fatal("post integrity")
	}
	if len(before["audits"].([]map[string]any)) != 0 || len(after["audits"].([]map[string]any)) != 0 {
		t.Fatal("read-only verification wrote audit")
	}
	if before["fingerprints"].(map[string]string)["protected_users"] != after["fingerprints"].(map[string]string)["protected_users"] {
		t.Fatal("protected state changed")
	}
}
