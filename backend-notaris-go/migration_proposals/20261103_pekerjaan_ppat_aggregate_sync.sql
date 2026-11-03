-- Disposable-only proposal. Never run automatically or on permanent notarisdev.
BEGIN;
ALTER TABLE pekerjaan_ppat ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 1;
ALTER TABLE pekerjaan_ppat ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE pekerjaan_ppat_harga ADD COLUMN IF NOT EXISTS uuid uuid;
ALTER TABLE pekerjaan_ppat_proses ADD COLUMN IF NOT EXISTS uuid uuid;
UPDATE pekerjaan_ppat_harga SET uuid=gen_random_uuid() WHERE uuid IS NULL;
UPDATE pekerjaan_ppat_proses SET uuid=gen_random_uuid() WHERE uuid IS NULL;
ALTER TABLE pekerjaan_ppat_harga ALTER COLUMN uuid SET NOT NULL;
ALTER TABLE pekerjaan_ppat_proses ALTER COLUMN uuid SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_ppat_harga_sync_uuid ON pekerjaan_ppat_harga(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_ppat_proses_sync_uuid ON pekerjaan_ppat_proses(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_ppat_sync_uuid ON pekerjaan_ppat(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS pekerjaan_kategori_sync_uuid ON pekerjaan_kategori(uuid);
CREATE TABLE IF NOT EXISTS pekerjaan_ppat_sync_atribut (
  id bigserial PRIMARY KEY, uuid uuid NOT NULL UNIQUE,
  proses_uuid uuid NOT NULL REFERENCES pekerjaan_ppat_proses(uuid),
  atribut text NOT NULL, status smallint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS pekerjaan_ppat_sync_mutation (
  mutation_id uuid PRIMARY KEY, actor_id bigint NOT NULL,
  request_hash text NOT NULL, acknowledgement jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS pekerjaan_ppat_sync_outbox (
  id bigserial PRIMARY KEY, aggregate_uuid uuid NOT NULL,
  payload jsonb NOT NULL, revision bigint NOT NULL DEFAULT 1,
  operation text NOT NULL DEFAULT 'create' CHECK(operation IN ('create','update','delete')),
  publication_seq bigint UNIQUE,
  published_at timestamptz
);
CREATE INDEX IF NOT EXISTS pekerjaan_ppat_sync_pending
  ON pekerjaan_ppat_sync_outbox(id) WHERE publication_seq IS NULL;
CREATE TABLE IF NOT EXISTS pekerjaan_ppat_sync_publication (
  id smallint PRIMARY KEY CHECK(id=1),
  last_seq bigint NOT NULL DEFAULT 0 CHECK(last_seq>=0),
  min_cursor bigint NOT NULL DEFAULT 0 CHECK(min_cursor>=0 AND min_cursor<=last_seq)
);
INSERT INTO pekerjaan_ppat_sync_publication(id) VALUES(1) ON CONFLICT DO NOTHING;
COMMIT;
