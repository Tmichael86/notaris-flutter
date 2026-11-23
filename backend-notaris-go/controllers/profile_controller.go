package controllers

import (
	"backend-notaris-go/config"
	"backend-notaris-go/database"
	"backend-notaris-go/services"
	"bytes"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"io"
	"unicode/utf8"
)

type ProfileController struct{ Service services.ProfileService }

func NewProfileController(cfg config.Config) *ProfileController {
	return &ProfileController{services.ProfileService{DB: database.DB, Enabled: cfg.UsersSecurityEnabled}}
}
func (p *ProfileController) Prepare(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
	c.Set("admin_request_id", services.AdminRequestID())
	c.Header("X-Request-ID", adminActor(c).RequestID)
	if !p.Service.Enabled {
		profileError(c, &services.AdminError{Status: 503, Code: "profile_security_not_enabled"})
		return
	}
	c.Next()
}
func profileError(c *gin.Context, e error) {
	problem := &services.AdminError{Status: 500, Code: "profile_operation_failed"}
	var known *services.AdminError
	if errors.As(e, &known) {
		problem = known
	}
	c.AbortWithStatusJSON(problem.Status, gin.H{"success": false, "code": problem.Code, "message": "Profil ditolak atau belum dapat diproses.", "request_id": adminActor(c).RequestID})
}
func profileTarget(c *gin.Context) bool {
	if c.Request.URL.RawQuery != "" || c.GetHeader("X-User-ID") != "" || c.GetHeader("X-Target-User-ID") != "" || c.GetHeader("X-Group-ID") != "" {
		profileError(c, &services.AdminError{Status: 400, Code: "invalid_profile_input"})
		return false
	}
	return true
}
func (p *ProfileController) Get(c *gin.Context) {
	if !profileTarget(c) {
		return
	}
	v, e := p.Service.Read(c.Request.Context(), adminActor(c))
	if e != nil {
		profileError(c, e)
		return
	}
	c.JSON(200, gin.H{"success": true, "data": v})
}

// Decode token-by-token: DisallowUnknownFields alone does not reject duplicate
// JSON keys or distinguish required null fields from omitted fields.
func decodeProfile(c *gin.Context) (services.ProfileInput, error) {
	var in services.ProfileInput
	raw, e := io.ReadAll(io.LimitReader(c.Request.Body, 32769))
	if e != nil || len(raw) > 32768 || !utf8.Valid(raw) {
		return in, errors.New("invalid")
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	token, e := d.Token()
	if e != nil || token != json.Delim('{') {
		return in, errors.New("object")
	}
	seen := map[string]bool{}
	for d.More() {
		key, e := d.Token()
		k, ok := key.(string)
		if e != nil || !ok || seen[k] {
			return in, errors.New("duplicate")
		}
		seen[k] = true
		var value json.RawMessage
		if e = d.Decode(&value); e != nil {
			return in, e
		}
		switch k {
		case "expected_revision":
			if bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
				return in, errors.New("revision")
			}
			e = json.Unmarshal(value, &in.ExpectedRevision)
		case "nama":
			if bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
				return in, errors.New("name")
			}
			e = json.Unmarshal(value, &in.Nama)
		case "no_telp":
			e = json.Unmarshal(value, &in.NoTelp)
		case "alamat":
			e = json.Unmarshal(value, &in.Alamat)
		default:
			return in, errors.New("unknown")
		}
		if e != nil {
			return in, e
		}
	}
	if _, e = d.Token(); e != nil {
		return in, e
	}
	if d.Decode(new(any)) != io.EOF || len(seen) != 4 || in.ExpectedRevision < 1 {
		return in, errors.New("shape")
	}
	return in, nil
}
func (p *ProfileController) Patch(c *gin.Context) {
	if !profileTarget(c) {
		return
	}
	in, e := decodeProfile(c)
	if e != nil {
		profileError(c, &services.AdminError{Status: 400, Code: "invalid_profile_input"})
		return
	}
	v, e := p.Service.Update(c.Request.Context(), adminActor(c), in)
	if e != nil {
		profileError(c, e)
		return
	}
	c.JSON(200, gin.H{"success": true, "data": v, "request_id": adminActor(c).RequestID})
}
