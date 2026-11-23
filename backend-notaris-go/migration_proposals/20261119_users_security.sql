-- Proposal only. Apply once in an explicitly approved transaction.
-- Users security cutover remains OFF until this proposal and prerequisite review pass.
SELECT pg_advisory_xact_lock(71920261119);
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM users GROUP BY lower(btrim(username)) HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM users GROUP BY lower(btrim(email)) HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM users WHERE username IS NULL OR btrim(username)='' OR email IS NULL OR btrim(email)='')
 OR EXISTS(SELECT 1 FROM sidebar_akses GROUP BY group_id,sidebar_id HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM sidebar GROUP BY sidebar_kode HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM sidebar WHERE sidebar_kode IS NULL OR btrim(sidebar_kode)='')
 OR EXISTS(SELECT 1 FROM users u JOIN users v ON lower(btrim(u.username))=lower(btrim(v.email)) AND u.id<>v.id)
 THEN RAISE EXCEPTION 'users_security_preflight_required'; END IF;
END $$;
ALTER TABLE users ADD COLUMN revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 ADD COLUMN security_version bigint NOT NULL DEFAULT 1 CHECK(security_version>0);
ALTER TABLE groups ADD COLUMN revision bigint NOT NULL DEFAULT 1 CHECK(revision>0);
CREATE UNIQUE INDEX users_username_normalized ON users(lower(btrim(username)));
CREATE UNIQUE INDEX users_email_normalized ON users(lower(btrim(email)));
CREATE UNIQUE INDEX sidebar_code_unique ON sidebar(sidebar_kode);
CREATE UNIQUE INDEX sidebar_group_grant_unique ON sidebar_akses(group_id,sidebar_id);
ALTER TABLE users ALTER COLUMN group_id SET NOT NULL,
 ALTER COLUMN username SET NOT NULL, ALTER COLUMN email SET NOT NULL,
 ADD CONSTRAINT users_security_identity_nonempty CHECK(btrim(username)<>'' AND btrim(email)<>'');
ALTER TABLE groups ADD CONSTRAINT groups_security_valid CHECK(status IS NOT NULL AND status IN(0,1)
 AND group_jenis IS NOT NULL AND group_jenis IN('user','superadmin'));
ALTER TABLE sidebar ALTER COLUMN sidebar_kode SET NOT NULL, ALTER COLUMN sidebar_route SET NOT NULL,
 ADD CONSTRAINT sidebar_security_valid CHECK(btrim(sidebar_kode)<>'' AND status IS NOT NULL AND status IN(0,1));
ALTER TABLE sidebar_akses ALTER COLUMN group_id SET NOT NULL, ALTER COLUMN sidebar_id SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_security_group_fk FOREIGN KEY(group_id) REFERENCES groups(id),
 ADD CONSTRAINT users_security_status CHECK(status IS NOT NULL AND status IN(0,1));
ALTER TABLE sidebar_akses ADD CONSTRAINT grants_security_group_fk FOREIGN KEY(group_id) REFERENCES groups(id),
 ADD CONSTRAINT grants_security_sidebar_fk FOREIGN KEY(sidebar_id) REFERENCES sidebar(id),
 ADD CONSTRAINT grants_security_flags CHECK(
 "read" IS NOT NULL AND "read" IN(0,1) AND "create" IS NOT NULL AND "create" IN(0,1)
 AND "update" IS NOT NULL AND "update" IN(0,1) AND "delete" IS NOT NULL AND "delete" IN(0,1));
CREATE TABLE administrative_audit(
 id bigserial PRIMARY KEY,
 actor_id bigint REFERENCES users(id), target_id bigint, target_type text NOT NULL,
 action text NOT NULL, occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 request_id uuid NOT NULL, result text NOT NULL CHECK(result IN('success','denied')),
 reason_code text, before_state jsonb, after_state jsonb,
 source text NOT NULL CHECK(source='online_admin_api')
);
CREATE INDEX administrative_audit_actor_time ON administrative_audit(actor_id,occurred_at);
CREATE FUNCTION deny_administrative_audit_rewrite() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'administrative_audit_append_only'; END $$;
CREATE TRIGGER administrative_audit_immutable BEFORE UPDATE OR DELETE OR TRUNCATE
 ON administrative_audit FOR EACH STATEMENT EXECUTE FUNCTION deny_administrative_audit_rewrite();
