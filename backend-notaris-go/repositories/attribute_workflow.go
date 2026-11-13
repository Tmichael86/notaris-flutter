package repositories

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"gorm.io/gorm"
)

var (
	ErrAttributeForbidden = errors.New("workflow permission denied")
	ErrAttributeInvalid   = errors.New("invalid workflow command")
	ErrAttributeConflict  = errors.New("workflow revision conflict")
)

type AttributeWorkflow struct{ DB *gorm.DB }

type AttributeCommand struct {
	MutationID       string `json:"mutation_id"`
	DefinitionUUID   string `json:"definition_uuid"`
	ExpectedRevision int64  `json:"expected_revision"`
	Action           string `json:"action"`
	Value            string `json:"value,omitempty"`
	Reason           string `json:"reason,omitempty"`
}

type AttributeEvent struct {
	UUID       string    `json:"uuid"`
	Action     string    `json:"action"`
	ActorID    int64     `json:"actor_id"`
	ActorName  string    `json:"actor_name"`
	Revision   int64     `json:"revision"`
	Version    int64     `json:"version"`
	Value      *string   `json:"value,omitempty"`
	Reason     *string   `json:"reason,omitempty"`
	OccurredAt time.Time `json:"occurred_at"`
}

type AttributeView struct {
	TransactionUUID string           `json:"transaction_uuid"`
	DetailUUID      string           `json:"detail_uuid"`
	ProcessUUID     string           `json:"process_uuid"`
	DefinitionUUID  string           `json:"definition_uuid"`
	Name            string           `json:"name"`
	ValueType       string           `json:"value_type"`
	Status          string           `json:"status"`
	Revision        int64            `json:"revision"`
	Version         int64            `json:"version"`
	InitializedAt   *time.Time       `json:"initialized_at"`
	InitializedBy   *int64           `json:"initialized_by"`
	Role            string           `json:"role"`
	CanFill         bool             `json:"can_fill"`
	CanDecide       bool             `json:"can_decide"`
	History         []AttributeEvent `json:"history" gorm:"-"`
	OfficeUUID      string           `json:"-"`
	SubmitterID     *int64           `json:"-"`
}

type AttributeNotification struct {
	EventUUID         string     `json:"event_uuid"`
	Action            string     `json:"action"`
	Version           int64      `json:"version"`
	Reason            *string    `json:"reason,omitempty"`
	OccurredAt        time.Time  `json:"occurred_at"`
	ReadAt            *time.Time `json:"read_at"`
	TransactionUUID   string     `json:"transaction_uuid"`
	TransactionNumber string     `json:"transaction_number"`
	DetailUUID        string     `json:"detail_uuid"`
	ProcessUUID       string     `json:"process_uuid"`
	DefinitionUUID    string     `json:"definition_uuid"`
	AttributeName     string     `json:"attribute_name"`
}

const attributeRelations = `
 JOIN attribute_workflow_definition def ON def.uuid=w.definition_uuid AND def.office_uuid=w.office_uuid
 JOIN transaction_cloud_process p ON p.uuid=w.process_uuid AND p.deleted_at IS NULL AND p.snapshot->>'source_id'=def.source_process_id
 JOIN transaction_cloud_detail d ON d.uuid=p.detail_uuid AND d.deleted_at IS NULL
 JOIN transaction_cloud t ON t.id=d.transaction_id AND t.deleted_at IS NULL AND t.domain='notaris'`

// Recheck active office membership and current menu permission inside the
// repository, including for recipient selection. There is no admin bypass.
const attributeActors = `
 JOIN users u ON u.id=m.user_id AND u.status=1
 JOIN groups g ON g.id=u.group_id AND g.status=1`
const attributeRead = `
 EXISTS (SELECT 1 FROM sidebar_akses a JOIN sidebar s ON s.id=a.sidebar_id
   WHERE a.group_id=u.group_id AND a."read"=1 AND s.sidebar_kode='transaksi'
   AND s.status=1 AND s.sidebar_route!='#')`

