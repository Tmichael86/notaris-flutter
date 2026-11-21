package routes

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"testing"
	"time"

	"backend-notaris-go/config"
	"backend-notaris-go/internal/backendstartup"
	"backend-notaris-go/services"
)

func h05Config(f usersFixture) config.Config {
	c := f.cfg
	c.Environment = "staging"
	c.DeploymentID = "h05-owned-test"
	c.HTTPHost = "127.0.0.1"
	c.Port = "18081"
	c.DBHost = "127.0.0.1"
	c.DBPort = "55793"
	c.DBName = "users_security_disposable"
	c.DBUser = "postgres"
	c.DBSSLMode = "disable"
	return c
}

func TestH05RealStartupAndJWT(t *testing.T) {
	f := h04Setup(t)
	cfg := h05Config(f)
	before := h04Snapshot(t, f)
	called := 0
	listener, err := backendstartup.Open(context.Background(), cfg, f.db, func(network, address string) (net.Listener, error) {
		called++
		if network != "tcp" || address != cfg.ListenAddress() {
			t.Fatal("listener target differs from reviewed configuration")
		}
		// Only this test's OS-assigned socket; never use operational HTTP ports.
		return net.Listen("tcp", "127.0.0.1:0")
	})
	if err != nil || called != 1 {
		t.Fatalf("complete P0 startup rejected: %v", err)
	}
	server := &http.Server{Handler: f.api}
	done := make(chan error, 1)
	go func() { done <- server.Serve(listener) }()
	t.Cleanup(func() { server.Close(); <-done })
	request := func(id uint, want int) {
		t.Helper()
		req, _ := http.NewRequest("GET", "http://"+listener.Addr().String()+"/api/v1/auth/me", nil)
		req.Header.Set("Authorization", "Bearer "+f.token(id, nil))
		client := &http.Client{Timeout: 3 * time.Second}
		res, e := client.Do(req)
		if e != nil {
			t.Fatal(e)
		}
		res.Body.Close()
		if res.StatusCode != want {
			t.Fatalf("JWT status %d, want %d", res.StatusCode, want)
		}
	}
	request(1, 200) // Matching security version is accepted by actual JWT middleware.
	if h04Snapshot(t, f) != before {
		t.Fatal("startup/readiness/authentication changed database state")
	}
	if e := f.db.Exec("UPDATE users SET security_version=2 WHERE id=1").Error; e != nil {
		t.Fatal(e)
	}
	request(1, 401) // Old signed token is revoked immediately.
	if e := f.db.Exec("UPDATE users SET status=0 WHERE id=2").Error; e != nil {
		t.Fatal(e)
	}
	request(2, 401)
	if e := f.db.Exec("UPDATE groups SET status=0 WHERE id=2").Error; e != nil {
		t.Fatal(e)
	}
	request(3, 401)
	// A missing current group also fails closed, even under fault-injected
	// post-startup schema/data drift in this disposable fixture.
	if e := f.db.Exec("ALTER TABLE users DROP CONSTRAINT users_security_group_fk; UPDATE users SET group_id=999 WHERE id=5").Error; e != nil {
		t.Fatal(e)
	}
	request(5, 401)
	// No explicit action grant, even for a superadmin-labelled group.
	f.req(t, "PUT", "/pemohon/sync/"+h04UUID, 4, map[string]any{"nama": "Denied"}, 403)
}

