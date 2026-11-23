package routes

import (
	"context"
	"testing"

	"backend-notaris-go/services"
	"gorm.io/gorm"
)

func TestH05LegacyVarcharProposal(t *testing.T) {
	for _, kind := range []string{"valid", "wrong-check", "wrong-index", "partial-index"} {
		t.Run(kind, func(t *testing.T) {
			f := usersSetupBeforeP0(t, func(db *gorm.DB) {
				// Actual archived Laravel column types, established BEFORE applying
				// the unchanged P0 proposal, not conversions of already-created checks.
				err := db.Exec(`ALTER TABLE users ALTER COLUMN username TYPE varchar(255),ALTER COLUMN email TYPE varchar(255);
 ALTER TABLE groups ALTER COLUMN group_jenis TYPE varchar(255);
 ALTER TABLE sidebar ALTER COLUMN sidebar_kode TYPE varchar(255)`).Error
				if err != nil {
					t.Fatal(err)
				}
			})
			var err error
			switch kind {
			case "wrong-check":
				err = f.db.Exec("ALTER TABLE users DROP CONSTRAINT users_security_identity_nonempty; ALTER TABLE users ADD CONSTRAINT users_security_identity_nonempty CHECK(true)").Error
			case "wrong-index":
				err = f.db.Exec("DROP INDEX users_username_normalized; CREATE UNIQUE INDEX users_username_normalized ON users(username)").Error
			case "partial-index":
				err = f.db.Exec("DROP INDEX users_username_normalized; CREATE UNIQUE INDEX users_username_normalized ON users(lower(btrim(username))) WHERE status=1").Error
			}
			if err != nil {
				t.Fatal(err)
			}
			before := h04Snapshot(t, f)
			err = (services.Administration{DB: f.db, Enabled: true}).Ready(context.Background())
			if (err == nil) != (kind == "valid") {
				t.Fatalf("legacy type readiness %s: %v", kind, err)
			}
			if before != h04Snapshot(t, f) {
				t.Fatal("legacy readiness mutated rows or sequence states")
			}
		})
	}
}