func attributeView(tx *gorm.DB, process string, actor int64, locked bool) (AttributeView, error) {
	var view AttributeView
	query := `SELECT t.uuid::text AS transaction_uuid, d.uuid::text AS detail_uuid,
 w.process_uuid::text, w.definition_uuid::text, w.office_uuid::text, def.name, def.value_type,
 w.status,w.revision,w.version,w.initialized_at,w.initialized_by,w.submitter_id,m.role
 FROM attribute_workflow_item w` + attributeRelations + `
 JOIN attribute_workflow_member m ON m.office_uuid=w.office_uuid AND m.user_id=?` + attributeActors + `
 WHERE w.process_uuid=?::uuid AND` + attributeRead
	if locked {
		query += " FOR UPDATE OF w FOR SHARE OF p,d,t,m,u,g"
	}
	result := tx.Raw(query, actor, process).Scan(&view)
	if result.Error != nil {
		return view, result.Error
	}
	if result.RowsAffected != 1 {
		return view, ErrAttributeForbidden
	}
	owns := view.SubmitterID == nil || *view.SubmitterID == actor
	view.CanFill = view.Role == "worker" && owns && view.InitializedAt != nil && (view.Status == "draft" || view.Status == "revision")
	view.CanDecide = view.Role == "reviewer" && view.Status == "waiting" && view.SubmitterID != nil && !owns
	return view, nil
}

func (r AttributeWorkflow) View(ctx context.Context, process string, actor int64) (view AttributeView, err error) {
	if !notarisCloudUUID.MatchString(process) || actor <= 0 {
		return view, ErrAttributeInvalid
	}
	err = r.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var e error
		view, e = attributeView(tx, process, actor, false)
		if e != nil {
			return e
		}
		view.History = []AttributeEvent{}
		return tx.Raw(`SELECT e.uuid::text,e.action,e.actor_id,coalesce(u.nama,'') AS actor_name,
      e.revision,e.version,e.value,e.reason,e.occurred_at FROM attribute_workflow_event e
      JOIN users u ON u.id=e.actor_id WHERE e.process_uuid=?::uuid ORDER BY e.revision`, process).Scan(&view.History).Error
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	return
}

func (r AttributeWorkflow) Execute(ctx context.Context, process string, actor int64, c AttributeCommand) (revision int64, err error) {
	if !notarisCloudUUID.MatchString(process) || !notarisCloudUUID.MatchString(c.MutationID) ||
		!notarisCloudUUID.MatchString(c.DefinitionUUID) || actor <= 0 || c.ExpectedRevision < 0 {
		return 0, ErrAttributeInvalid
	}
	c.Value, c.Reason = strings.TrimSpace(c.Value), strings.TrimSpace(c.Reason)
	if strings.ContainsRune(c.Value, 0) || strings.ContainsRune(c.Reason, 0) ||
		utf8.RuneCountInString(c.Value) > 2000 || utf8.RuneCountInString(c.Reason) > 1000 {
		return 0, ErrAttributeInvalid
	}
	switch c.Action {
	case "initialize", "approve":
		if c.Value != "" || c.Reason != "" {
			return 0, ErrAttributeInvalid
		}
	case "submit":
		if c.Value == "" || c.Reason != "" {
			return 0, ErrAttributeInvalid
		}
	case "revise":
		if c.Value != "" || c.Reason == "" {
			return 0, ErrAttributeInvalid
		}
	default:
		return 0, ErrAttributeInvalid
	}
	payload, _ := json.Marshal(c)
	hash := fmt.Sprintf("%x", sha256.Sum256(payload))
	err = r.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		view, e := attributeView(tx, process, actor, true)
		if e != nil {
			return e
		}
		if c.DefinitionUUID != view.DefinitionUUID {
			return ErrAttributeConflict
		}
		worker := c.Action == "initialize" || c.Action == "submit"
		if worker != (view.Role == "worker") || (!worker && view.SubmitterID != nil && *view.SubmitterID == actor) {
			return ErrAttributeForbidden
		}
		if e = tx.Exec("SELECT pg_advisory_xact_lock(hashtextextended(?::text,0))", c.MutationID).Error; e != nil {
			return e
		}
		var previous struct {
			ProcessUUID string
			ActorID     int64
			RequestHash string
			Revision    int64
		}
		hit := tx.Raw("SELECT process_uuid::text,actor_id,request_hash,revision FROM attribute_workflow_event WHERE uuid=?::uuid", c.MutationID).Scan(&previous)
		if hit.Error != nil {
			return hit.Error
		}
		if hit.RowsAffected == 1 {
			if previous.ProcessUUID != process || previous.ActorID != actor || previous.RequestHash != hash {
				return ErrAttributeConflict
			}
			revision = previous.Revision
			return nil
		}
		if c.Action == "initialize" && view.InitializedAt != nil {
			revision = view.Revision
			return nil
		}
		if view.Revision != c.ExpectedRevision {
			return ErrAttributeConflict
		}
		var recipients []int64
		revision = view.Revision + 1
		version := view.Version
		var write *gorm.DB
		switch c.Action {
		case "initialize":
			write = tx.Exec("UPDATE attribute_workflow_item SET initialized_by=?,initialized_at=clock_timestamp(),revision=? WHERE process_uuid=?::uuid", actor, revision, process)
		case "submit":
			if view.SubmitterID != nil && *view.SubmitterID != actor {
				return ErrAttributeForbidden
			}
			if !view.CanFill {
				return ErrAttributeConflict
			}
			if e = tx.Raw(`SELECT m.user_id FROM attribute_workflow_member m`+attributeActors+`
     WHERE m.office_uuid=?::uuid AND m.role='reviewer' AND m.user_id!=? AND`+attributeRead+
				" ORDER BY m.user_id FOR SHARE OF m,u,g", view.OfficeUUID, actor).Scan(&recipients).Error; e != nil {
				return e
			}
			if len(recipients) == 0 {
				return ErrAttributeConflict
			}
			version++
			write = tx.Exec("UPDATE attribute_workflow_item SET status='waiting',revision=?,version=?,submitter_id=? WHERE process_uuid=?::uuid", revision, version, actor, process)
		case "approve", "revise":
			if !view.CanDecide {
				return ErrAttributeConflict
			}
			if e = tx.Raw(`SELECT m.user_id FROM attribute_workflow_member m`+attributeActors+`
     WHERE m.office_uuid=?::uuid AND m.user_id=? AND`+attributeRead+
				" FOR SHARE OF m,u,g", view.OfficeUUID, *view.SubmitterID).Scan(&recipients).Error; e != nil {
				return e
			}
			if len(recipients) != 1 {
				return ErrAttributeConflict
			}
			next := "valid"
			if c.Action == "revise" {
				next = "revision"
			}
			write = tx.Exec("UPDATE attribute_workflow_item SET status=?,revision=? WHERE process_uuid=?::uuid", next, revision, process)
		}
		if write.Error != nil {
			return write.Error
		}
		if e = tx.Exec(`INSERT INTO attribute_workflow_event(uuid,process_uuid,actor_id,request_hash,action,revision,version,value,reason)
    VALUES(?::uuid,?::uuid,?,?,?,?,?,nullif(?,''),nullif(?,''))`,
			c.MutationID, process, actor, hash, c.Action, revision, version, c.Value, c.Reason).Error; e != nil {
			return e
		}
		for _, recipient := range recipients {
			if e = tx.Exec("INSERT INTO attribute_workflow_inbox(event_uuid,recipient_id) VALUES(?::uuid,?)", c.MutationID, recipient).Error; e != nil {
				return e
			}
		}
		return nil
	})
	return
}

