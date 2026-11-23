package services

import (
	"backend-notaris-go/models"
	"context"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// SelfProfile deliberately excludes password, security version and admin metadata.
type SelfProfile struct {
	ID         uint    `json:"id"`
	Nama       string  `json:"nama"`
	NoTelp     *string `json:"no_telp"`
	Alamat     *string `json:"alamat"`
	Username   string  `json:"username"`
	Email      string  `json:"email"`
	GroupID    uint    `json:"group_id"`
	GroupNama  string  `json:"group_nama"`
	GroupJenis string  `json:"group_jenis"`
	Status     int16   `json:"status"`
	Revision   int64   `json:"revision"`
}
type ProfileInput struct {
	ExpectedRevision int64
	Nama             string
	NoTelp, Alamat   *string
}
type ProfileService struct {
	DB      *gorm.DB
	Enabled bool
}

func (s ProfileService) identity(tx *gorm.DB, actor AdminActor, lock bool) (models.User, models.Group, error) {
	var u models.User
	var g models.Group
	q := tx
	if lock {
		q = q.Clauses(clause.Locking{Strength: "UPDATE"})
	}
	if actor.ID == 0 || actor.Version < 1 {
		return u, g, adminError(401, "session_invalid")
	}
	if e := q.First(&u, actor.ID).Error; e != nil || u.Status != 1 || u.SecurityVersion != actor.Version {
		return u, g, adminError(401, "session_invalid")
	}
	if e := tx.First(&g, u.GroupID).Error; e != nil || g.Status != 1 {
		return u, g, adminError(403, "group_inactive")
	}
	return u, g, nil
}
func profileDTO(u models.User, g models.Group) SelfProfile {
	return SelfProfile{u.ID, u.Nama, u.NoTelp, u.Alamat, u.Username, u.Email, u.GroupID, g.GroupNama, g.GroupJenis, u.Status, u.Revision}
}
func (s ProfileService) Read(ctx context.Context, actor AdminActor) (SelfProfile, error) {
	if !s.Enabled {
		return SelfProfile{}, adminError(503, "profile_security_not_enabled")
	}
	// One query provides a coherent identity/membership read, not JWT field values.
	var row struct {
		SelfProfile
		SecurityVersion int64
		GroupStatus     int16
	}
	e := s.DB.WithContext(ctx).Raw(`SELECT u.id,u.nama,u.no_telp,u.alamat,u.username,u.email,u.group_id,g.group_nama,g.group_jenis,u.status,u.revision,u.security_version,g.status AS group_status FROM users u JOIN groups g ON g.id=u.group_id WHERE u.id=?`, actor.ID).Scan(&row).Error
	if e != nil {
		return SelfProfile{}, adminSafeError(e)
	}
	if row.ID == 0 || row.Status != 1 || actor.Version < 1 || row.SecurityVersion != actor.Version {
		return SelfProfile{}, adminError(401, "session_invalid")
	}
	if row.GroupStatus != 1 {
		return SelfProfile{}, adminError(403, "group_inactive")
	}
	return row.SelfProfile, nil
}
func profileText(value string, max int, multiline bool) bool {
	if !utf8.ValidString(value) || utf8.RuneCountInString(value) > max {
		return false
	}
	for _, c := range value {
		if unicode.IsControl(c) && !(multiline && (c == '\n' || c == '\r' || c == '\t')) {
			return false
		}
	}
	return true
}
func normalizedProfile(in ProfileInput) (ProfileInput, error) {
	in.Nama = strings.TrimSpace(in.Nama)
	if in.ExpectedRevision < 1 || in.Nama == "" || !profileText(in.Nama, 160, false) {
		return in, adminError(400, "invalid_profile_input")
	}
	for i, p := range []**string{&in.NoTelp, &in.Alamat} {
		if *p != nil {
			v := strings.TrimSpace(**p)
			if !profileText(v, []int{32, 255}[i], i == 1) {
				return in, adminError(400, "invalid_profile_input")
			}
			if v == "" {
				*p = nil
			} else {
				*p = &v
			}
		}
	}
	return in, nil
}
func profileSummary(u models.User) map[string]any {
	// Field names plus revision suffice for audit without copying personal contacts.
	return map[string]any{"revision": u.Revision, "fields": []string{"nama", "no_telp", "alamat"}, "origin": "self_service_profile"}
}
func (s ProfileService) Update(ctx context.Context, actor AdminActor, in ProfileInput) (SelfProfile, error) {
	if !s.Enabled {
		return SelfProfile{}, adminError(503, "profile_security_not_enabled")
	}
	var out SelfProfile
	e := s.DB.Session(&gorm.Session{Logger: logger.Default.LogMode(logger.Silent)}).WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec("SET LOCAL lock_timeout='5s'").Error; e != nil {
			return e
		}
		if e := tx.Exec("SELECT pg_advisory_xact_lock(?)", AdminLock).Error; e != nil {
			return e
		}
		before, g, e := s.identity(tx, actor, true)
		if e != nil {
			return e
		}
		if in.ExpectedRevision != before.Revision {
			return adminError(409, "stale_revision")
		}
		in, e = normalizedProfile(in)
		if e != nil {
			return e
		}
		result := tx.Model(&models.User{}).Where("id=? AND revision=?", actor.ID, in.ExpectedRevision).Updates(map[string]any{"nama": in.Nama, "no_telp": in.NoTelp, "alamat": in.Alamat, "revision": gorm.Expr("revision+1"), "updated_at": time.Now(), "updated_by": actor.ID})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 1 {
			return adminError(409, "stale_revision")
		}
		after, _, e := s.identity(tx, actor, false)
		if e != nil {
			return e
		}
		// Same P0 recovery invariant; no administrative authorization is inherited.
		if e = (Administration{DB: tx, Enabled: true}).recovery(tx); e != nil {
			return e
		}
		// Existing source denotes the online account-administration transport. Action,
		// target_type and origin explicitly identify SELF service, never Superadmin.
		if e = auditAdmin(tx, actor, actor.ID, "self_profile", "profile_self_update", "success", "", profileSummary(before), profileSummary(after)); e != nil {
			return e
		}
		out = profileDTO(after, g)
		return nil
	})
	if e != nil {
		return SelfProfile{}, adminSafeError(e)
	}
	return out, nil
}
