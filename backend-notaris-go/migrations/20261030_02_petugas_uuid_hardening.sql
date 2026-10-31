-- Run after the identity and publication migrations, before deploying the new
-- legacy writer. The original identity migration has only been exercised on
-- disposable test schemas in the known rollout history. For installations that
-- already applied its earlier revision, this corrective migration preserves
-- EVERY assigned UUID (including old hashes); never remap referenced identities.
-- PostgreSQL 13+ is required for core gen_random_uuid().
BEGIN;
LOCK TABLE petugas IN SHARE ROW EXCLUSIVE MODE;
UPDATE petugas SET uuid = gen_random_uuid() WHERE uuid IS NULL;
ALTER TABLE petugas ALTER COLUMN uuid SET DEFAULT gen_random_uuid();
ALTER TABLE petugas ALTER COLUMN uuid SET NOT NULL;
-- Older legacy writers could insert row_version=0 explicitly. Normalize these
-- pre-activation records; positive versions and existing IDs remain untouched.
UPDATE petugas SET row_version = 1 WHERE row_version < 1;
CREATE UNIQUE INDEX IF NOT EXISTS petugas_uuid_unique ON petugas(uuid);
COMMIT;