const attributeInboxFrom = ` FROM attribute_workflow_inbox i
 JOIN attribute_workflow_event e ON e.uuid=i.event_uuid
 JOIN attribute_workflow_item w ON w.process_uuid=e.process_uuid` + attributeRelations + `
 JOIN attribute_workflow_member m ON m.office_uuid=w.office_uuid AND m.user_id=i.recipient_id` + attributeActors + `
 WHERE i.recipient_id=? AND` + attributeRead

func (r AttributeWorkflow) Inbox(ctx context.Context, actor int64) ([]AttributeNotification, error) {
	items := []AttributeNotification{}
	err := r.DB.WithContext(ctx).Raw(`SELECT e.uuid::text AS event_uuid,e.action,e.version,e.reason,e.occurred_at,i.read_at,
 t.uuid::text AS transaction_uuid,t.final_number AS transaction_number,d.uuid::text AS detail_uuid,p.uuid::text AS process_uuid,
 def.uuid::text AS definition_uuid,def.name AS attribute_name`+attributeInboxFrom+
		" ORDER BY e.occurred_at DESC,e.uuid LIMIT 100", actor).Scan(&items).Error
	return items, err
}

func (r AttributeWorkflow) MarkRead(ctx context.Context, actor int64, event string) error {
	if !notarisCloudUUID.MatchString(event) {
		return ErrAttributeInvalid
	}
	result := r.DB.WithContext(ctx).Exec(`UPDATE attribute_workflow_inbox n SET read_at=coalesce(n.read_at,clock_timestamp())
 WHERE n.recipient_id=? AND n.event_uuid=?::uuid AND EXISTS (SELECT 1`+attributeInboxFrom+" AND i.event_uuid=n.event_uuid)", actor, event, actor)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return ErrAttributeForbidden
	}
	return nil
}
