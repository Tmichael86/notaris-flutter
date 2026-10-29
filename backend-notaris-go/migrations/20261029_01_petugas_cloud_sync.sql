-- Petugas Cloud Sync foundation.
--
-- This migration is intentionally additive and is not executed by application
-- startup. It targets the source schema documented in DATABASE_STRUCTURE.md;
-- the deployed PostgreSQL schema has not been inspected by this repository.

ALTER TABLE petugas ADD COLUMN IF NOT EXISTS uuid uuid;
ALTER TABLE petugas ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 1;
ALTER TABLE petugas ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Existing IDs remain untouched. The deterministic UUID is only a one-time
-- server identity for legacy rows; new sync-capable writes must provide UUIDs.
UPDATE petugas
SET uuid = md5('petugas:' || id::text)::uuid
WHERE uuid IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS petugas_uuid_unique
    ON petugas (uuid)
    WHERE uuid IS NOT NULL;

CREATE TABLE IF NOT EXISTS petugas_sync_mutations (
    mutation_id uuid PRIMARY KEY,
    petugas_uuid uuid NOT NULL,
    request_hash text NOT NULL,
    acknowledgement jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS petugas_sync_mutations_petugas_uuid_idx
    ON petugas_sync_mutations (petugas_uuid);

-- Outbox rows are inserted in the same transaction as the Petugas mutation.
-- publication_seq remains NULL until a publisher observes a committed outbox
-- row and allocates a sequence in its own committed transaction.
CREATE TABLE IF NOT EXISTS petugas_sync_outbox (
    id bigserial PRIMARY KEY,
    petugas_uuid uuid NOT NULL,
    row_version bigint NOT NULL,
    tombstone boolean NOT NULL,
    payload jsonb NOT NULL,
    publication_seq bigint UNIQUE,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS petugas_sync_outbox_unpublished_idx
    ON petugas_sync_outbox (id)
    WHERE publication_seq IS NULL;

CREATE INDEX IF NOT EXISTS petugas_sync_outbox_publication_idx
    ON petugas_sync_outbox (publication_seq)
    WHERE publication_seq IS NOT NULL;
