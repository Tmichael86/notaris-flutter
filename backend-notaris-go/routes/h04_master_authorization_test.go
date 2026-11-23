package routes

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"backend-notaris-go/controllers"
	"backend-notaris-go/models"
	"backend-notaris-go/repositories"
	"backend-notaris-go/services"
	"github.com/golang-jwt/jwt/v5"
	"gorm.io/gorm"
)

const h04UUID = "0a04abcd-1111-4222-8333-000000000001"
const h04OtherUUID = "0a04abcd-1111-4222-8333-000000000002"

type h04Resource struct{ code, table, path string }

var h04Resources = []h04Resource{
	{"kategori_pekerjaan", "pekerjaan_kategori", "/kategori-pekerjaan"},
	{"jenis_pengeluaran", "pengeluaran_jenis", "/jenis-pengeluaran"},
	{"pemohon", "pemohon", "/pemohon"},
}

func h04Setup(t *testing.T) usersFixture {
	t.Helper()
	f := usersSetup(t) // Enforces fresh-owned port, database marker and schema.
	ddl := `CREATE TABLE pekerjaan_kategori(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),nama text NOT NULL,created_by bigint REFERENCES users(id),updated_by bigint REFERENCES users(id),created_at timestamptz,updated_at timestamptz,status smallint);
 CREATE TABLE pengeluaran_jenis(LIKE pekerjaan_kategori INCLUDING ALL);
 CREATE TABLE jenis_kelamin(id int PRIMARY KEY,nama text,status smallint);
 INSERT INTO jenis_kelamin VALUES(1,'Laki-laki',1);
 CREATE TABLE pemohon(id bigserial PRIMARY KEY,uuid uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),nama text NOT NULL,alamat text,jenis_kelamin int REFERENCES jenis_kelamin(id),no_telp text,nik text,created_by bigint REFERENCES users(id),updated_by bigint REFERENCES users(id),created_at timestamptz,updated_at timestamptz,status smallint,is_dirty boolean DEFAULT false,last_synced_at timestamptz,deleted_at timestamptz);
 INSERT INTO sidebar(id,sidebar_nama,sidebar_kode,sidebar_route,status) VALUES (6,'Kategori','kategori_pekerjaan','/kategori-pekerjaan',1),(7,'Jenis','jenis_pengeluaran','/jenis-pengeluaran',1),(8,'Pemohon','pemohon','/pemohon',1);
 INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT 1,s,1,1,1,1 FROM generate_series(6,8) s;`
	if e := f.db.Exec(ddl).Error; e != nil {
		t.Fatal(e)
	}
	f.api = SetupRouter(f.cfg, controllers.NewHealthController(), controllers.NewPemohonController(), nil,
		controllers.NewSimpleMasterController("pekerjaan_kategori", "kategori pekerjaan"), controllers.NewSimpleMasterController("pengeluaran_jenis", "jenis pengeluaran"),
		controllers.NewGroupController(), controllers.NewUserController(), controllers.NewAuthController(services.NewAuthService(f.cfg)), controllers.NewMeController(), controllers.NewSidebarController(), controllers.NewSidebarAccessController(services.NewSidebarService()))
	return f
}

func h04Context() context.Context {
	v := int64(1)
	return repositories.WithMutationActor(context.Background(), repositories.MutationActor{UserID: 1, GroupID: 1, SecurityVersion: &v, SecurityRequired: true, ExpiresAt: time.Now().Add(time.Hour)})
}
func (r h04Resource) upsert(ctx context.Context, uuid, name string) error {
	if r.table == "pemohon" {
		_, e := repositories.NewPemohonRepository().UpsertByUUID(ctx, uuid, &models.Pemohon{Nama: name}, 1)
		return e
	}
	_, e := repositories.NewSimpleMasterRepository(r.table).UpsertByUUID(ctx, uuid, name, 1)
	return e
}
func (r h04Resource) create(ctx context.Context, name string) error {
	if r.table == "pemohon" {
		_, e := repositories.NewPemohonRepository().Create(ctx, &models.Pemohon{Nama: name}, 1)
		return e
	}
	_, e := repositories.NewSimpleMasterRepository(r.table).Create(ctx, name, 1)
	return e
}
func (r h04Resource) update(ctx context.Context, id uint64, name string) error {
	if r.table == "pemohon" {
		_, e := repositories.NewPemohonRepository().Update(ctx, id, &models.Pemohon{Nama: name}, 1)
		return e
	}
	_, e := repositories.NewSimpleMasterRepository(r.table).Update(ctx, id, name, 1)
	return e
}
func h04Grant(t *testing.T, f usersFixture, r h04Resource, c, u int) {
	t.Helper()
	if e := f.db.Exec(`UPDATE sidebar_akses SET "create"=?,"update"=? WHERE group_id=1 AND sidebar_id=(SELECT id FROM sidebar WHERE sidebar_kode=?)`, c, u, r.code).Error; e != nil {
		t.Fatal(e)
	}
}

