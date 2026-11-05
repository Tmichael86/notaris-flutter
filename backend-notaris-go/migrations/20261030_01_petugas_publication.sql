-- Apply after 20261029_01. No automatic application at startup.
-- Bootstrap under an outbox lock so an existing publication is never reused.
BEGIN;
LOCK TABLE petugas_sync_outbox IN SHARE ROW EXCLUSIVE MODE;
CREATE TABLE IF NOT EXISTS petugas_sync_publication (
    id smallint PRIMARY KEY CHECK (id = 1),
    last_seq bigint NOT NULL CHECK (last_seq >= 0),
    min_cursor bigint NOT NULL DEFAULT 0 CHECK (min_cursor >= 0 AND min_cursor <= last_seq)
);
INSERT INTO petugas_sync_publication (id, last_seq)
SELECT 1, COALESCE(MAX(publication_seq), 0) FROM petugas_sync_outbox
ON CONFLICT (id) DO NOTHING;
COMMIT;
