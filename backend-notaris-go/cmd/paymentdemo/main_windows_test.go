package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"os"
	"path/filepath"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func testProfile(t *testing.T) (string, string, ed25519.PrivateKey) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	root, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	id := profileID(public)
	for name, content := range map[string][]byte{"owner": []byte(id), "public.key": public} {
		if err := writeNew(filepath.Join(root, name), content); err != nil {
			t.Fatal(err)
		}
	}
	return root, id, private
}

func testSession(id string, a account, now time.Time) verifiedSession {
	permission := access{Read: 1, Create: a.Create, Update: a.Update}
	permission.Sidebar.Code = "transaksi"
	permission.Sidebar.Status = 1
	return verifiedSession{
		Profile: id, Username: a.Username, UserID: a.ID, GroupID: a.ID,
		UserName: a.Name, GroupName: a.Name, GroupType: a.Role,
		VerifiedAt: now.Add(-time.Minute), ExpiresAt: now.Add(time.Minute),
		Sidebars: []access{permission},
	}
}

func TestWindowsOfflineUnlock(t *testing.T) {
	root, id, private := testProfile(t)
	now := time.Now()
	passwords := []string{"operator-test-password", "admin-test-password", "reader-test-password"}
	for i, a := range accounts {
		hash, err := bcrypt.GenerateFromPassword([]byte(passwords[i]), bcrypt.MinCost)
		if err != nil {
			t.Fatal(err)
		}
		session := testSession(id, a, now)
		if err := seal(root, id, a.Username, storedSession{session, hash}, private); err != nil {
			t.Fatal(err)
		}
		var stored storedSession
		if err := unseal(root, id, a.Username, &stored); err != nil {
			t.Fatalf("could not unseal %s: %v", a.Username, err)
		}
		s, err := unlock(root, id, a, passwords[i], now)
		if err != nil || s.UserID != a.ID || s.GroupType != a.Role || s.Sidebars[0].Update != a.Update {
			t.Fatalf("verified session for %s did not round trip", a.Username)
		}
		if _, err := unlock(root, id, a, passwords[(i+1)%len(accounts)], now); err == nil {
			t.Fatal("accepted another account's password")
		}
		if _, err := unlock(root, id, a, passwords[i], session.ExpiresAt); err == nil {
			t.Fatal("accepted expired session")
		}
	}
	if _, err := lookup("102"); err == nil {
		t.Fatal("accepted user ID as login")
	}
	admin := accounts[1]
	adminFile := filepath.Join(root, admin.Username+".bin")
	sealed, err := os.ReadFile(adminFile)
	if err != nil {
		t.Fatal(err)
	}
	otherRoot, otherID, _ := testProfile(t)
	if err := writeNew(filepath.Join(otherRoot, admin.Username+".bin"), sealed); err != nil {
		t.Fatal(err)
	}
	if _, err := unlock(otherRoot, otherID, admin, passwords[1], now); err == nil {
		t.Fatal("accepted a cache from another profile")
	}
	operator := accounts[0]
	if err := os.WriteFile(filepath.Join(root, operator.Username+".bin"), sealed, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := unlock(root, id, operator, passwords[1], now); err == nil {
		t.Fatal("accepted a cache renamed to another account")
	}
	sealed[len(sealed)-1] ^= 1
	if err := os.WriteFile(adminFile, sealed, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := unlock(root, id, admin, passwords[1], now); err == nil {
		t.Fatal("accepted a tampered cache")
	}
}

func TestRoleAndPermissionsMustMatchAuthenticatedAccount(t *testing.T) {
	now := time.Now()
	a := accounts[0]
	session := testSession("profile", a, now)
	session.GroupType = "superadmin"
	if session.valid("profile", a, now) {
		t.Fatal("accepted a role outside the verified account policy")
	}
	session = testSession("profile", accounts[2], now)
	session.Sidebars[0].Update = 1
	if session.valid("profile", accounts[2], now) {
		t.Fatal("accepted update permission for a reader")
	}
}

func TestMonitoringProfileUsesExplicitReadOnlySidebarPolicy(t *testing.T) {
	now := time.Now()
	for _, a := range accounts {
		s := testSession("profile", a, now)
		s.Sidebars[0].Create = 0
		s.Sidebars[0].Update = 0
		monitoring := access{}
		monitoring.Sidebar.Code, monitoring.Sidebar.Name, monitoring.Sidebar.Status = "monitoring", "Monitoring", 1
		if a.Username == "pembaca.demo" {
			monitoring.Read = 1
		}
		s.Sidebars = append([]access{monitoring}, s.Sidebars...)
		if !s.validFor("profile", a, now, "monitoring") || s.valid("profile", a, now) {
			t.Fatal("Monitoring policy accepted outside its profile or rejected valid access")
		}
		s.Sidebars[0].Read = 1 - monitoring.Read
		if s.validFor("profile", a, now, "monitoring") {
			t.Fatal("unexpected Monitoring read grant accepted")
		}
		s.Sidebars[0] = monitoring
		s.Sidebars[1].Delete = 1
		if s.validFor("profile", a, now, "monitoring") {
			t.Fatal("transaction delete grant accepted on read-only profile")
		}
	}
}

func TestExpenseProfileGrantsOnlyTheAssignedActions(t *testing.T) {
	now := time.Now()
	expected := [][2]int{{1, 1}, {0, 0}, {1, 0}}
	for i, a := range accounts {
		s := testSession("profile", a, now)
		s.Sidebars[0].Create, s.Sidebars[0].Update = 0, 0
		read, write := expected[i][0], expected[i][1]
		expense := access{Read: read, Create: write, Update: write, Delete: write}
		expense.Sidebar.Code, expense.Sidebar.Name, expense.Sidebar.Status = "pengeluaran", "Pengeluaran", 1
		s.Sidebars = append(s.Sidebars, expense)
		if !s.validFor("profile", a, now, "pengeluaran") ||
			s.valid("profile", a, now) || s.validFor("profile", a, now, "monitoring") {
			t.Fatalf("wrong scope or permission policy for %s", a.Username)
		}
		s.Sidebars[1].Delete = 1 - write
		if s.validFor("profile", a, now, "pengeluaran") {
			t.Fatal("unexpected expense delete grant accepted")
		}
	}
}

func TestMateraiProfileGrantsOnlyTheAssignedActions(t *testing.T) {
	now := time.Now()
	expected := [][2]int{{0, 0}, {1, 1}, {1, 0}}
	for i, a := range accounts {
		s := testSession("materai-test", a, now)
		s.Sidebars[0].Create, s.Sidebars[0].Update = 0, 0
		grant := access{Read: expected[i][0], Create: expected[i][1]}
		grant.Sidebar.Code, grant.Sidebar.Name, grant.Sidebar.Status = "laporan_materai", "Materai", 1
		s.Sidebars = append(s.Sidebars, grant)
		if !s.validFor("materai-test", a, now, "materai") ||
			s.validFor("other-profile", a, now, "materai") ||
			s.validFor("materai-test", a, now, "presentation") {
			t.Fatalf("Materai scope or grant differs for %s", a.Username)
		}
		s.Sidebars[1].Create = 1 - expected[i][1]
		if s.validFor("materai-test", a, now, "materai") {
			t.Fatal("unexpected Materai CREATE accepted")
		}
	}
}

func TestOwnedFilesRejectHardlinks(t *testing.T) {
	root, _, _ := testProfile(t)
	outside := filepath.Join(t.TempDir(), "unrelated.sqlite")
	if err := writeNew(outside, []byte("sentinel")); err != nil {
		t.Fatal(err)
	}
	inside := filepath.Join(root, "offline.sqlite")
	if err := os.Link(outside, inside); err != nil {
		t.Fatal(err)
	}
	if file, err := openOwnedFile(root, "offline.sqlite"); err == nil {
		file.Close()
		t.Fatal("opened an alias of a file outside the profile")
	}
	value, err := os.ReadFile(outside)
	if err != nil || string(value) != "sentinel" {
		t.Fatal("external file changed")
	}
}

// Opt in with a copy of the sealed auth files under an isolated TEMP root.
func TestProvisionedReaderHandoff(t *testing.T) {
	id := os.Getenv("NOTARIS_PAYMENT_CHECK_PROFILE")
	if id == "" {
		t.Skip("requires a copy of the provisioned auth files")
	}
	root, err := profileRoot(id)
	if err != nil {
		t.Fatal("invalid profile")
	}
	a, err := lookup("pembaca.demo")
	if err != nil {
		t.Fatal("missing reader")
	}
	var password string
	if err := unseal(root, id, "handoff-"+a.Username, &password); err != nil {
		t.Fatal("reader handoff did not open")
	}
	s, err := unlock(root, id, a, password, time.Now())
	if err != nil || s.UserID != a.ID || s.GroupType != "user" ||
		s.Sidebars[0].Read != 1 || s.Sidebars[0].Create != 0 || s.Sidebars[0].Update != 0 {
		t.Fatal("reader handoff did not unlock the expected read-only session")
	}
	if _, err := unlock(root, id, accounts[1], password, time.Now()); err == nil {
		t.Fatal("reader handoff unlocked the administrator session")
	}
}