// Fingerprint every actual table (including security/audit metadata), plus every
// sequence. Denials and no-op retries must not leave even timestamp side effects.
func h04Snapshot(t *testing.T, f usersFixture) string {
	t.Helper()
	var names []string
	if e := f.db.Raw("SELECT tablename FROM pg_tables WHERE schemaname=current_schema() ORDER BY tablename").Scan(&names).Error; e != nil {
		t.Fatal(e)
	}
	var data strings.Builder
	for _, name := range names {
		var value string
		if e := f.db.Raw(`SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb)::text FROM (SELECT to_jsonb(t) v FROM "` + name + `" t) x`).Scan(&value).Error; e != nil {
			t.Fatal(e)
		}
		fmt.Fprintln(&data, name, value)
	}
	var seq string
	if e := f.db.Raw("SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY sequencename),'[]'::jsonb)::text FROM pg_sequences s WHERE schemaname=current_schema()").Scan(&seq).Error; e != nil {
		t.Fatal(e)
	}
	fmt.Fprintln(&data, seq)
	return fmt.Sprintf("%x", sha256.Sum256([]byte(data.String())))
}
func h04Denied(t *testing.T, f usersFixture, status int, fn func() error) {
	t.Helper()
	before := h04Snapshot(t, f)
	e := fn()
	var denial *repositories.MutationAccessError
	if !errors.As(e, &denial) || denial.Status != status {
		t.Fatalf("expected denial %d, got %v", status, e)
	}
	if h04Snapshot(t, f) != before {
		t.Fatal("denial changed rows, audit or sequences")
	}
}
func h04HTTPUnchanged(t *testing.T, f usersFixture, method, path string, id uint, body any, want int) {
	t.Helper()
	before := h04Snapshot(t, f)
	f.req(t, method, path, id, body, want)
	if h04Snapshot(t, f) != before {
		t.Fatal("HTTP denial/retry changed persisted state")
	}
}

func TestH04RepositoryActionBoundary(t *testing.T) {
	if repositories.MasterMutationAdminLock != services.AdminLock {
		t.Fatal("administration lock namespace drift")
	}
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			ctx := h04Context()
			if e := r.upsert(ctx, h04UUID, "Original"); e != nil {
				t.Fatal(e)
			}
			for _, call := range []func() error{
				func() error { return r.create(context.Background(), "Anonymous") },
				func() error { return r.update(context.Background(), 1, "Anonymous") },
				func() error { return r.upsert(context.Background(), h04UUID, "Anonymous") },
			} {
				h04Denied(t, f, 401, call)
			}
			for _, a := range []repositories.MutationActor{
				{}, {UserID: 2, GroupID: 1, ExpiresAt: time.Now().Add(time.Hour)},
				{UserID: 1, GroupID: 2, ExpiresAt: time.Now().Add(time.Hour)},
				{UserID: 1, GroupID: 1, ExpiresAt: time.Now().Add(-time.Second)},
				{UserID: 1, GroupID: 1, ExpiresAt: time.Now().Add(time.Hour), SecurityRequired: true},
			} {
				h04Denied(t, f, 401, func() error {
					return r.upsert(repositories.WithMutationActor(context.Background(), a), h04UUID, "Bad session")
				})
			}
			h04Grant(t, f, r, 1, 0)
			h04Denied(t, f, 403, func() error { return r.upsert(ctx, h04UUID, "Changed via CREATE") })
			h04Denied(t, f, 403, func() error { return r.update(ctx, 1, "Changed via UPDATE") })
			before := h04Snapshot(t, f)
			if e := r.upsert(ctx, strings.ToUpper(h04UUID), "Original"); e != nil {
				t.Fatal(e)
			}
			if h04Snapshot(t, f) != before {
				t.Fatal("initial CREATE retry modified metadata")
			}
			h04Grant(t, f, r, 0, 1)
			h04Denied(t, f, 403, func() error { return r.upsert(ctx, h04OtherUUID, "INSERT via UPDATE") })
			h04Denied(t, f, 403, func() error { return r.create(ctx, "INSERT via CREATE") })
			if e := r.update(ctx, 99999, "Missing"); !errors.Is(e, gorm.ErrRecordNotFound) {
				t.Fatalf("strict UPDATE inserted or failed incorrectly: %v", e)
			}
			if e := r.upsert(ctx, h04UUID, "Valid update"); e != nil {
				t.Fatal(e)
			}
			before = h04Snapshot(t, f)
			if e := r.upsert(ctx, h04UUID, "Valid update"); e != nil {
				t.Fatal(e)
			}
			if h04Snapshot(t, f) != before {
				t.Fatal("UPDATE retry modified metadata")
			}
			h04Grant(t, f, r, 0, 0)
			for _, uuid := range []string{h04UUID, h04OtherUUID} {
				h04Denied(t, f, 403, func() error { return r.upsert(ctx, uuid, "READ is not CUD") })
			}
			if e := f.db.Exec("UPDATE users SET security_version=2 WHERE id=1").Error; e != nil {
				t.Fatal(e)
			}
			h04Denied(t, f, 401, func() error { return r.upsert(ctx, h04UUID, "Revoked session") })
		})
	}
}

