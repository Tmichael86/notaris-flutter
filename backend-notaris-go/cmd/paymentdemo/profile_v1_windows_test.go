package main

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
)

func TestProfileV1ManifestIsolation(t *testing.T) {
	id := "00000000000000000000000000000000"
	p, o := profileV1ManifestFor(id), officeV1ManifestFor(id)
	if p.Scope == o.Scope || p.Database == o.Database || p.Port == o.Port || p.BaseURL == o.BaseURL {
		t.Fatal("old profile target reused")
	}
	if _, _, e := profileV1Root("../development"); e == nil {
		t.Fatal("unscoped path")
	}
}
func TestProfileV1OwnedSafety(t *testing.T) {
	id := os.Getenv("NOTARIS_PROFILE_V1_TEST_PROFILE")
	if id == "" {
		t.Skip("owned profile opt-in")
	}
	_, secret, e := profileV1Root(id)
	if e != nil {
		t.Fatal("binding")
	}
	owner, e := profileV1Open(id, true, false)
	if e != nil {
		t.Fatal("owner")
	}
	defer closePromo(owner)
	app, e := profileV1Open(id, false, false)
	if e != nil {
		t.Fatal("app")
	}
	defer closePromo(app)
	before, e := profileV1State(owner)
	if e != nil {
		t.Fatal("state")
	}
	server := httptest.NewServer(profileV1Handler(id, app, secret))
	defer server.Close()
	if profileV1HTTPCheck(id, secret, server.URL) != nil {
		t.Fatal("HTTP own/read/forged")
	}
	for _, name := range []string{"inactive.profile", "groupinactive.profile"} {
		body, _ := json.Marshal(map[string]string{"username": name, "password": secret.Passwords[name]})
		res, e := groupsV2Client().Post(server.URL+"/api/v1/auth/login", "application/json", strings.NewReader(string(body)))
		if e != nil {
			t.Fatal("inactive HTTP")
		}
		res.Body.Close()
		if res.StatusCode != 401 {
			t.Fatal("inactive accepted")
		}
	}
	var users, groups int64
	owner.Table("users").Count(&users)
	owner.Table("groups").Count(&groups)
	if users != 6 || groups != 5 {
		t.Fatal("fixture counts")
	}
	t.Log("fixture users=6 groups=5; inactive User and Group HTTP=401")
	after, e := profileV1State(owner)
	if e != nil || !reflect.DeepEqual(before, after) {
		t.Fatal("read/forged changed state")
	}
}