func TestH05SchemaGateBeforeListener(t *testing.T) {
	cases := []struct{ name, sql string }{
		{"missing-security-version", "ALTER TABLE users DROP COLUMN security_version"},
		{"missing-user-revision", "ALTER TABLE users DROP COLUMN revision"},
		{"missing-group-revision", "ALTER TABLE groups DROP COLUMN revision"},
		{"missing-audit", "DROP TABLE administrative_audit"},
		{"missing-unique-identity", "DROP INDEX users_username_normalized"},
		{"wrong-unique-index", "DROP INDEX users_email_normalized; CREATE UNIQUE INDEX users_email_normalized ON users(email)"},
		{"missing-grant-uniqueness", "DROP INDEX sidebar_group_grant_unique"},
		{"missing-user-group-fk", "ALTER TABLE users DROP CONSTRAINT users_security_group_fk"},
		{"not-valid-grant-fk", "ALTER TABLE sidebar_akses DROP CONSTRAINT grants_security_sidebar_fk; ALTER TABLE sidebar_akses ADD CONSTRAINT grants_security_sidebar_fk FOREIGN KEY(sidebar_id) REFERENCES sidebar(id) NOT VALID"},
		{"wrong-check-definition", "ALTER TABLE groups DROP CONSTRAINT groups_security_valid; ALTER TABLE groups ADD CONSTRAINT groups_security_valid CHECK(true)"},
		{"nullable-version", "ALTER TABLE users ALTER COLUMN security_version DROP NOT NULL"},
		{"wrong-version-default", "ALTER TABLE users ALTER COLUMN security_version SET DEFAULT 0"},
		{"disabled-audit-trigger", "ALTER TABLE administrative_audit DISABLE TRIGGER administrative_audit_immutable"},
		{"ineffective-audit-function", `CREATE OR REPLACE FUNCTION deny_administrative_audit_rewrite() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$`},
		{"no-recovery-grants", `UPDATE sidebar_akses SET "create"=0 WHERE group_id=1 AND sidebar_id=1`},
		{"no-usable-recovery-password", "UPDATE users SET password='invalid-disposable-hash' WHERE group_id=1"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := usersSetup(t)
			if err := f.db.Exec(tc.sql).Error; err != nil {
				t.Fatal(err)
			} // Fault injection only in a new owned disposable schema.
			before := h04Snapshot(t, f)
			called := 0
			ln, err := backendstartup.Open(context.Background(), h05Config(f), f.db, func(string, string) (net.Listener, error) {
				called++
				return nil, errors.New("listener must never be reached")
			})
			if err == nil || called != 0 || ln != nil {
				t.Fatal("partial P0 schema reached listener")
			}
			if h04Snapshot(t, f) != before {
				t.Fatal("failed startup modified data/audit/sequences")
			}
		})
	}
}

func TestH05InvalidConfigCannotBind(t *testing.T) {
	f := usersSetup(t)
	for _, mode := range []string{"local", "staging", "production", "release"} {
		t.Run(mode, func(t *testing.T) {
			cfg := h05Config(f)
			cfg.Environment = mode
			cfg.UsersSecurityEnabled = false
			called := false
			ln, e := backendstartup.Open(context.Background(), cfg, f.db, func(string, string) (net.Listener, error) { called = true; return nil, nil })
			if e == nil || called || ln != nil {
				t.Fatal("insecure mode reached a listener")
			}
		})
	}
	for _, field := range []string{"target", "local-interface"} {
		t.Run(field, func(t *testing.T) {
			cfg := h05Config(f)
			if field == "target" {
				cfg.DBName = "wrong-disposable-target"
			} else {
				cfg.Environment = "local"
				cfg.HTTPHost = "0.0.0.0"
			}
			called := false
			_, err := backendstartup.Open(context.Background(), cfg, f.db, func(string, string) (net.Listener, error) { called = true; return nil, nil })
			if err == nil || called {
				t.Fatal("target/local mode mismatch reached listener")
			}
		})
	}
	if err := (services.Administration{DB: f.db, Enabled: false}).Ready(context.Background()); err == nil {
		t.Fatal("disabled P0 falsely reported ready")
	}
}

func TestH05ConfiguredLoopbackBind(t *testing.T) {
	f := usersSetup(t)
	cfg := h05Config(f)
	cfg.Environment = "local"
	// Reserve an OS-selected port then use the actual configured address through
	// net.Listen, exercising the production path without touching 8080/8081.
	probe, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	cfg.Port = strconv.Itoa(probe.Addr().(*net.TCPAddr).Port)
	probe.Close()
	ln, err := backendstartup.Open(context.Background(), cfg, f.db, net.Listen)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	if ln.Addr().String() != fmt.Sprintf("127.0.0.1:%s", cfg.Port) {
		t.Fatal("local listener is not bound to exact loopback target")
	}
}
