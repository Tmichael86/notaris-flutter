-- Additive proposal; apply only on disposable PostgreSQL until separately approved.
ALTER TABLE transaction_cloud DROP CONSTRAINT transaction_cloud_revision_check;
ALTER TABLE transaction_cloud ADD CHECK(revision>0), ADD COLUMN deleted_at timestamptz;
ALTER TABLE transaction_cloud_detail ADD COLUMN deleted_at timestamptz;
ALTER TABLE transaction_cloud_process ADD COLUMN deleted_at timestamptz;
ALTER TABLE transaction_cloud_outbox DROP CONSTRAINT transaction_cloud_outbox_aggregate_uuid_key;
ALTER TABLE transaction_cloud_outbox ADD COLUMN revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 ADD COLUMN operation text NOT NULL DEFAULT 'create' CHECK(operation IN ('create','update','delete')),
 ADD UNIQUE(aggregate_uuid,revision);
