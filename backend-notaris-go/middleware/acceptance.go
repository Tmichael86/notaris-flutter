package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"

	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/services"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// An opt-in owned backend process, never a normal-profile feature flag.
// An immutable hash-pinned four-event plan also gates every business write.
type AcceptanceEvent struct {
	Kind            string `json:"kind"`
	Domain          string `json:"domain"`
	UUID            string `json:"uuid"`
	Operation       string `json:"operation"`
	Revision        int    `json:"revision"`
	ExpectedLastSeq int    `json:"expected_last_seq"`
}
type AcceptancePlan struct {
	Target string            `json:"target"`
	Events []AcceptanceEvent `json:"events"`
	Pilot  *DevelopmentPilot `json:"pilot,omitempty"`
}
type AcceptanceGate struct {
	Plan    AcceptancePlan
	Hash    string
	mu      sync.Mutex
	stopped bool
}

func ReadAcceptancePlan(path, hash string) (*AcceptanceGate, error) {
	b, e := os.ReadFile(path)
	if e != nil {
		return nil, e
	}
	sum := sha256.Sum256(b)
	if !strings.EqualFold(hex.EncodeToString(sum[:]), hash) {
		return nil, fmt.Errorf("acceptance hash mismatch")
	}
	g := &AcceptanceGate{Hash: strings.ToLower(hash)}
	if json.Unmarshal(b, &g.Plan) != nil || g.Plan.Target != "127.0.0.1:5432/notarisdev" {
		return nil, fmt.Errorf("invalid acceptance plan")
	}
	if g.Plan.Pilot != nil {
		if len(g.Plan.Events) != 0 || !g.Plan.Pilot.valid() {
			return nil, fmt.Errorf("invalid development pilot")
		}
		return g, nil
	}
	if len(g.Plan.Events) != 4 {
		return nil, fmt.Errorf("invalid acceptance event count")
	}
	seen := map[string]bool{}
	ids := map[string]bool{}
	for _, v := range g.Plan.Events {
		expected := 5
		if v.Kind == "transaction" {
			expected = 6
			if v.Domain == "ppat" {
				expected = 7
			}
		}
		if v.ExpectedLastSeq != expected {
			return nil, fmt.Errorf("unexpected baseline cursor")
		}
		key := v.Kind + "/" + v.Domain
		if seen[key] || ids[v.UUID] || len(v.UUID) != 36 || v.Operation != "create" || v.Revision != 1 || v.ExpectedLastSeq < 0 || !(v.Kind == "master" || v.Kind == "transaction") || !(v.Domain == "notaris" || v.Domain == "ppat") {
			return nil, fmt.Errorf("invalid acceptance event")
		}
		seen[key] = true
		ids[v.UUID] = true
	}
	return g, nil
}

func (g *AcceptanceGate) probe(c *gin.Context) (gin.H, error) {
	var row struct {
		Name   string
		Host   string
		Port   int
		Marker string
		Role   string
	}
	if database.DB == nil {
		return nil, fmt.Errorf("no database")
	}
	err := database.DB.WithContext(c.Request.Context()).Raw("SELECT current_database() AS name,host(inet_server_addr()) AS host,inet_server_port() AS port,current_user AS role,(SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1) AS marker").Scan(&row).Error
	if err != nil || row.Name != "notarisdev" || row.Host != "127.0.0.1" || row.Port != 5432 || row.Marker != "NOTARISDEV SYNTHETIC v1" {
		return nil, fmt.Errorf("target mismatch")
	}
	var active int64
	if database.DB.WithContext(c.Request.Context()).Table("users").Where("id=2001 AND group_id=11 AND status=1").Count(&active).Error != nil || active != 1 {
		return nil, fmt.Errorf("fixture scope mismatch")
	}
	if g.Plan.Pilot != nil {
		if row.Role != "nd_app_14af5452144b" {
			return nil, fmt.Errorf("pilot role mismatch")
		}
		return g.probePilot(c)
	}
	for _, t := range []string{"pekerjaan_notaris_sync_outbox", "pekerjaan_ppat_sync_outbox", "transaction_cloud_outbox"} {
		ids := []string{}
		for _, v := range g.Plan.Events {
			if (t == "transaction_cloud_outbox" && v.Kind == "transaction") || (t == "pekerjaan_"+v.Domain+"_sync_outbox" && v.Kind == "master") {
				ids = append(ids, v.UUID)
			}
		}
		var n int64
		if database.DB.WithContext(c.Request.Context()).Table(t).Where("publication_seq IS NULL AND aggregate_uuid::text NOT IN ?", ids).Count(&n).Error != nil || n != 0 {
			return nil, fmt.Errorf("unrelated pending event")
		}
	}
	for _, kind := range []string{"master/notaris", "master/ppat", "transaction"} {
		table := "transaction_cloud_publication"
		base := int(^uint(0) >> 1)
		limit := 0
		for _, v := range g.Plan.Events {
			key := v.Kind
			if v.Kind == "master" {
				key += "/" + v.Domain
			}
			if key == kind {
				if v.ExpectedLastSeq < base {
					base = v.ExpectedLastSeq
				}
				limit++
			}
		}
		if strings.HasPrefix(kind, "master/") {
			table = "pekerjaan_" + strings.TrimPrefix(kind, "master/") + "_sync_publication"
		}
		var seq int
		if database.DB.WithContext(c.Request.Context()).Raw("SELECT last_seq FROM "+table+" WHERE id=1").Scan(&seq).Error != nil || seq < base || seq > base+limit {
			return nil, fmt.Errorf("publication budget mismatch")
		}
	}
	return gin.H{"database": row.Name, "host": row.Host, "port": row.Port, "marker": row.Marker, "plan_sha256": g.Hash, "account_id": 2001, "group_id": 11}, nil
}

