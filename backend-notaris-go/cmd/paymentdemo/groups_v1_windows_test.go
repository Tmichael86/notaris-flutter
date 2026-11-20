package main

import (
	"net/http/httptest"
	"os"
	"testing"
)

func TestGroupsV1ManifestIsolation(t *testing.T) {
	id := "00000000000000000000000000000000"
	u, p := groupsManifestFor(id), usersManifestFor(id)
	if u.Port == p.Port || u.BaseURL == p.BaseURL || u.Database == p.Database || u.Scope == p.Scope {
		t.Fatal("cross-profile target collision")
	}
	if _, _, e := groupsRoot("../daily"); e == nil {
		t.Fatal("free-form root accepted")
	}
}

func TestGroupsV1OwnedReadOnlyAttestation(t *testing.T) {
	id := os.Getenv("NOTARIS_GROUPS_V1_TEST_PROFILE")
	if id == "" {
		t.Skip("new Groups-owned profile opt-in unset")
	}
	_, s, e := groupsRoot(id)
	if e != nil {
		t.Fatal("Groups owner/DPAPI/manifest mismatch")
	}
	app, e := groupsOpen(id, false, false)
	if e != nil {
		t.Fatal("application target mismatch")
	}
	defer closePromo(app)
	owner, e := groupsOpen(id, true, false)
	if e != nil {
		t.Fatal("owner target mismatch")
	}
	defer closePromo(owner)
	before, e := groupsState(owner)
	if e != nil {
		t.Fatal("initial integrity")
	}
	handler := groupsHandler(id, app, s)
	server := httptest.NewServer(handler)
	defer server.Close()
	if groupsHTTPCheck(id, s, server.URL) != nil {
		t.Fatal("actual authenticated HTTP attestation/list")
	}
	for _, path := range []string{"/api/v1/users", "/api/v1/groups/201/sidebar-access", "/api/v1/transaksi-notaris/sync/create"} {
		r := httptest.NewRecorder()
		handler.ServeHTTP(r, httptest.NewRequest("POST", path, nil))
		if r.Code != 404 {
			t.Fatal("unapproved writer registered")
		}
	}
	var privilege struct{ UsersInsert, GroupsWrite, UserIdentity, UserRevocation, Audit bool }
	if app.Raw(`SELECT has_table_privilege(current_user,'users','INSERT') AS users_insert,
 has_table_privilege(current_user,'groups','INSERT,UPDATE') AS groups_write,
 has_column_privilege(current_user,'users','group_id','UPDATE') AS user_identity,
 has_column_privilege(current_user,'users','security_version','UPDATE') AS user_revocation,
 has_table_privilege(current_user,'administrative_audit','UPDATE,DELETE') AS audit`).Scan(&privilege).Error != nil || privilege.UsersInsert || !privilege.GroupsWrite || privilege.UserIdentity || !privilege.UserRevocation || privilege.Audit {
		t.Fatal("least privilege mismatch")
	}
	after, e := groupsState(owner)
	if e != nil {
		t.Fatal("post integrity")
	}
	if len(before["audits"].([]map[string]any)) != 0 || len(after["audits"].([]map[string]any)) != 0 {
		t.Fatal("read-only verification wrote audit")
	}
	if before["fingerprints"].(map[string]string)["user_identity"] != after["fingerprints"].(map[string]string)["user_identity"] {
		t.Fatal("protected state changed")
	}
}
