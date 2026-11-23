package repositories

import (
	"context"
	"errors"
	"regexp"
	"time"

	"backend-notaris-go/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// MasterMutationAdminLock shares the administration lock namespace. Operational
// writes take it SHARED; Users/Groups/grant administration takes it EXCLUSIVE.
const MasterMutationAdminLock int64 = 71920261119

// MutationActor is supplied by JWTAuth after signature/expiry verification, never
// by a request body. A bare numeric audit user ID is not authentication.
type MutationActor struct {
	UserID, GroupID  uint
	SecurityVersion  *int64
	SecurityRequired bool
	ExpiresAt        time.Time
}

type mutationActorKey struct{}

func WithMutationActor(ctx context.Context, actor MutationActor) context.Context {
	if actor.SecurityVersion != nil {
		version := *actor.SecurityVersion
		actor.SecurityVersion = &version
	}
	return context.WithValue(ctx, mutationActorKey{}, actor)
}

type MutationAccessError struct {
	Status int
	Code   string
}

func (e *MutationAccessError) Error() string { return e.Code }

var ErrMasterUUIDConflict = errors.New("master UUID already exists with different payload")
var ErrInvalidMutationInput = errors.New("invalid mutation input")
var mutationUUIDPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

type mutationAccess struct {
	actor  MutationActor
	grant  models.SidebarAccess
	action string
}

func (a *mutationAccess) require(action string) error {
	if !time.Now().Before(a.actor.ExpiresAt) {
		return &MutationAccessError{401, "session_invalid"}
	}
	allowed := action == "create" && a.grant.Create == 1 || action == "update" && a.grant.Update == 1
	if !allowed {
		return &MutationAccessError{403, "action_forbidden"}
	}
	a.action = action
	return nil
}

// Exact initial CREATE retries are a no-op only for the original creator with
// CREATE permission. Other existing-record retries require UPDATE, even if equal.
func (a *mutationAccess) existing(equal, initialOwnCreate bool) error {
	if equal && initialOwnCreate && a.grant.Create == 1 {
		return a.require("create")
	}
	return a.require("update")
}

func authorizedMasterMutation(ctx context.Context, db *gorm.DB, userID uint, code string, fn func(*gorm.DB, *mutationAccess) error) error {
	actor, ok := ctx.Value(mutationActorKey{}).(MutationActor)
	if !ok || userID == 0 || actor.UserID != userID || actor.GroupID == 0 || !time.Now().Before(actor.ExpiresAt) ||
		(actor.SecurityRequired && (actor.SecurityVersion == nil || *actor.SecurityVersion < 1)) {
		return &MutationAccessError{401, "session_invalid"}
	}
	switch code {
	case "kategori_pekerjaan", "jenis_pengeluaran", "pemohon":
	default:
		return &MutationAccessError{403, "action_forbidden"}
	}
	return db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec("SELECT pg_advisory_xact_lock_shared(?)", MasterMutationAdminLock).Error; err != nil {
			return err
		}
		var user models.User
		if err := tx.Clauses(clause.Locking{Strength: "SHARE"}).Where("id = ?", actor.UserID).Take(&user).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return &MutationAccessError{401, "session_invalid"}
			}
			return err
		}
		if user.Status != 1 || user.GroupID != actor.GroupID || (actor.SecurityRequired && user.SecurityVersion != *actor.SecurityVersion) {
			return &MutationAccessError{401, "session_invalid"}
		}
		var group models.Group
		if err := tx.Clauses(clause.Locking{Strength: "SHARE"}).Where("id = ? AND status = 1", user.GroupID).Take(&group).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return &MutationAccessError{403, "action_forbidden"}
			}
			return err
		}
		var grants []models.SidebarAccess
		// Exactly one canonical active grant, no aliases or group-type bypass.
		err := tx.Table("sidebar_akses AS a").Select("a.*").Joins("JOIN sidebar AS s ON s.id = a.sidebar_id").
			Where("a.group_id = ? AND s.sidebar_kode = ? AND s.status = 1 AND s.sidebar_route <> '#'", user.GroupID, code).
			Limit(2).Clauses(clause.Locking{Strength: "SHARE", Table: clause.Table{Name: "a"}}).Find(&grants).Error
		if err != nil {
			return err
		}
		if len(grants) != 1 {
			return &MutationAccessError{403, "action_forbidden"}
		}
		a := &mutationAccess{actor: actor, grant: grants[0]}
		if err := fn(tx, a); err != nil {
			return err
		}
		return a.require(a.action) // Also reject expiry before COMMIT or an unclassified write.
	})
}
