-- Disposable-only proposal. Never run automatically or on permanent notarisdev.
BEGIN;
ALTER TABLE pekerjaan_notaris ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 1;
ALTER TABLE pekerjaan_notaris ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE pekerjaan_notaris_harga ADD COLUMN IF NOT EXISTS uuid uuid;
ALTER TABLE pekerjaan_notaris_proses ADD COLUMN IF NOT EXISTS uuid uuid;
UPDATE pekerjaan_notaris_harga SET uuid=gen_random_uuid() WHERE uuid IS NULL;
UPDATE pekerjaan_notaris_proses SET uuid=gen_random_uuid() WHERE uuid IS NULL;
ALTER TABLE pekerjaan_notaris_harga ALTER COLUMN uuid SET NOT NULL;
ALTER TABLE pekerjaan_notaris_proses ALTER COLUMN uuid SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_notaris_harga_sync_uuid ON pekerjaan_notaris_harga(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_notaris_proses_sync_uuid ON pekerjaan_notaris_proses(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_notaris_sync_uuid ON pekerjaan_notaris(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_kategori_sync_uuid ON pekerjaan_kategori(uuid);
CREATE TABLE IF NOT EXISTS pekerjaan_notaris_sync_atribut (
  id bigserial PRIMARY KEY, uuid uuid NOT NULL UNIQUE,
  proses_uuid uuid NOT NULL REFERENCES pekerjaan_notaris_proses(uuid),
  atribut text NOT NULL, status smallint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS pekerjaan_notaris_sync_mutation (
  mutation_id uuid PRIMARY KEY, actor_id bigint NOT NULL,
  request_hash text NOT NULL, acknowledgement jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS pekerjaan_notaris_sync_outbox (
  id bigserial PRIMARY KEY, aggregate_uuid uuid NOT NULL,
  payload jsonb NOT NULL, revision bigint NOT NULL DEFAULT 1,
  operation text NOT NULL DEFAULT 'create' CHECK(operation IN ('create','update','delete')),
  publication_seq bigint UNIQUE,
  published_at timestamptz
);
CREATE INDEX IF NOT EXISTS pekerjaan_notaris_sync_pending
  ON pekerjaan_notaris_sync_outbox(id) WHERE publication_seq IS NULL;
CREATE TABLE IF NOT EXISTS pekerjaan_notaris_sync_publication (
  id smallint PRIMARY KEY CHECK(id=1),
  last_seq bigint NOT NULL DEFAULT 0 CHECK(last_seq>=0),
  min_cursor bigint NOT NULL DEFAULT 0 CHECK(min_cursor>=0 AND min_cursor<=last_seq)
);
INSERT INTO pekerjaan_notaris_sync_publication(id) VALUES(1) ON CONFLICT DO NOTHING;
COMMIT;
