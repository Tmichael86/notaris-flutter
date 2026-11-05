// Package petugasops is the bounded, explicit initial-development rollout.
// It never migrates, grants, resets sequences, or implements another publisher.
package petugasops

import (
	"context"
	"crypto/md5"
	"database/sql"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"regexp"
	"sort"
	"strings"
	"time"

	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"backend-notaris-go/synccontract"
	"gorm.io/gorm"
)

// schemaSQL deliberately leaves the historical grants-recovery files unchanged:
// their exact checksums are part of the already committed operator receipt.
//
//go:embed schema.sql
var schemaSQL string

type Baseline struct {
	AppRole         string `json:"app_role"`
	PetugasHash     string `json:"petugas_hash"`
	UUIDHash        string `json:"uuid_hash"`
	TransactionHash string `json:"transaction_hash"`
	DetailHash      string `json:"detail_hash"`
	PaymentHash     string `json:"payment_hash"`
}

func (b Baseline) Validate() error {
	if !regexp.MustCompile(`^[a-z_][a-z0-9_]{0,62}$`).MatchString(b.AppRole) || b.AppRole == "postgres" {
		return errors.New("explicit restricted application role required")
	}
	for _, hash := range []string{b.PetugasHash, b.UUIDHash, b.TransactionHash, b.DetailHash, b.PaymentHash} {
		if !regexp.MustCompile(`^[a-f0-9]{32}$`).MatchString(hash) {
			return errors.New("verified baseline fingerprints required")
		}
	}
	return nil
}

type Options struct {
	Apply                    bool
	Operation                string // bootstrap, drain, bootstrap-and-drain
	BatchSize, MaxBatches    int
	RequirePublishedBaseline bool
}

func (o Options) Validate() error {
	if o.Operation != "bootstrap" && o.Operation != "drain" && o.Operation != "bootstrap-and-drain" {
		return errors.New("unknown operation")
	}
	if o.BatchSize < 1 || o.BatchSize > 500 || o.MaxBatches < 1 || o.MaxBatches > 100 {
		return errors.New("batch size or execution bound invalid")
	}
	if o.Apply && o.RequirePublishedBaseline {
		return errors.New("published-baseline gate is read-only")
	}
	return nil
}

type State struct {
	Outbox, Pending, Published, LastSeq, MinCursor int64
	SequenceLast                                   int64
	SequenceCalled                                 bool
	PullCount                                      int
}

func (s State) Ready() bool {
	return s.Outbox == 4 && s.Pending == 0 && s.Published == 4 && s.LastSeq == 4 && s.MinCursor == 0 && s.PullCount == 4
}

type Event struct {
	Stage string `json:"stage"`
	Count int    `json:"count"`
	State State  `json:"state"`
}

// Run's public entry point cannot opt in to another host/database/port.
func Run(ctx context.Context, db *gorm.DB, b Baseline, o Options, emit func(Event)) (State, error) {
	return run(ctx, db, b, o, 5432, emit)
}

