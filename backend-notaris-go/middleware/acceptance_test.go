package middleware

import (
	"backend-notaris-go/config"
	"backend-notaris-go/services"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fixturePlan() AcceptancePlan {
	p := AcceptancePlan{Target: "127.0.0.1:5432/notarisdev"}
	for i, k := range []string{"master", "transaction"} {
		for j, d := range []string{"notaris", "ppat"} {
			p.Events = append(p.Events, AcceptanceEvent{k, d, fmt.Sprintf("00000000-0000-4000-8000-%012d", i*2+j+1), "create", 1, 5 + i + j*i})
		}
	}
	return p
}
func TestAcceptancePlanPinsBudget(t *testing.T) {
	p := fixturePlan()
	file := filepath.Join(t.TempDir(), "plan.json")
	save := func() { b, _ := json.Marshal(p); os.WriteFile(file, b, 0600) }
	save()
	b, _ := os.ReadFile(file)
	hash := fmt.Sprintf("%x", sha256.Sum256(b))
	if _, e := ReadAcceptancePlan(file, hash); e != nil {
		t.Fatal(e)
	}
	if _, e := ReadAcceptancePlan(file, strings.Repeat("0", 64)); e == nil {
		t.Fatal("hash bypass")
	}
	p.Events[0].Operation = "delete"
	save()
	b, _ = os.ReadFile(file)
	if _, e := ReadAcceptancePlan(file, fmt.Sprintf("%x", sha256.Sum256(b))); e == nil {
		t.Fatal("delete accepted")
	}
}
func TestAcceptanceWriteGate(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cfg := config.Config{JWTSecret: "disposable-test-secret"}
	token := func(uid uint) string {
		c := services.Claims{UID: uid, GID: 11, RegisteredClaims: jwt.RegisteredClaims{Issuer: "backend-notaris-go", ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}}
		s, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(cfg.JWTSecret))
		return s
	}
	for _, tc := range []struct {
		name, path, body string
		uid              uint
		header           bool
		want             int
	}{
		{"create", "/api/v1/transaksi-notaris/sync/create", `{"uuid":"00000000-0000-4000-8000-000000000003","expected_revision":0,"payments":[{}]}`, 2001, true, 204},
		{"update", "/api/v1/transaksi-notaris/sync/update", `{}`, 2001, true, 403},
		{"unknown UUID", "/api/v1/transaksi-notaris/sync/create", `{"uuid":"other"}`, 2001, true, 403},
		{"two payments", "/api/v1/transaksi-notaris/sync/create", `{"uuid":"00000000-0000-4000-8000-000000000003","payments":[{},{}]}`, 2001, true, 403},
		{"wrong actor", "/api/v1/transaksi-notaris/sync/create", `{}`, 1, true, 403},
		{"missing plan header", "/api/v1/transaksi-notaris/sync/create", `{}`, 2001, false, 403},
	} {
		t.Run(tc.name, func(t *testing.T) {
			g := &AcceptanceGate{Plan: fixturePlan(), Hash: "reviewed"}
			r := gin.New()
			r.Use(g.guard(cfg, func(*gin.Context) (gin.H, error) { return gin.H{}, nil }))
			r.POST(tc.path, func(c *gin.Context) { c.Status(204) })
			// Master publication guard uses the real database even when target probe is injected.
			// Pure HTTP allowance is demonstrated with Master CREATE; transaction waits for publication.
			if tc.want == 204 {
				tc.path = "/api/v1/pekerjaan-notaris/sync/create"
				tc.body = `{"uuid":"00000000-0000-4000-8000-000000000001"}`
				r.POST(tc.path, func(c *gin.Context) { c.Status(204) })
			}
			req := httptest.NewRequest("POST", tc.path, strings.NewReader(tc.body))
			req.Header.Set("Authorization", "Bearer "+token(tc.uid))
			if tc.header {
				req.Header.Set("X-Notaris-Acceptance", "reviewed")
			}
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if w.Code != tc.want {
				t.Fatalf("got %d want %d", w.Code, tc.want)
			}
		})
	}
}
func TestAcceptanceStopsOnTargetMismatch(t *testing.T) {
	g := &AcceptanceGate{Plan: fixturePlan()}
	c, _ := gin.CreateTestContext(httptest.NewRecorder())
	c.Request = httptest.NewRequest("GET", "/", nil)
	if _, err := g.probe(c); err == nil {
		t.Fatal("unbound database accepted")
	}
}
