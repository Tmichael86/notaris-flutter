package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/mail"
	"regexp"
	"strings"
	"time"

	"backend-notaris-go/dto/request"
	"backend-notaris-go/models"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
)

const AdminLock int64 = 71920261119

type AdminError struct {
	Status int
	Code   string
}

func (e *AdminError) Error() string            { return e.Code }
func adminError(status int, code string) error { return &AdminError{status, code} }

type AdminActor struct {
	ID        uint
	Version   int64
	RequestID string
}

func AdminRequestID() string {
	var raw [16]byte
	if _, err := rand.Read(raw[:]); err != nil {
		panic("secure random unavailable")
	}
	raw[6] = (raw[6] & 15) | 64
	raw[8] = (raw[8] & 63) | 128
	s := hex.EncodeToString(raw[:])
	return s[:8] + "-" + s[8:12] + "-" + s[12:16] + "-" + s[16:20] + "-" + s[20:]
}

type Administration struct {
	DB      *gorm.DB
	Enabled bool
}

func (a Administration) authorize(tx *gorm.DB, actor AdminActor, menu, action string) error {
	var user models.User
	if err := tx.First(&user, actor.ID).Error; err != nil || user.Status != 1 ||
		actor.Version < 1 || user.SecurityVersion != actor.Version {
		return adminError(401, "session_invalid")
	}
	var group models.Group
	if err := tx.First(&group, user.GroupID).Error; err != nil || group.Status != 1 ||
		group.GroupJenis != "superadmin" {
		return adminError(403, "admin_forbidden")
	}
	type grant struct{ Read, Create, Update, Delete int16 }
	var rows []grant
	if err := tx.Raw(`SELECT a."read",a."create",a."update",a."delete" FROM sidebar_akses a
 JOIN sidebar s ON s.id=a.sidebar_id WHERE a.group_id=? AND s.sidebar_kode=?
 AND s.status=1 AND s.sidebar_route<>'#'`, user.GroupID, menu).Scan(&rows).Error; err != nil {
		return err
	}
	if len(rows) != 1 || rows[0].Read != 1 {
		return adminError(403, "admin_forbidden")
	}
	p := rows[0]
	allowed := action == "read" || action == "create" && p.Create == 1 ||
		action == "update" && p.Update == 1 || action == "delete" && p.Delete == 1
	if !allowed {
		return adminError(403, "admin_forbidden")
	}
	return nil
}

func (a Administration) recovery(tx *gorm.DB) error {
	var passwords []string
	if err := tx.Raw(`SELECT u.password FROM users u JOIN groups g ON g.id=u.group_id
 WHERE u.status=1 AND g.status=1 AND g.group_jenis='superadmin'
 AND NOT EXISTS (
   SELECT 1 FROM (VALUES ('users'),('groups'),('sidebars')) required(code)
   WHERE (SELECT count(*) FROM sidebar_akses p JOIN sidebar s ON s.id=p.sidebar_id
     WHERE p.group_id=g.id AND s.sidebar_kode=required.code
       AND s.status=1 AND s.sidebar_route<>'#' AND p."read"=1
       AND (SELECT count(*) FROM sidebar_akses px JOIN sidebar sx ON sx.id=px.sidebar_id
         WHERE px.group_id=g.id AND sx.sidebar_kode=required.code)=1
       AND (required.code='sidebars' OR (p."create"=1 AND p."update"=1 AND p."delete"=1)))<>1
 )`).Scan(&passwords).Error; err != nil {
		return err
	}
	for _, hash := range passwords {
		if _, err := bcrypt.Cost([]byte(hash)); err == nil {
			return nil
		}
	}
	return adminError(409, "last_recovery_administrator")
}

func adminSafeError(err error) error {
	var known *AdminError
	if errors.As(err, &known) {
		return known
	}
	var pg *pgconn.PgError
	if errors.As(err, &pg) {
		if pg.Code == "23505" {
			return adminError(409, "identity_conflict")
		}
		if pg.Code == "40001" || pg.Code == "40P01" || pg.Code == "55P03" {
			return adminError(409, "concurrent_change")
		}
		if pg.Code == "23503" || pg.Code == "23514" {
			return adminError(422, "invalid_reference")
		}
	}
	return adminError(500, "admin_operation_failed")
}

