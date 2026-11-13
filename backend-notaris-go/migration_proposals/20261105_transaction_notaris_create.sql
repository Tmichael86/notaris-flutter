-- Proposal: disposable tests only until separately approved for a deployment.
-- Apply transaction_cloud_numbering proposal first, in the same rollout tx.
CREATE TABLE transaction_cloud (
 id bigserial PRIMARY KEY, uuid uuid NOT NULL UNIQUE,
 final_number text NOT NULL UNIQUE, revision bigint NOT NULL CHECK(revision=1),
 pemohon_id bigint NOT NULL REFERENCES pemohon(id),
 petugas_id bigint NOT NULL REFERENCES petugas(id),
 header jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE transaction_cloud_detail (
 uuid uuid PRIMARY KEY, transaction_id bigint NOT NULL REFERENCES transaction_cloud(id),
 pekerjaan_notaris_id bigint NOT NULL REFERENCES pekerjaan_notaris(id),
 harga_id bigint NOT NULL REFERENCES pekerjaan_notaris_harga(id),
 kategori_id bigint NOT NULL REFERENCES pekerjaan_kategori(id), snapshot jsonb NOT NULL
);
CREATE TABLE transaction_cloud_process (
 uuid uuid PRIMARY KEY, detail_uuid uuid NOT NULL REFERENCES transaction_cloud_detail(uuid), snapshot jsonb NOT NULL
);
CREATE TABLE transaction_cloud_payment (
 uuid uuid PRIMARY KEY, transaction_id bigint NOT NULL REFERENCES transaction_cloud(id),
 nominal numeric NOT NULL CHECK(nominal>0), snapshot jsonb NOT NULL
);
CREATE TABLE transaction_cloud_mutation (
 mutation_id uuid PRIMARY KEY, actor_id bigint NOT NULL REFERENCES users(id),
 request_hash text NOT NULL, acknowledgement jsonb NOT NULL
);
CREATE TABLE transaction_cloud_publication (
 id smallint PRIMARY KEY CHECK(id=1), last_seq bigint NOT NULL DEFAULT 0, min_cursor bigint NOT NULL DEFAULT 0,
 CHECK(last_seq>=min_cursor AND min_cursor>=0)
);
INSERT INTO transaction_cloud_publication(id) VALUES(1);
CREATE TABLE transaction_cloud_outbox (
 id bigserial PRIMARY KEY, aggregate_uuid uuid NOT NULL UNIQUE REFERENCES transaction_cloud(uuid),
 payload jsonb NOT NULL, publication_seq bigint UNIQUE, published_at timestamptz,
 CHECK((publication_seq IS NULL)=(published_at IS NULL))
);