func TestH04HTTPActionBoundary(t *testing.T) {
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			body := map[string]any{"nama": "Published locally"}
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 0, body, 401)
			// Superadmin label with NO canonical grants has no mutation rights.
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 4, body, 403)
			h04Grant(t, f, r, 1, 0)
			created := f.req(t, "PUT", r.path+"/sync/"+h04UUID, 1, body, 200)["data"].(map[string]any)
			id := uint64(created["id"].(float64))
			strict := fmt.Sprintf("%s/%d", r.path, id)
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, body, 200)
			changed := map[string]any{"nama": "Changed"}
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, changed, 403)
			h04HTTPUnchanged(t, f, "PUT", strict, 1, changed, 403)
			if r.table != "pemohon" {
				h04HTTPUnchanged(t, f, "POST", r.path, 1, map[string]any{"uuid": h04UUID, "nama": "Changed"}, 409)
				h04HTTPUnchanged(t, f, "POST", r.path, 1, map[string]any{"uuid": h04UUID, "nama": "Published locally"}, 201)
			}
			h04Grant(t, f, r, 0, 1)
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04OtherUUID, 1, changed, 403)
			h04HTTPUnchanged(t, f, "PUT", r.path+"/99999", 1, changed, 404)
			f.req(t, "PUT", strict, 1, changed, 200)
			h04Grant(t, f, r, 0, 0)
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, changed, 403)
			h04HTTPUnchanged(t, f, "POST", r.path, 1, body, 403)
			// Canonical grants from another module or alias must not authorize this one.
			if e := f.db.Exec("UPDATE sidebar SET sidebar_kode='wrong_alias' WHERE sidebar_kode=?", r.code).Error; e != nil {
				t.Fatal(e)
			}
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, body, 403)
		})
	}
}

func TestH04ConcurrentUUID(t *testing.T) {
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			h04Grant(t, f, r, 1, 0)
			start := make(chan struct{})
			out := make(chan error, 2)
			var wg sync.WaitGroup
			for i := 0; i < 2; i++ {
				wg.Add(1)
				go func() { defer wg.Done(); <-start; out <- r.upsert(h04Context(), h04UUID, "Same creation") }()
			}
			close(start)
			wg.Wait()
			close(out)
			for e := range out {
				if e != nil {
					t.Fatal(e)
				}
			}
			var count int64
			f.db.Table(r.table).Count(&count)
			if count != 1 {
				t.Fatal("duplicate UUID created")
			}
			start = make(chan struct{})
			out = make(chan error, 2)
			for i := 0; i < 2; i++ {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					<-start
					out <- r.upsert(h04Context(), h04OtherUUID, fmt.Sprintf("Conflicting creation %d", i))
				}(i)
			}
			close(start)
			wg.Wait()
			close(out)
			ok, denied := 0, 0
			for e := range out {
				var a *repositories.MutationAccessError
				if e == nil {
					ok++
				} else if errors.As(e, &a) && a.Status == 403 {
					denied++
				} else {
					t.Fatal(e)
				}
			}
			if ok != 1 || denied != 1 {
				t.Fatalf("create race: %d success %d denied", ok, denied)
			}
			h04Grant(t, f, r, 0, 1)
			start = make(chan struct{})
			out = make(chan error, 2)
			for i := 0; i < 2; i++ {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					<-start
					out <- r.upsert(h04Context(), h04UUID, fmt.Sprintf("Authorized update %d", i))
				}(i)
			}
			close(start)
			wg.Wait()
			close(out)
			for e := range out {
				if e != nil {
					t.Fatal(e)
				}
			} // Legacy upsert serializes updates; it has no revision wire field.
			f.db.Table(r.table).Count(&count)
			if count != 2 {
				t.Fatal("update race inserted rows")
			}
		})
	}
}

