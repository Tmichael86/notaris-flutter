package services

import (
	"fmt"
	"strings"
	"unicode"

	"gorm.io/gorm"
)

// This is a read-only contract for the approved P0 proposal, not a migrator.
// Compare definitions as well as names: a disabled index, NOT VALID FK or
// CHECK(true) with an expected name must not qualify a partial schema as ready.
func usersSecuritySchema(tx *gorm.DB) error {
	fail := func() error { return adminError(503, "security_schema_required") }
	tables := []string{"users", "groups", "sidebar", "sidebar_akses", "administrative_audit"}
	var tableCount int64
	if e := tx.Raw(`SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname=current_schema() AND c.relkind='r' AND c.relname IN ?`, tables).Scan(&tableCount).Error; e != nil || tableCount != 5 {
		return fail()
	}
	type column struct {
		TableName, Name, Type, DefaultValue string
		NotNull                             bool
	}
	var columns []column
	if e := tx.Raw(`SELECT c.relname AS table_name,a.attname AS name,format_type(a.atttypid,a.atttypmod) AS type,
 a.attnotnull AS not_null,coalesce(pg_get_expr(d.adbin,d.adrelid),'') AS default_value
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
 WHERE n.nspname=current_schema() AND c.relname IN ? AND a.attnum>0 AND NOT a.attisdropped`, tables).Scan(&columns).Error; e != nil {
		return fail()
	}
	byColumn := map[string]column{}
	for _, c := range columns {
		byColumn[c.TableName+"."+c.Name] = c
	}
	for _, key := range []string{"users.revision", "users.security_version", "groups.revision"} {
		c, ok := byColumn[key]
		if !ok || c.Type != "bigint" || !c.NotNull || schemaSQL(c.DefaultValue) != "1" {
			return fail()
		}
	}
	for _, key := range []string{"users.group_id", "users.username", "users.email", "sidebar.sidebar_kode", "sidebar.sidebar_route", "sidebar_akses.group_id", "sidebar_akses.sidebar_id"} {
		c, ok := byColumn[key]
		if !ok || !c.NotNull {
			return fail()
		}
	}
	for name, kind := range map[string]string{"id": "bigint", "actor_id": "bigint", "target_id": "bigint", "target_type": "text", "action": "text", "occurred_at": "timestamp with time zone", "request_id": "uuid", "result": "text", "reason_code": "text", "before_state": "jsonb", "after_state": "jsonb", "source": "text"} {
		c, ok := byColumn["administrative_audit."+name]
		if !ok || c.Type != kind {
			return fail()
		}
		switch name {
		case "actor_id", "target_id", "reason_code", "before_state", "after_state":
		default:
			if !c.NotNull {
				return fail()
			}
		}
	}
	type constraint struct {
		TableName, Name, Definition, Kind string
		Validated, Deferrable             bool
	}
	var constraints []constraint
	if e := tx.Raw(`SELECT r.relname AS table_name,c.conname AS name,c.contype::text AS kind,
 pg_get_constraintdef(c.oid) AS definition,c.convalidated AS validated,c.condeferrable AS deferrable
 FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace
 WHERE n.nspname=current_schema() AND r.relname IN ?`, tables).Scan(&constraints).Error; e != nil {
		return fail()
	}
	byConstraint := map[string]constraint{}
	primary := map[string]bool{}
	for _, c := range constraints {
		byConstraint[c.TableName+"."+c.Name] = c
		if c.Kind == "p" && c.Validated && !c.Deferrable && schemaSQL(c.Definition) == schemaSQL("PRIMARY KEY (id)") {
			primary[c.TableName] = true
		}
	}
	for _, table := range tables {
		if !primary[table] {
			return fail()
		}
	}
	required := map[string]string{
		"users.users_revision_check":                              "CHECK ((revision > 0))",
		"users.users_security_version_check":                      "CHECK ((security_version > 0))",
		"groups.groups_revision_check":                            "CHECK ((revision > 0))",
		"users.users_security_identity_nonempty":                  "CHECK (((btrim(username) <> ''::text) AND (btrim(email) <> ''::text)))",
		"users.users_security_group_fk":                           "FOREIGN KEY (group_id) REFERENCES groups(id)",
		"users.users_security_status":                             "CHECK (((status IS NOT NULL) AND (status = ANY (ARRAY[0, 1]))))",
		"groups.groups_security_valid":                            "CHECK (((status IS NOT NULL) AND (status = ANY (ARRAY[0, 1])) AND (group_jenis IS NOT NULL) AND (group_jenis = ANY (ARRAY['user'::text, 'superadmin'::text]))))",
		"sidebar.sidebar_security_valid":                          "CHECK (((btrim(sidebar_kode) <> ''::text) AND (status IS NOT NULL) AND (status = ANY (ARRAY[0, 1]))))",
		"sidebar_akses.grants_security_group_fk":                  "FOREIGN KEY (group_id) REFERENCES groups(id)",
		"sidebar_akses.grants_security_sidebar_fk":                "FOREIGN KEY (sidebar_id) REFERENCES sidebar(id)",
		"sidebar_akses.grants_security_flags":                     `CHECK (((read IS NOT NULL) AND (read = ANY (ARRAY[0, 1])) AND ("create" IS NOT NULL) AND ("create" = ANY (ARRAY[0, 1])) AND (update IS NOT NULL) AND (update = ANY (ARRAY[0, 1])) AND (delete IS NOT NULL) AND (delete = ANY (ARRAY[0, 1]))))`,
		"administrative_audit.administrative_audit_actor_id_fkey": "FOREIGN KEY (actor_id) REFERENCES users(id)",
		"administrative_audit.administrative_audit_result_check":  "CHECK ((result = ANY (ARRAY['success'::text, 'denied'::text])))",
		"administrative_audit.administrative_audit_source_check":  "CHECK ((source = 'online_admin_api'::text))",
	}
	for key, expected := range required {
		c, ok := byConstraint[key]
		if !ok || !c.Validated || c.Deferrable || schemaSQL(c.Definition) != schemaSQL(expected) {
			return fmt.Errorf("%w: %s", fail(), key)
		}
	}
	type index struct {
		TableName, Name, Keys                           string
		Unique, Valid, Ready, Live, Immediate, Complete bool
	}
	var indexes []index
	if e := tx.Raw(`SELECT r.relname AS table_name,c.relname AS name,i.indisunique AS unique,i.indisvalid AS valid,
 i.indisready AS ready,i.indislive AS live,i.indimmediate AS immediate,
 (i.indpred IS NULL AND i.indnatts=i.indnkeyatts) AS complete,
 (SELECT string_agg(pg_get_indexdef(i.indexrelid,k,true),',' ORDER BY k) FROM generate_series(1,i.indnkeyatts) k) AS keys
 FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_class r ON r.oid=i.indrelid
 JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname=current_schema() AND r.relname IN ?`, tables).Scan(&indexes).Error; e != nil {
		return fail()
	}
	byIndex := map[string]index{}
	for _, i := range indexes {
		byIndex[i.TableName+"."+i.Name] = i
	}
	for key, keys := range map[string]string{
		"users.users_username_normalized": "lower(btrim(username))", "users.users_email_normalized": "lower(btrim(email))",
		"sidebar.sidebar_code_unique": "sidebar_kode", "sidebar_akses.sidebar_group_grant_unique": "group_id,sidebar_id",
		"administrative_audit.administrative_audit_actor_time": "actor_id,occurred_at",
	} {
		i, ok := byIndex[key]
		unique := !strings.HasPrefix(key, "administrative_audit.")
		if !ok || i.Unique != unique || !i.Valid || !i.Ready || !i.Live || !i.Immediate || !i.Complete || schemaSQL(i.Keys) != schemaSQL(keys) {
			return fmt.Errorf("%w: %s", fail(), key)
		}
	}
	var bodies []string
	if e := tx.Raw(`SELECT p.prosrc FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=r.relnamespace JOIN pg_proc p ON p.oid=t.tgfoid
 JOIN pg_namespace pn ON pn.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
 WHERE n.nspname=current_schema() AND pn.nspname=current_schema() AND r.relname='administrative_audit'
 AND t.tgname='administrative_audit_immutable' AND NOT t.tgisinternal AND t.tgtype=58 AND t.tgenabled IN ('O','A')
 AND p.proname='deny_administrative_audit_rewrite' AND p.pronargs=0 AND p.prorettype='trigger'::regtype
 AND l.lanname='plpgsql'`).Scan(&bodies).Error; e != nil || len(bodies) != 1 || schemaSQL(bodies[0]) != schemaSQL("BEGIN RAISE EXCEPTION 'administrative_audit_append_only'; END") {
		return fail()
	}
	return nil
}

// Ignore formatting outside quoted tokens only. Whitespace inside literals or
// identifiers is semantic and must never normalize a different CHECK to valid.
func schemaSQL(value string) string {
	var out strings.Builder
	var quote rune
	for _, r := range value {
		if quote != 0 {
			out.WriteRune(r)
			if r == quote {
				quote = 0
			}
			continue
		}
		if r == '\'' || r == '"' {
			quote = r
		}
		if !unicode.IsSpace(r) {
			out.WriteRune(r)
		}
	}
	return out.String()
}
