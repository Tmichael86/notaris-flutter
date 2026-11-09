package middleware

import (
	"backend-notaris-go/config"
	"backend-notaris-go/services"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

const pilotTestBody = `{"uuid":"00000000-0000-4000-8000-000000000001","mutation_id":"00000000-0000-4000-8000-000000000002","domain":"notaris","expected_revision":0,"header":{"initial_payment":0},"details":[{}],"payments":[]}`

func pilotTestPlan() DevelopmentPilot {
	return DevelopmentPilot{Stage: "UploadPilot", UUID: "00000000-0000-4000-8000-000000000001", MutationID: "00000000-0000-4000-8000-000000000002", PayloadHash: fmt.Sprintf("%x", sha256.Sum256([]byte(pilotTestBody)))}
}

func TestPilotPlanKeepsLegacyBudgetAndRequiresFrozenCreate(t *testing.T) {
	p := pilotTestPlan()
	file := filepath.Join(t.TempDir(), "pilot.json")
	read := func(plan AcceptancePlan) error {
		b, _ := json.Marshal(plan)
		if err := os.WriteFile(file, b, 0600); err != nil {
			t.Fatal(err)
		}
		_, err := ReadAcceptancePlan(file, fmt.Sprintf("%x", sha256.Sum256(b)))
		return err
	}
	if err := read(AcceptancePlan{Target: "127.0.0.1:5432/notarisdev", Pilot: &p}); err != nil {
		t.Fatal(err)
	}
	legacy := fixturePlan()
	legacy.Pilot = &p
	if read(legacy) == nil {
		t.Fatal("mixed legacy and pilot accepted")
	}
	p.PayloadHash = ""
	if read(AcceptancePlan{Target: "127.0.0.1:5432/notarisdev", Pilot: &p}) == nil {
		t.Fatal("unfrozen payload accepted")
	}
}

func TestPilotBlocksBootstrapWritesAndConsumesAmbiguousDispatch(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cfg := config.Config{JWTSecret: "pilot-test"}
	claims := &services.Claims{UID: 2001, GID: 11, RegisteredClaims: jwt.RegisteredClaims{Issuer: "backend-notaris-go", ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}}
	token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(cfg.JWTSecret))
	for _, tc := range []struct {
		name       string
		pilot      DevelopmentPilot
		path, body string
		code       int
	}{
		{"bootstrap", DevelopmentPilot{Stage: "LocalBootstrap"}, "create", pilotTestBody, 403},
		{"update", pilotTestPlan(), "update", pilotTestBody, 403},
		{"changed payload", pilotTestPlan(), "create", pilotTestBody + " ", 403},
		{"ambiguous", pilotTestPlan(), "create", pilotTestBody, 500},
	} {
		t.Run(tc.name, func(t *testing.T) {
			gate := &AcceptanceGate{Plan: AcceptancePlan{Pilot: &tc.pilot}, Hash: "reviewed"}
			r := gin.New()
			r.Use(gate.guard(cfg, func(*gin.Context) (gin.H, error) { return gin.H{}, nil }))
			path := "/api/v1/transaksi-notaris/sync/" + tc.path
			r.POST(path, func(c *gin.Context) { c.Status(500) })
			request := func() int {
				req := httptest.NewRequest("POST", path, strings.NewReader(tc.body))
				req.Header.Set("Authorization", "Bearer "+token)
				req.Header.Set("X-Notaris-Acceptance", "reviewed")
				res := httptest.NewRecorder()
				r.ServeHTTP(res, req)
				return res.Code
			}
			if got := request(); got != tc.code {
				t.Fatalf("got %d want %d", got, tc.code)
			}
			if got := request(); got != 403 {
				t.Fatalf("automatic retry allowed: %d", got)
			}
		})
	}
}