func TestH04PermissionRevokeBeforeMutation(t *testing.T) {
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			tx := f.db.Begin()
			defer tx.Rollback()
			if e := tx.Exec("SELECT pg_advisory_xact_lock(?)", services.AdminLock).Error; e != nil {
				t.Fatal(e)
			}
			result := make(chan error, 1)
			go func() { result <- r.upsert(h04Context(), h04UUID, "Must be denied after revocation") }()
			deadline := time.Now().Add(5 * time.Second)
			for {
				var blocked int64
				if e := tx.Raw("SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND NOT granted AND mode='ShareLock'").Scan(&blocked).Error; e != nil {
					t.Fatal(e)
				}
				if blocked > 0 {
					break
				}
				if time.Now().After(deadline) {
					t.Fatal("mutation did not wait on administration lock")
				}
				time.Sleep(time.Millisecond * 10)
			}
			if e := tx.Exec(`UPDATE sidebar_akses SET "create"=0,"update"=0 WHERE group_id=1 AND sidebar_id=(SELECT id FROM sidebar WHERE sidebar_kode=?)`, r.code).Error; e != nil {
				t.Fatal(e)
			}
			if e := tx.Commit().Error; e != nil {
				t.Fatal(e)
			}
			h04Denied(t, f, 403, func() error { return <-result })
		})
	}
}

// Real authenticated HTTP with the exact unmodified Dart publisher payloads.
func TestH04SelectivePublisherHTTPCompatibility(t *testing.T) {
	f := h04Setup(t)
	server := httptest.NewServer(f.api)
	defer server.Close()
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			var id any
			for _, name := range []string{"Publisher create", "Publisher create", "Publisher update", "Publisher update"} {
				body := map[string]any{"nama": name}
				if r.table == "pemohon" {
					body["alamat"] = nil
					body["jenis_kelamin_nama"] = "Laki-laki"
					body["no_telp"] = nil
					body["nik"] = "1234567890123456"
				}
				raw, _ := json.Marshal(body)
				req, _ := http.NewRequest("PUT", server.URL+"/api/v1"+r.path+"/sync/"+h04UUID, bytes.NewReader(raw))
				req.Header.Set("Content-Type", "application/json")
				req.Header.Set("Authorization", "Bearer "+f.token(1, nil))
				res, e := http.DefaultClient.Do(req)
				if e != nil {
					t.Fatal(e)
				}
				var data map[string]any
				e = json.NewDecoder(res.Body).Decode(&data)
				res.Body.Close()
				if e != nil || res.StatusCode != 200 || data["success"] != true {
					t.Fatalf("publisher contract failed: HTTP %d %v", res.StatusCode, e)
				}
				record := data["data"].(map[string]any)
				if id != nil && id != record["id"] {
					t.Fatal("publisher ACK identity changed")
				}
				id = record["id"]
				if record["uuid"] != h04UUID || record["nama"] != name {
					t.Fatal("ACK payload mismatch")
				}
			}
		})
	}
}

func TestH04InvalidHTTPSession(t *testing.T) {
	f := h04Setup(t)
	for _, change := range []func(jwt.MapClaims){
		func(c jwt.MapClaims) { delete(c, "sv") }, func(c jwt.MapClaims) { c["sv"] = 99 }, func(c jwt.MapClaims) { c["gid"] = 2 },
		func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }, func(c jwt.MapClaims) { c["uid"] = "invalid" },
	} {
		before := h04Snapshot(t, f)
		req := httptest.NewRequest("PUT", "/api/v1/pemohon/sync/"+h04UUID, strings.NewReader(`{"nama":"Denied"}`))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+f.token(1, change))
		w := httptest.NewRecorder()
		f.api.ServeHTTP(w, req)
		if w.Code != 401 {
			t.Fatalf("invalid session status %d", w.Code)
		}
		if before != h04Snapshot(t, f) {
			t.Fatal("invalid authentication mutated database")
		}
	}
}