func auditAdmin(tx *gorm.DB, actor AdminActor, target uint, kind, action, result, reason string, before, after any) error {
	encode := func(value any) any {
		if value == nil {
			return nil
		}
		data, _ := json.Marshal(value)
		return string(data)
	}
	return tx.Exec(`INSERT INTO administrative_audit
 (actor_id,target_id,target_type,action,request_id,result,reason_code,before_state,after_state,source)
 VALUES(?,?,?,?,?::uuid,?,?,?::jsonb,?::jsonb,'online_admin_api')`,
		actor.ID, target, kind, action, actor.RequestID, result, reason, encode(before), encode(after)).Error
}

func (a Administration) Mutate(ctx context.Context, actor AdminActor, menu, permission, action, kind string, target uint,
	change func(*gorm.DB) (any, any, error)) error {
	if !a.Enabled {
		return adminError(503, "admin_security_not_enabled")
	}
	err := a.DB.Session(&gorm.Session{Logger: logger.Default.LogMode(logger.Silent)}).WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if e := tx.Exec("SET LOCAL lock_timeout='5s'").Error; e != nil {
			return e
		}
		if e := tx.Exec("SELECT pg_advisory_xact_lock(?)", AdminLock).Error; e != nil {
			return e
		}
		if e := a.authorize(tx, actor, menu, permission); e != nil {
			return e
		}
		before, after, e := change(tx)
		if e != nil {
			return e
		}
		if e = a.recovery(tx); e != nil {
			return e
		}
		if e = a.authorize(tx, actor, menu, permission); e != nil {
			return e
		}
		if target == 0 {
			if row, ok := after.(map[string]any); ok {
				target = row["id"].(uint)
			}
		}
		return auditAdmin(tx, actor, target, kind, action, "success", "", before, after)
	})
	if err == nil {
		return nil
	}
	safe := adminSafeError(err)
	var problem *AdminError
	errors.As(safe, &problem)
	// A denied event survives the mutation rollback. Use an independent bounded
	// context so request cancellation cannot silently drop this security event.
	logctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	var count int64
	if e := a.DB.WithContext(logctx).Model(&models.User{}).Where("id=?", actor.ID).Count(&count).Error; e == nil && count == 1 {
		if e = auditAdmin(a.DB.WithContext(logctx), actor, target, kind, action, "denied", problem.Code, nil, nil); e != nil {
			return adminError(500, "security_event_failed")
		}
	}
	return safe
}

func (a Administration) Read(ctx context.Context, actor AdminActor, menu string) error {
	if !a.Enabled {
		return adminError(503, "admin_security_not_enabled")
	}
	return adminSafeRead(a.authorize(a.DB.WithContext(ctx), actor, menu, "read"))
}

// Check is also used before bounded decoding/hash work. Mutate repeats it under
// the global transaction lock; UI visibility is never an authorization source.
func (a Administration) Check(ctx context.Context, actor AdminActor, menu, action string) error {
	if !a.Enabled {
		return adminError(503, "admin_security_not_enabled")
	}
	err := adminSafeRead(a.authorize(a.DB.WithContext(ctx), actor, menu, action))
	if err != nil {
		return a.Reject(actor, menu, action, err)
	}
	return nil
}
func (a Administration) Reject(actor AdminActor, kind, action string, err error) error {
	safe := adminSafeError(err)
	if !a.Enabled {
		return safe
	}
	problem := safe.(*AdminError)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if e := auditAdmin(a.DB.WithContext(ctx), actor, 0, kind, action, "denied", problem.Code, nil, nil); e != nil {
		return adminError(500, "security_event_failed")
	}
	return safe
}