// The private port argument is used only by same-package disposable tests.
func run(ctx context.Context, db *gorm.DB, b Baseline, o Options, port int, emit func(Event)) (state State, err error) {
	if err = b.Validate(); err != nil {
		return
	}
	if err = o.Validate(); err != nil {
		return
	}
	if emit == nil {
		emit = func(Event) {}
	}
	err = db.WithContext(ctx).Connection(func(conn *gorm.DB) error {
		// One pinned session retains the advisory lock across phase commits.
		// Other runners fail immediately; CRUD clients must remain in maintenance.
		if o.Apply {
			var locked bool
			if e := conn.Raw("SELECT pg_try_advisory_lock(7281946103101)").Scan(&locked).Error; e != nil {
				return e
			}
			if !locked {
				return errors.New("another Petugas operations runner holds the maintenance lock")
			}
			defer func() {
				// A deadline must not prevent session-lock cleanup.
				cleanup, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
				defer cancel()
				conn.WithContext(cleanup).Exec("SELECT pg_advisory_unlock(7281946103101)")
			}()
		}
		var original map[string]string
		if o.RequirePublishedBaseline {
			// Runtime startup checks retained baseline history, not frozen live
			// rows. Later legitimate CRUD must not make worker restarts impossible.
			e := conn.Transaction(func(tx *gorm.DB) error {
				if e := verifyTarget(tx, b, port); e != nil {
					return e
				}
				var e error
				state, e = inspectPublishedHistory(tx, b)
				return e
			}, &sql.TxOptions{ReadOnly: true, Isolation: sql.LevelRepeatableRead})
			if e != nil {
				return e
			}
			emit(Event{Stage: "dry_run_verified", State: state})
			return nil
		}
		preflight := func(tx *gorm.DB) error {
			var e error
			state, e = inspect(tx, b, port)
			if e != nil {
				return e
			}
			hashes, e := legacySnapshot(tx)
			if e != nil {
				return e
			}
			if original == nil {
				original = hashes
			} else if !reflect.DeepEqual(original, hashes) {
				return errors.New("legacy table/sequence snapshot changed; inspect without reset or restore")
			}
			return nil
		}
		if e := conn.Transaction(preflight, &sql.TxOptions{ReadOnly: true, Isolation: sql.LevelRepeatableRead}); e != nil {
			return e
		}
		emit(Event{Stage: "preflight_verified", State: state})
		if !o.Apply {
			emit(Event{Stage: "dry_run_verified", State: state})
			return nil
		}
		// Each phase is committed independently. Revalidate while holding the same
		// lock order before invoking the existing repository's nested transaction.
		phase := func(action func(*repositories.PetugasPublicationRepository) (int, error)) (n int, e error) {
			e = conn.Transaction(func(tx *gorm.DB) error {
				if e := tx.Exec("LOCK TABLE public.petugas IN SHARE ROW EXCLUSIVE MODE").Error; e != nil {
					return e
				}
				if e := tx.Exec("LOCK TABLE public.petugas_sync_publication, public.petugas_sync_outbox IN SHARE ROW EXCLUSIVE MODE").Error; e != nil {
					return e
				}
				if e := preflight(tx); e != nil {
					return e
				}
				var e error
				n, e = action(repositories.NewPetugasPublicationRepository(tx))
				if e != nil {
					return e
				}
				return preflight(tx)
			}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
			return
		}
		if o.Operation != "drain" {
			n, e := phase(func(r *repositories.PetugasPublicationRepository) (int, error) { return r.Bootstrap(ctx) })
			if e != nil {
				return e
			}
			emit(Event{Stage: "bootstrap_committed", Count: n, State: state})
		}
		if o.Operation != "bootstrap" {
			// A drain-only invocation must not silently complete with missing baselines.
			if state.Outbox != 4 {
				return errors.New("drain requires all four baseline events; run approved bootstrap first")
			}
			for batches := 0; state.Pending > 0; batches++ {
				if batches >= o.MaxBatches {
					return errors.New("drain batch bound reached; committed batches retained, rerun after inspection")
				}
				n, e := phase(func(r *repositories.PetugasPublicationRepository) (int, error) { return r.Publish(ctx, o.BatchSize) })
				if e != nil {
					return e
				}
				if n == 0 {
					return errors.New("pending outbox made no progress")
				}
				emit(Event{Stage: "publication_batch_committed", Count: n, State: state})
			}
			if !state.Ready() {
				return errors.New("final baseline/pull verification failed")
			}
		}
		emit(Event{Stage: "complete", State: state})
		return nil
	})
	return
}

func verifyTarget(tx *gorm.DB, b Baseline, port int) error {
	var identity struct {
		Database, Address, Role, Marker string
		Port                            int
		OtherSessions                   int64
	}
	err := tx.Raw(`SELECT current_database() AS database, inet_server_addr()::text AS address, inet_server_port() AS port, current_user AS role,
 (SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1) AS marker,
 (SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()) AS other_sessions`).Scan(&identity).Error
	if err != nil {
		return err
	}
	if identity.Database != "notarisdev" || identity.Address != "127.0.0.1/32" && identity.Address != "127.0.0.1" || identity.Port != port || identity.Role != b.AppRole || identity.Marker != "NOTARISDEV SYNTHETIC v1" || identity.OtherSessions != 0 {
		return errors.New("development target/role/marker/maintenance mismatch; stop other clients")
	}
	if err = tx.Exec(schemaSQL).Error; err != nil {
		return err
	}
	return checkPrivileges(tx)
}

func inspect(tx *gorm.DB, b Baseline, port int) (s State, err error) {
	if err = verifyTarget(tx, b, port); err != nil {
		return
	}
	var actual Baseline
	err = tx.Raw(`SELECT current_user AS app_role,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p)-ARRAY['uuid','row_version','deleted_at'] ORDER BY id)::text,'[]')) FROM public.petugas p) AS petugas_hash,
 (SELECT md5(string_agg(id::text||':'||uuid::text,',' ORDER BY id)) FROM public.petugas) AS uuid_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]')) FROM public.transaksi t) AS transaction_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d) AS detail_hash,
 (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.transaksi_riwayat_pembayaran p) AS payment_hash`).Scan(&actual).Error
	if err != nil {
		return
	}
	if actual != b {
		return s, errors.New("approved identity/data fingerprint changed")
	}
	var valid bool
	err = tx.Raw(`SELECT (SELECT array_agg(id ORDER BY id) FROM public.petugas)=ARRAY[101,102,103,104]::bigint[]
 AND (SELECT count(DISTINCT uuid) FROM public.petugas)=4
 AND NOT EXISTS(SELECT FROM public.petugas p WHERE row_version<>1 OR status<>1 OR deleted_at IS NOT NULL
 OR (jenis_kelamin IS NOT NULL AND NOT EXISTS(SELECT FROM public.jenis_kelamin g WHERE g.id=p.jenis_kelamin))
 OR (user_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.users u WHERE u.id=p.user_id)))
 AND NOT EXISTS(SELECT FROM public.petugas_sync_mutations)`).Scan(&valid).Error
	if err != nil {
		return
	}
	if !valid {
		return s, errors.New("four pristine Petugas identities/references and empty mutation receipts required")
	}
	var rows []models.Petugas
	if err = tx.Order("id").Find(&rows).Error; err != nil {
		return
	}
	for _, row := range rows {
		payload, e := json.Marshal(row)
		if e != nil {
			return s, e
		}
		var bad int64
		if err = tx.Raw(`SELECT count(*) FROM public.petugas_sync_outbox WHERE petugas_uuid=?::uuid AND (row_version<>1 OR tombstone OR payload<>?::jsonb)`, *row.UUID, string(payload)).Scan(&bad).Error; err != nil {
			return
		}
		if bad != 0 {
			return s, errors.New("noncanonical baseline outbox snapshot")
		}
	}
	err = tx.Raw(`SELECT count(*) AS outbox, count(*) FILTER(WHERE publication_seq IS NULL) AS pending,
 count(*) FILTER(WHERE publication_seq IS NOT NULL) AS published FROM public.petugas_sync_outbox`).Scan(&s).Error
	if err != nil {
		return
	}
	var pub []struct {
		ID                 int
		LastSeq, MinCursor int64
	}
	if err = tx.Table("public.petugas_sync_publication").Find(&pub).Error; err != nil {
		return
	}
	if len(pub) != 1 || pub[0].ID != 1 || pub[0].MinCursor != 0 || pub[0].LastSeq != s.Published || s.Outbox > 4 {
		return s, errors.New("publication counter/baseline bounds changed")
	}
	s.LastSeq, s.MinCursor = pub[0].LastSeq, pub[0].MinCursor
	err = tx.Raw(`SELECT NOT EXISTS(SELECT FROM public.petugas_sync_outbox o LEFT JOIN public.petugas p ON p.uuid=o.petugas_uuid
 WHERE p.id IS NULL OR o.row_version<>1 OR o.tombstone OR (o.publication_seq IS NULL)<>(o.published_at IS NULL)
 OR o.publication_seq<1 OR o.publication_seq>?)
 AND NOT EXISTS(SELECT FROM public.petugas_sync_outbox GROUP BY petugas_uuid HAVING count(*)>1)
 AND (SELECT count(DISTINCT publication_seq) FROM public.petugas_sync_outbox)=?`, s.LastSeq, s.LastSeq).Scan(&valid).Error
	if err != nil {
		return
	}
	if !valid {
		return s, errors.New("outbox identity/publication order/gaps invalid")
	}
	var seq struct {
		LastValue int64
		IsCalled  bool
	}
	if err = tx.Raw("SELECT last_value,is_called FROM public.petugas_sync_outbox_id_seq").Scan(&seq).Error; err != nil {
		return
	}
	s.SequenceLast, s.SequenceCalled = seq.LastValue, seq.IsCalled
	var maxID int64
	if err = tx.Raw("SELECT COALESCE(max(id),0) FROM public.petugas_sync_outbox").Scan(&maxID).Error; err != nil {
		return
	}
	// Sequence gaps from aborted inserts are valid. Never infer cursors from IDs,
	// never reset a used sequence, and never reject a safe post-crash retry for gaps.
	if seq.LastValue < 1 || seq.LastValue < maxID || maxID > 0 && !seq.IsCalled || !seq.IsCalled && seq.LastValue != 1 {
		return s, errors.New("outbox sequence inconsistent with committed journal")
	}
	s.PullCount, err = verifyPull(tx, rows, s.LastSeq)
	return
}

// This gate never writes or bootstraps and tolerates later pending CRUD events.
// Retention has no operational implementation yet; an expired baseline blocks
// startup for inspection rather than inventing a resync/reset policy.
func inspectPublishedHistory(tx *gorm.DB, b Baseline) (s State, err error) {
	var counters []struct {
		ID                 int
		LastSeq, MinCursor int64
	}
	if err = tx.Table("public.petugas_sync_publication").Find(&counters).Error; err != nil {
		return
	}
	if len(counters) != 1 || counters[0].ID != 1 || counters[0].LastSeq < 4 || counters[0].MinCursor != 0 {
		return s, errors.New("retained published baseline required before worker startup")
	}
	s.LastSeq = counters[0].LastSeq
	s.MinCursor = counters[0].MinCursor
	err = tx.Raw(`SELECT count(*) AS outbox,count(*) FILTER(WHERE publication_seq IS NULL) AS pending,count(*) FILTER(WHERE publication_seq IS NOT NULL) AS published FROM public.petugas_sync_outbox`).Scan(&s).Error
	if err != nil {
		return
	}
	s.LastSeq = counters[0].LastSeq
	var seq struct {
		LastValue int64
		IsCalled  bool
		MaxID     int64
	}
	if err = tx.Raw(`SELECT last_value,is_called,(SELECT COALESCE(max(id),0) FROM public.petugas_sync_outbox) AS max_id FROM public.petugas_sync_outbox_id_seq`).Scan(&seq).Error; err != nil {
		return
	}
	if !seq.IsCalled || seq.LastValue < seq.MaxID {
		return s, errors.New("outbox sequence behind committed runtime journal")
	}
	s.SequenceLast, s.SequenceCalled = seq.LastValue, seq.IsCalled
	var valid bool
	err = tx.Raw(`SELECT count(DISTINCT publication_seq)=? AND NOT EXISTS(SELECT FROM public.petugas_sync_outbox WHERE publication_seq<1 OR publication_seq>? OR (publication_seq IS NULL)<>(published_at IS NULL)) FROM public.petugas_sync_outbox`, s.LastSeq, s.LastSeq).Scan(&valid).Error
	if err != nil {
		return
	}
	if !valid || s.Published != s.LastSeq {
		return s, errors.New("committed publication history/counter mismatch")
	}
	page, e := repositories.NewPetugasPublicationRepository(tx).Pull(tx.Statement.Context, synccontract.PetugasPullRequest{Cursor: 0, Limit: 4})
	if e != nil {
		return s, e
	}
	if len(page.Changes) != 4 || page.NextCursor != 4 {
		return s, errors.New("initial incremental pull is missing baseline events")
	}
	identities := []string{}
	seen := map[uint]bool{}
	for i, c := range page.Changes {
		if c.PublicationSequence != int64(i+1) || c.ServerID < 101 || c.ServerID > 104 || seen[c.ServerID] || c.RowVersion != 1 || c.Tombstone || c.Payload == nil {
			return s, errors.New("initial published baseline identity invalid")
		}
		seen[c.ServerID] = true
		identities = append(identities, fmt.Sprintf("%d:%s", c.ServerID, c.PetugasUUID))
	}
	sort.Strings(identities)
	if fmt.Sprintf("%x", md5.Sum([]byte(strings.Join(identities, ",")))) != b.UUIDHash {
		return s, errors.New("published baseline UUIDs differ from approved installation")
	}
	s.PullCount = 4
	return
}

func checkPrivileges(tx *gorm.DB) error {
	var valid bool
	err := tx.Raw(`SELECT NOT EXISTS(SELECT FROM pg_auth_members WHERE member=(SELECT oid FROM pg_roles WHERE rolname=current_user))
 AND has_database_privilege(current_user,current_database(),'CONNECT') AND NOT has_database_privilege(current_user,current_database(),'CREATE')
 AND has_schema_privilege(current_user,'public','USAGE') AND NOT has_schema_privilege(current_user,'public','CREATE')
 AND NOT EXISTS(SELECT FROM (VALUES ('petugas',ARRAY['SELECT','INSERT','UPDATE','DELETE']::text[]),
 ('petugas_sync_mutations',ARRAY['SELECT','INSERT']::text[]),('petugas_sync_outbox',ARRAY['SELECT','INSERT','UPDATE']::text[]),
 ('petugas_sync_publication',ARRAY['SELECT','UPDATE']::text[])) v(tbl,allowed)
 CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege(current_user,'public.'||tbl,p)<>(p=ANY(allowed)) OR has_table_privilege(current_user,'public.'||tbl,p||' WITH GRANT OPTION'))
 AND NOT EXISTS(SELECT FROM unnest(ARRAY['SELECT','USAGE','UPDATE']) p
 WHERE has_sequence_privilege(current_user,'public.petugas_sync_outbox_id_seq',p)<>(p IN ('SELECT','USAGE'))
 OR has_sequence_privilege(current_user,'public.petugas_sync_outbox_id_seq',p||' WITH GRANT OPTION'))`).Scan(&valid).Error
	if err != nil {
		return err
	}
	if !valid {
		return errors.New("application grants/ownership mismatch")
	}
	// MAINTAIN only exists on PostgreSQL 17+.
	var version int
	if err = tx.Raw("SELECT current_setting('server_version_num')::integer").Scan(&version).Error; err != nil {
		return err
	}
	if version >= 170000 {
		if err = tx.Raw(`SELECT NOT EXISTS(SELECT FROM unnest(ARRAY['petugas','petugas_sync_mutations','petugas_sync_outbox','petugas_sync_publication']) t WHERE has_table_privilege(current_user,'public.'||t,'MAINTAIN'))`).Scan(&valid).Error; err != nil {
			return err
		}
		if !valid {
			return errors.New("unexpected MAINTAIN grant")
		}
	}
	return nil
}

func verifyPull(tx *gorm.DB, rows []models.Petugas, last int64) (int, error) {
	byID := map[uint]models.Petugas{}
	for _, p := range rows {
		byID[p.ID] = p
	}
	seen := map[uint]bool{}
	cursor := int64(0)
	for {
		page, err := repositories.NewPetugasPublicationRepository(tx).Pull(tx.Statement.Context, synccontract.PetugasPullRequest{Cursor: cursor, Limit: 2})
		if err != nil {
			return 0, err
		}
		for _, change := range page.Changes {
			p, ok := byID[change.ServerID]
			if !ok || seen[p.ID] || change.PetugasUUID != *p.UUID || change.RowVersion != 1 || change.Tombstone || change.PublicationSequence != cursor+1 || change.Payload == nil {
				return 0, errors.New("incremental pull identity/cursor invalid")
			}
			date := p.TanggalLahir
			if date != nil && len(*date) >= 10 {
				d := (*date)[:10]
				date = &d
			}
			want := synccontract.PetugasPayload{NIK: p.NIK, Nama: p.Nama, Alamat: p.Alamat, TempatLahir: p.TempatLahir, TanggalLahir: date, JenisKelaminID: p.JenisKelamin, NoTelp: p.NoTelp, Email: p.Email, UserID: p.UserID}
			if !reflect.DeepEqual(*change.Payload, want) {
				return 0, errors.New("incremental pull payload mismatch")
			}
			seen[p.ID] = true
			cursor = change.PublicationSequence
		}
		if page.NextCursor != cursor {
			return 0, errors.New("pull cursor mismatch")
		}
		if !page.HasMore {
			break
		}
		if len(page.Changes) == 0 {
			return 0, errors.New("pull made no progress")
		}
	}
	if cursor != last {
		return 0, errors.New("pull did not reach committed publication cursor")
	}
	return len(seen), nil
}

func legacySnapshot(tx *gorm.DB) (map[string]string, error) {
	var objects []struct{ Name, Kind string }
	if err := tx.Raw(`SELECT c.relname AS name,c.relkind::text AS kind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind IN ('r','p','S') AND c.relname NOT IN ('petugas_sync_mutations','petugas_sync_outbox','petugas_sync_publication','petugas_sync_outbox_id_seq') ORDER BY c.relname`).Scan(&objects).Error; err != nil {
		return nil, err
	}
	hashes := map[string]string{}
	for _, object := range objects {
		name := `public."` + strings.ReplaceAll(object.Name, `"`, `""`) + `"`
		query := fmt.Sprintf(`SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) FROM %s t`, name)
		if object.Kind == "S" {
			query = fmt.Sprintf(`SELECT md5(jsonb_build_array(last_value,is_called)::text) FROM %s`, name)
		}
		var hash string
		if err := tx.Raw(query).Scan(&hash).Error; err != nil {
			return nil, err
		}
		hashes[object.Name] = hash
	}
	return hashes, nil
}