func (g *AcceptanceGate) Attest(c *gin.Context) {
	if c.GetUint("user_id") != 2001 || c.GetUint("group_id") != 11 {
		c.AbortWithStatus(403)
		return
	}
	data, e := g.probe(c)
	if e != nil {
		c.AbortWithStatusJSON(409, gin.H{"code": "acceptance_target_or_pending"})
		return
	}
	c.JSON(200, gin.H{"data": data})
}

func (g *AcceptanceGate) Guard(cfg config.Config) gin.HandlerFunc { return g.guard(cfg, g.probe) }
func (g *AcceptanceGate) guard(cfg config.Config, probe func(*gin.Context) (gin.H, error)) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method == "GET" || c.Request.URL.Path == "/api/v1/auth/login" {
			c.Next()
			return
		}
		g.mu.Lock()
		defer g.mu.Unlock()
		if g.stopped || c.GetHeader("X-Notaris-Acceptance") != g.Hash {
			c.AbortWithStatus(403)
			return
		}
		claims := &services.Claims{}
		raw := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
		token, e := jwt.ParseWithClaims(raw, claims, func(*jwt.Token) (any, error) { return []byte(cfg.JWTSecret), nil }, jwt.WithValidMethods([]string{"HS256"}), jwt.WithIssuer("backend-notaris-go"))
		if e != nil || !token.Valid || claims.UID != 2001 || claims.GID != 11 {
			c.AbortWithStatus(403)
			return
		}
		if _, e = probe(c); e != nil {
			g.stopped = true
			c.AbortWithStatus(409)
			return
		}
		b, e := io.ReadAll(io.LimitReader(c.Request.Body, (2<<20)+1))
		c.Request.Body.Close()
		if e != nil || len(b) > 2<<20 {
			c.AbortWithStatus(422)
			return
		}
		if pilot := g.Plan.Pilot; pilot != nil {
			// Consume the one dispatch even when the response is ambiguous.
			g.stopped = true
			if !pilot.allows(c.Request.Method, c.Request.URL.Path, b) {
				c.AbortWithStatus(403)
				return
			}
			c.Request.Body = io.NopCloser(bytes.NewReader(b))
			c.Next()
			return
		}
		var body struct {
			UUID     string `json:"uuid"`
			Payments []any  `json:"payments"`
			Expected int    `json:"expected_revision"`
		}
		if json.Unmarshal(b, &body) != nil || body.Expected != 0 {
			c.AbortWithStatus(422)
			return
		}
		allowed := false
		for _, v := range g.Plan.Events {
			prefix := "pekerjaan-"
			if v.Kind == "transaction" {
				prefix = "transaksi-"
			}
			if c.Request.Method == "POST" && c.Request.URL.Path == "/api/v1/"+prefix+v.Domain+"/sync/create" && body.UUID == v.UUID && (v.Kind != "transaction" || len(body.Payments) == 1) {
				allowed = true
			}
		}
		if !allowed {
			g.stopped = true
			c.AbortWithStatus(403)
			return
		}
		if strings.HasPrefix(c.Request.URL.Path, "/api/v1/transaksi-") {
			for _, v := range g.Plan.Events {
				if v.Kind == "master" {
					var n int64
					if database.DB.WithContext(c.Request.Context()).Table("pekerjaan_"+v.Domain+"_sync_outbox").Where("aggregate_uuid=? AND publication_seq IS NOT NULL AND revision=1", v.UUID).Count(&n).Error != nil || n != 1 {
						c.AbortWithStatus(409)
						return
					}
				}
			}
		}
		if c.Request.URL.Path == "/api/v1/transaksi-ppat/sync/create" {
			for _, v := range g.Plan.Events {
				if v.Kind == "transaction" && v.Domain == "notaris" {
					var n int64
					if database.DB.WithContext(c.Request.Context()).Table("transaction_cloud_outbox").Where("aggregate_uuid=? AND publication_seq IS NOT NULL AND revision=1", v.UUID).Count(&n).Error != nil || n != 1 {
						c.AbortWithStatus(409)
						return
					}
				}
			}
		}
		c.Request.Body = io.NopCloser(bytes.NewReader(b))
		c.Next()
		// Ambiguous or unexpected outcomes stop the owned process's next write.
		if c.Writer.Status() >= 400 {
			g.stopped = true
		}
	}
}
