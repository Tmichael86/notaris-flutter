package repositories

import (
	"context"
	"database/sql"
	"gorm.io/gorm"
)

// Bootstrap appends missing current-version snapshots, including inactive rows.
// Call from an explicit deployment/admin workflow before initial client sync.
// It assigns no cursor: the existing serialized publisher handles publication.
func (r *PetugasPublicationRepository) Bootstrap(ctx context.Context) (int, error) {
	count := 0
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Blocks INSERT/UPDATE/DELETE on petugas and serializes other bootstraps.
		// Under READ COMMITTED, the SELECT below observes writes completed before
		// this lock. Later writes append their own next-version events after commit.
		if err := tx.Exec("LOCK TABLE petugas IN SHARE ROW EXCLUSIVE MODE").Error; err != nil {
			return err
		}
		var rows []struct{ ID uint }
		if err := tx.Raw(`SELECT p.id FROM petugas p WHERE NOT EXISTS
   (SELECT 1 FROM petugas_sync_outbox o WHERE o.petugas_uuid=p.uuid AND o.row_version=p.row_version)
   ORDER BY p.id`).Scan(&rows).Error; err != nil {
			return err
		}
		for _, row := range rows {
			if err := recordLegacyPetugasEvent(tx, row.ID); err != nil {
				return err
			}
			count++
		}
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return 0, err
	}
	return count, nil
}
