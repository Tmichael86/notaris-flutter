package middleware

import (
	"backend-notaris-go/database"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"

	"github.com/gin-gonic/gin"
)

type DevelopmentPilot struct {
	Stage       string `json:"stage"`
	UUID        string `json:"uuid"`
	MutationID  string `json:"mutation_id"`
	PayloadHash string `json:"payload_sha256"`
}

var pilotUUID = regexp.MustCompile(`^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$`)
var pilotSHA = regexp.MustCompile(`^[a-f0-9]{64}$`)

func (p DevelopmentPilot) valid() bool {
	if p.Stage == "LocalBootstrap" {
		return p.UUID == "" && p.MutationID == "" && p.PayloadHash == ""
	}
	return p.Stage == "UploadPilot" && pilotUUID.MatchString(p.UUID) && pilotUUID.MatchString(p.MutationID) && pilotSHA.MatchString(p.PayloadHash)
}

func (p DevelopmentPilot) allows(method, path string, payload []byte) bool {
	if p.Stage != "UploadPilot" || method != "POST" || path != "/api/v1/transaksi-notaris/sync/create" {
		return false
	}
	digest := sha256.Sum256(payload)
	var body struct {
		UUID       string `json:"uuid"`
		MutationID string `json:"mutation_id"`
		Domain     string `json:"domain"`
		Revision   *int   `json:"expected_revision"`
		Details    []any  `json:"details"`
		Payments   []any  `json:"payments"`
		Header     struct {
			InitialPayment *float64 `json:"initial_payment"`
		} `json:"header"`
	}
	return hex.EncodeToString(digest[:]) == p.PayloadHash && json.Unmarshal(payload, &body) == nil &&
		body.UUID == p.UUID && body.MutationID == p.MutationID && body.Domain == "notaris" &&
		body.Revision != nil && *body.Revision == 0 && len(body.Details) == 1 &&
		body.Payments != nil && len(body.Payments) == 0 && body.Header.InitialPayment != nil && *body.Header.InitialPayment == 0
}

func (g *AcceptanceGate) probePilot(c *gin.Context) (gin.H, error) {
	p := g.Plan.Pilot
	db := database.DB.WithContext(c.Request.Context())
	var ok bool
	err := db.Raw(`SELECT
	  (SELECT last_seq=6 AND min_cursor=0 FROM pekerjaan_notaris_sync_publication WHERE id=1)
	  AND (SELECT last_seq=8 FROM transaction_cloud_publication WHERE id=1)
	  AND NOT EXISTS (SELECT 1 FROM pekerjaan_notaris_sync_outbox WHERE publication_seq IS NULL)
	  AND NOT EXISTS (SELECT 1 FROM pekerjaan_ppat_sync_outbox WHERE publication_seq IS NULL)
	  AND NOT EXISTS (SELECT 1 FROM transaction_cloud_outbox WHERE publication_seq IS NULL)
	  AND EXISTS (SELECT 1 FROM sidebar s JOIN sidebar_akses a ON a.sidebar_id=s.id
	    WHERE s.sidebar_kode='transaksi' AND s.status=1 AND a.group_id=11 AND a."read"=1 AND a."create"=1)
	  AND EXISTS (SELECT 1 FROM sidebar s JOIN sidebar_akses a ON a.sidebar_id=s.id
	    WHERE s.sidebar_kode='pekerjaan_notaris' AND s.status=1 AND a.group_id=11 AND a."read"=1)
	  AND EXISTS (SELECT 1 FROM pemohon WHERE uuid='fa000001-0000-4000-8000-000000000001' AND status=1 AND deleted_at IS NULL)
	  AND EXISTS (SELECT 1 FROM petugas WHERE id=101 AND uuid='e85be759-1e15-4b2f-8243-120131475207'
	    AND row_version=1 AND status=1 AND deleted_at IS NULL)
	  AND EXISTS (SELECT 1 FROM pekerjaan_notaris_sync_outbox WHERE aggregate_uuid='19566301-0540-4e1a-8b17-948bc3dec96e'
	    AND publication_seq=6 AND revision=1 AND operation='create')
	  AND EXISTS (SELECT 1 FROM pekerjaan_notaris m JOIN pekerjaan_notaris_harga h ON h.pekerjaan_notaris_id=m.id
	    JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id
	    WHERE m.uuid='19566301-0540-4e1a-8b17-948bc3dec96e' AND m.row_version=1 AND m.status=1 AND m.deleted_at IS NULL
	      AND h.uuid='ef324a08-d51f-49ea-b4f9-08a0c8305d96' AND h.status=1 AND h.harga='100000'
	      AND c.uuid='fa000002-0000-4000-8000-000000000001' AND c.status=1 AND (to_jsonb(c)->>'deleted_at') IS NULL)
	  AND NOT EXISTS (SELECT 1 FROM transaction_cloud WHERE uuid=NULLIF(?, '')::uuid)
	  AND NOT EXISTS (SELECT 1 FROM transaction_cloud_outbox WHERE aggregate_uuid=NULLIF(?, '')::uuid)
	  AND NOT EXISTS (SELECT 1 FROM transaction_cloud_mutation WHERE mutation_id=NULLIF(?, '')::uuid OR acknowledgement->>'uuid'=?)`,
		p.UUID, p.UUID, p.MutationID, p.UUID).Row().Scan(&ok)
	if err != nil || !ok {
		return nil, fmt.Errorf("pilot baseline or permission mismatch")
	}
	return gin.H{"database": "notarisdev", "host": "127.0.0.1", "port": 5432, "marker": "NOTARISDEV SYNTHETIC v1",
		"plan_sha256": g.Hash, "account_id": 2001, "group_id": 11, "pilot_stage": p.Stage, "role": "nd_app_14af5452144b"}, nil
}