// No DDL or bootstrap occurs at startup. The coordinated cutover requires an
// approved migration and a real recovery administrator already in the database.
func (a Administration) Ready(ctx context.Context) error {
	if !a.Enabled {
		return nil
	}
	var count int64
	if err := a.DB.WithContext(ctx).Raw(`SELECT count(*) FROM information_schema.columns
 WHERE table_schema=current_schema() AND ((table_name='users' AND column_name IN ('revision','security_version'))
 OR (table_name='groups' AND column_name='revision'))`).Scan(&count).Error; err != nil || count != 3 {
		return adminError(503, "security_schema_required")
	}
	if !a.DB.Migrator().HasTable("administrative_audit") {
		return adminError(503, "security_schema_required")
	}
	return adminSafeRead(a.recovery(a.DB.WithContext(ctx)))
}
func adminSafeRead(err error) error {
	if err == nil {
		return nil
	}
	return adminSafeError(err)
}

func safeUser(u models.User) map[string]any {
	return map[string]any{"id": u.ID, "group_id": u.GroupID, "username": u.Username, "email": u.Email,
		"nama": u.Nama, "no_telp": u.NoTelp, "alamat": u.Alamat, "status": u.Status, "revision": u.Revision}
}

var loginName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`)

func validateUser(u *models.User) error {
	u.Username = strings.TrimSpace(u.Username)
	u.Email = strings.TrimSpace(u.Email)
	u.Nama = strings.TrimSpace(u.Nama)
	address, e := mail.ParseAddress(u.Email)
	if !loginName.MatchString(u.Username) || e != nil || address.Address != u.Email || len(u.Email) > 254 ||
		u.Nama == "" || len(u.Nama) > 160 || u.GroupID == 0 ||
		u.NoTelp != nil && len(*u.NoTelp) > 32 || u.Alamat != nil && len(*u.Alamat) > 1000 {
		return adminError(400, "invalid_user_input")
	}
	return nil
}

func AdminPassword(password, confirm string) (string, error) {
	if len(password) < 12 || len(password) > 72 || password != confirm {
		return "", adminError(400, "invalid_password_input")
	}
	hash, e := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if e != nil {
		return "", adminError(400, "invalid_password_input")
	}
	return string(hash), nil
}

func assignable(tx *gorm.DB, id uint) error {
	var group models.Group
	if e := tx.First(&group, id).Error; e != nil || group.Status != 1 || group.GroupJenis != "user" {
		return adminError(422, "group_not_assignable")
	}
	return nil
}

func (a Administration) SaveUser(ctx context.Context, actor AdminActor, input models.User, revision int64, hash string) (models.User, error) {
	var result models.User
	operation, permission := "user_update", "update"
	if input.ID == 0 {
		operation, permission = "user_create", "create"
	}
	err := a.Mutate(ctx, actor, "users", permission, operation, "user", input.ID, func(tx *gorm.DB) (any, any, error) {
		if e := validateUser(&input); e != nil {
			return nil, nil, e
		}
		if input.ID == 0 {
			if hash == "" {
				return nil, nil, adminError(400, "initial_password_required")
			}
			if e := assignable(tx, input.GroupID); e != nil {
				return nil, nil, e
			}
			now := time.Now()
			if e := tx.Raw(`INSERT INTO users(group_id,username,password,email,nama,no_telp,alamat,created_by,created_at,updated_at,status)
       VALUES(?,?,?,?,?,?,?,?,?,?,1) RETURNING *`,
				input.GroupID, input.Username, hash, input.Email, input.Nama, input.NoTelp, input.Alamat, actor.ID, now, now).
				Scan(&result).Error; e != nil {
				return nil, nil, e
			}
			return nil, safeUser(result), nil
		}
		var before models.User
		if e := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&before, input.ID).Error; e != nil {
			return nil, nil, adminError(404, "user_unavailable")
		}
		if revision < 1 || before.Revision != revision {
			return nil, nil, adminError(409, "stale_revision")
		}
		if hash != "" {
			return nil, nil, adminError(400, "use_password_reset")
		}
		if actor.ID == before.ID && (before.Username != input.Username || before.Email != input.Email) {
			return nil, nil, adminError(403, "self_security_change")
		}
		if before.GroupID != input.GroupID {
			if actor.ID == before.ID {
				return nil, nil, adminError(403, "self_group_change")
			}
			var old models.Group
			if e := tx.First(&old, before.GroupID).Error; e != nil {
				return nil, nil, e
			}
			if old.GroupJenis == "superadmin" {
				return nil, nil, adminError(403, "privileged_transition_blocked")
			}
			if e := assignable(tx, input.GroupID); e != nil {
				return nil, nil, e
			}
		}
		changes := map[string]any{"group_id": input.GroupID, "username": input.Username, "email": input.Email,
			"nama": input.Nama, "no_telp": input.NoTelp, "alamat": input.Alamat, "updated_by": actor.ID,
			"updated_at": time.Now(), "revision": gorm.Expr("revision+1")}
		if before.GroupID != input.GroupID || before.Username != input.Username || before.Email != input.Email {
			changes["security_version"] = gorm.Expr("security_version+1")
		}
		if e := tx.Model(&models.User{}).Where("id=? AND revision=?", input.ID, revision).Updates(changes).Error; e != nil {
			return nil, nil, e
		}
		if e := tx.First(&result, input.ID).Error; e != nil {
			return nil, nil, e
		}
		return safeUser(before), safeUser(result), nil
	})
	return result, err
}

func (a Administration) UserSecurity(ctx context.Context, actor AdminActor, id uint, revision int64, passwordHash string) error {
	action, permission := "user_deactivate", "delete"
	if passwordHash != "" {
		action, permission = "password_reset", "update"
	}
	return a.Mutate(ctx, actor, "users", permission, action, "user", id, func(tx *gorm.DB) (any, any, error) {
		if actor.ID == id {
			return nil, nil, adminError(403, "self_security_change")
		}
		var before models.User
		if e := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&before, id).Error; e != nil {
			return nil, nil, adminError(404, "user_unavailable")
		}
		if revision < 1 || before.Revision != revision {
			return nil, nil, adminError(409, "stale_revision")
		}
		changes := map[string]any{"revision": gorm.Expr("revision+1"), "security_version": gorm.Expr("security_version+1"),
			"updated_at": time.Now(), "updated_by": actor.ID}
		if passwordHash == "" {
			changes["status"] = 0
		} else {
			changes["password"] = passwordHash
		}
		if e := tx.Model(&models.User{}).Where("id=?", id).Updates(changes).Error; e != nil {
			return nil, nil, e
		}
		var after models.User
		if e := tx.First(&after, id).Error; e != nil {
			return nil, nil, e
		}
		return safeUser(before), safeUser(after), nil
	})
}

func (a Administration) GroupChange(ctx context.Context, actor AdminActor, input models.Group, revision int64, remove bool, expectedMembership ...string) error {
	permission, action := "update", "group_update"
	if input.ID == 0 {
		permission, action = "create", "group_create"
	}
	if remove {
		permission, action = "delete", "group_deactivate"
	}
	input.GroupNama = strings.TrimSpace(input.GroupNama)
	return a.Mutate(ctx, actor, "groups", permission, action, "group", input.ID, func(tx *gorm.DB) (any, any, error) {
		if input.ID == 0 {
			if input.GroupJenis != "user" || strings.TrimSpace(input.GroupNama) == "" || len(input.GroupNama) > 160 {
				return nil, nil, adminError(422, "group_not_assignable")
			}
			now := time.Now()
			var createdID uint
			err := tx.Raw(`INSERT INTO groups(group_nama,group_jenis,status,created_by,created_at,updated_at)
              VALUES(?,'user',1,?,?,?) RETURNING id`, strings.TrimSpace(input.GroupNama), actor.ID, now, now).Scan(&createdID).Error
			return nil, map[string]any{"id": createdID, "name": strings.TrimSpace(input.GroupNama), "kind": "user", "status": 1, "revision": 1}, err
		}
		var before models.Group
		if e := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&before, input.ID).Error; e != nil {
			return nil, nil, adminError(404, "group_unavailable")
		}
		if before.GroupJenis == "superadmin" {
			return nil, nil, adminError(403, "protected_group")
		}
		if before.GroupJenis != "user" || before.Status != 1 {
			return nil, nil, adminError(409, "group_inactive")
		}
		if revision < 1 || revision != before.Revision {
			return nil, nil, adminError(409, "stale_revision")
		}
		changes := map[string]any{"revision": gorm.Expr("revision+1"), "updated_at": time.Now(), "updated_by": actor.ID}
		if remove {
			var membership string
			if e := tx.Raw("SELECT "+GroupMembershipSQL+" FROM users m WHERE m.group_id=?", input.ID).Scan(&membership).Error; e != nil {
				return nil, nil, e
			}
			if len(expectedMembership) != 1 || expectedMembership[0] != membership {
				return nil, nil, adminError(409, "membership_changed")
			}
			changes["status"] = 0
		} else {
			if input.GroupJenis != before.GroupJenis || strings.TrimSpace(input.GroupNama) == "" || len(input.GroupNama) > 160 {
				return nil, nil, adminError(403, "privileged_transition_blocked")
			}
			changes["group_nama"] = strings.TrimSpace(input.GroupNama)
		}
		if e := tx.Model(&models.Group{}).Where("id=?", input.ID).Updates(changes).Error; e != nil {
			return nil, nil, e
		}
		if remove {
			if e := tx.Model(&models.User{}).Where("group_id=?", input.ID).UpdateColumn("security_version", gorm.Expr("security_version+1")).Error; e != nil {
				return nil, nil, e
			}
		}
		var after models.Group
		if e := tx.First(&after, input.ID).Error; e != nil {
			return nil, nil, e
		}
		return before, after, nil
	})
}

func (a Administration) Grants(ctx context.Context, actor AdminActor, id uint, revision int64, items []request.SidebarAccessItem) error {
	return a.Mutate(ctx, actor, "groups", "update", "group_grants", "group", id, func(tx *gorm.DB) (any, any, error) {
		var group models.Group
		if e := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&group, id).Error; e != nil || group.Status != 1 {
			return nil, nil, adminError(404, "group_unavailable")
		}
		if revision < 1 || group.Revision != revision {
			return nil, nil, adminError(409, "stale_revision")
		}
		if len(items) > 1000 {
			return nil, nil, adminError(400, "invalid_grants")
		}
		var before []models.SidebarAccess
		if e := tx.Where("group_id=?", id).Order("sidebar_id").Find(&before).Error; e != nil {
			return nil, nil, e
		}
		seen := map[uint]bool{}
		for _, item := range items {
			if seen[item.SidebarID] || item.SidebarID == 0 || item.Read < 0 || item.Read > 1 || item.Create < 0 || item.Create > 1 || item.Update < 0 || item.Update > 1 || item.Delete < 0 || item.Delete > 1 ||
				item.Read == 0 && (item.Create == 1 || item.Update == 1 || item.Delete == 1) {
				return nil, nil, adminError(400, "invalid_grants")
			}
			seen[item.SidebarID] = true
			var count int64
			if e := tx.Model(&models.Sidebar{}).Where("id=? AND status=1", item.SidebarID).Count(&count).Error; e != nil {
				return nil, nil, e
			}
			if count != 1 {
				return nil, nil, adminError(422, "invalid_reference")
			}
		}
		if e := tx.Where("group_id=?", id).Delete(&models.SidebarAccess{}).Error; e != nil {
			return nil, nil, e
		}
		for _, item := range items {
			if e := tx.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete",created_by,updated_by,created_at,updated_at)
       VALUES(?,?,?,?,?,?,?,?,now(),now())`, id, item.SidebarID, item.Read, item.Create, item.Update, item.Delete, actor.ID, actor.ID).Error; e != nil {
				return nil, nil, e
			}
		}
		if e := tx.Model(&models.Group{}).Where("id=?", id).UpdateColumn("revision", gorm.Expr("revision+1")).Error; e != nil {
			return nil, nil, e
		}
		return before, items, nil
	})
}