func TestH04StrictCRUDAndConflicts(t *testing.T) {
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			body := map[string]any{"nama": "Strict create"}
			if r.table == "pemohon" {
				body["nik"] = "1234567890123456"
				body["jenis_kelamin"] = 1
				body["alamat"] = "Alamat"
				body["no_telp"] = "081234567890"
			}
			data := f.req(t, "POST", r.path, 1, body, 201)["data"].(map[string]any)
			id := uint64(data["id"].(float64))
			uuid := data["uuid"].(string)
			h04HTTPUnchanged(t, f, "POST", r.path, 1, body, 409)
			if r.table != "pemohon" {
				// Even CREATE+UPDATE permission cannot turn POST into UPDATE.
				h04HTTPUnchanged(t, f, "POST", r.path, 1, map[string]any{"uuid": uuid, "nama": "POST changed"}, 409)
			}
			body["nama"] = "Strict update"
			updated := f.req(t, "PUT", fmt.Sprintf("%s/%d", r.path, id), 1, body, 200)["data"].(map[string]any)
			if updated["uuid"] != uuid || updated["nama"] != "Strict update" {
				t.Fatal("strict update changed identity or lost payload")
			}
			if r.table == "pemohon" && (updated["nik"] != body["nik"] || updated["jenis_kelamin_nama"] != "Laki-laki" || updated["alamat"] != "Alamat") {
				t.Fatal("Pemohon references or optional fields changed")
			}
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04OtherUUID, 1, body, 409)
			// Deleted UUIDs are never resurrected by a permitted publisher retry.
			f.req(t, "DELETE", r.path+"/sync/"+uuid, 1, nil, 200)
			status := 409
			if r.table == "pemohon" {
				status = 404
			}
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+uuid, 1, body, status)
		})
	}
}

func TestH04CanonicalGrantFailures(t *testing.T) {
	for _, r := range h04Resources {
		for _, kind := range []string{"missing", "duplicate", "inactive-sidebar", "inactive-group", "inactive-user"} {
			t.Run(r.code+"/"+kind, func(t *testing.T) {
				f := h04Setup(t)
				status := 403
				var e error
				switch kind {
				case "missing":
					e = f.db.Exec("DELETE FROM sidebar_akses WHERE sidebar_id=(SELECT id FROM sidebar WHERE sidebar_kode=?)", r.code).Error
				case "duplicate":
					// Fault-inject a pre-P0/legacy ambiguous grant only in this owned
					// disposable schema; normal P0 uniqueness stays unchanged.
					if err := f.db.Exec("DROP INDEX sidebar_group_grant_unique").Error; err != nil {
						t.Fatal(err)
					}
					e = f.db.Exec(`INSERT INTO sidebar_akses(group_id,sidebar_id,"read","create","update","delete") SELECT group_id,sidebar_id,1,1,1,1 FROM sidebar_akses WHERE group_id=1 AND sidebar_id=(SELECT id FROM sidebar WHERE sidebar_kode=?)`, r.code).Error
				case "inactive-sidebar":
					e = f.db.Exec("UPDATE sidebar SET status=0 WHERE sidebar_kode=?", r.code).Error
				case "inactive-group":
					e = f.db.Exec("UPDATE groups SET status=0 WHERE id=1").Error
				case "inactive-user":
					e = f.db.Exec("UPDATE users SET status=0 WHERE id=1").Error
					status = 401
				}
				if e != nil {
					t.Fatal(e)
				}
				h04Denied(t, f, status, func() error { return r.upsert(h04Context(), h04UUID, "No canonical authority") })
				httpStatus := status
				if kind == "inactive-group" {
					httpStatus = 401
				} // JWT P0 rejects the session before the action boundary.
				h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, map[string]any{"nama": "Denied"}, httpStatus)
			})
		}
	}
}

func TestH04RetryIsActorBound(t *testing.T) {
	for _, r := range h04Resources {
		t.Run(r.code, func(t *testing.T) {
			f := h04Setup(t)
			body := map[string]any{"nama": "Other creator"}
			f.req(t, "PUT", r.path+"/sync/"+h04UUID, 2, body, 200)
			h04Grant(t, f, r, 1, 0)
			h04HTTPUnchanged(t, f, "PUT", r.path+"/sync/"+h04UUID, 1, body, 403)
			h04Denied(t, f, 403, func() error { return r.upsert(h04Context(), h04UUID, "Other creator") })
		})
	}
}
