package repositories

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

var ErrUnexpectedMasterOutbox = errors.New("unexpected pending Master outbox event")

// PublishExpectedMaster is the controlled one-event path. Both publication
// counters are locked in a fixed order while checking both pending feeds, so
// another pending Master event prevents this event from being published.
func PublishExpectedMaster(ctx context.Context, db *gorm.DB, domain, uuid, operation string, revision int64) (int64, error) {
	if (domain != "notaris" && domain != "ppat") || !notarisCloudUUID.MatchString(uuid) || revision < 1 ||
		(operation != "create" && operation != "update" && operation != "delete") {
		return 0, ErrUnexpectedMasterOutbox
	}
	var publishedSeq int64
	err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, table := range []string{"pekerjaan_notaris_sync_publication", "pekerjaan_ppat_sync_publication"} {
			var locked int64
			if err := tx.Raw("SELECT last_seq FROM " + table + " WHERE id=1 FOR UPDATE").Row().Scan(&locked); err != nil {
				return err
			}
		}
		for _, feed := range []string{"notaris", "ppat"} {
			table := "pekerjaan_" + feed + "_sync_outbox"
			var pending int64
			if err := tx.Raw("SELECT count(*) FROM " + table + " WHERE publication_seq IS NULL").Row().Scan(&pending); err != nil {
				return err
			}
			if (feed == domain && pending != 1) || (feed != domain && pending != 0) {
				return ErrUnexpectedMasterOutbox
			}
		}
		outbox := "pekerjaan_" + domain + "_sync_outbox"
		publication := "pekerjaan_" + domain + "_sync_publication"
		var event struct {
			ID            int64
			AggregateUUID string
			Revision      int64
			Operation     string
			PayloadUUID   string
			Complete      bool
		}
		query := "SELECT id,aggregate_uuid::text AS aggregate_uuid,revision,operation,payload->>'uuid' AS payload_uuid," +
			"(payload ?& ARRAY['uuid','nama','harga','proses']) AS complete FROM " + outbox + " WHERE publication_seq IS NULL FOR UPDATE"
		if err := tx.Raw(query).Scan(&event).Error; err != nil {
			return err
		}
		if event.ID == 0 || event.AggregateUUID != uuid || event.PayloadUUID != uuid || event.Revision != revision || event.Operation != operation ||
			(operation != "delete" && !event.Complete) {
			return ErrUnexpectedMasterOutbox
		}
		if err := tx.Raw("UPDATE " + publication + " SET last_seq=last_seq+1 WHERE id=1 RETURNING last_seq").Row().Scan(&publishedSeq); err != nil {
			return err
		}
		result := tx.Exec("UPDATE "+outbox+" SET publication_seq=?,published_at=clock_timestamp() WHERE id=? AND publication_seq IS NULL", publishedSeq, event.ID)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 1 {
			return fmt.Errorf("%w: selected event changed", ErrUnexpectedMasterOutbox)
		}
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return 0, err
	}
	return publishedSeq, nil
}
