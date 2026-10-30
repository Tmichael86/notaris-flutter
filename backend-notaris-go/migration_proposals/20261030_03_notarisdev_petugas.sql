-- PROPOSAL ONLY. Not part of migrations/, never run by startup.
-- Requires sanitized notarisdev, reviewed schema compatibility and owner approval.
-- Run only with psql; default execution refuses changes.
\set ON_ERROR_STOP on
\if :{?NOTARIS_DEV_REVIEWED}
\else
  \echo 'BLOCKED: sanitization and migration review required'
  DO $$ BEGIN RAISE EXCEPTION 'Sanitization and migration review required'; END $$;
  \quit
\endif
\if :NOTARIS_DEV_REVIEWED
\else
  DO $$ BEGIN RAISE EXCEPTION 'Migration review not approved'; END $$;
  \quit
\endif
-- Session-scoped: included files COMMIT, so SET LOCAL would not protect phase 2/3.
SET search_path=public,pg_catalog;
SET lock_timeout='5s';
SET statement_timeout='60s';
BEGIN;
DO $$
BEGIN
  IF current_database() <> 'notarisdev' THEN
    RAISE EXCEPTION 'Only notarisdev may be migrated';
  END IF;
  -- First-install proposal only. Partial installations need phase-aware recovery,
  -- not blind IF NOT EXISTS replay over unknown object definitions.
  IF to_regclass('public.petugas_sync_mutations') IS NOT NULL OR
     to_regclass('public.petugas_sync_outbox') IS NOT NULL OR
     to_regclass('public.petugas_sync_publication') IS NOT NULL THEN
    RAISE EXCEPTION 'Existing sync foundation: inspect definitions and recover by phase';
  END IF;
  IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='petugas' AND column_name='id' AND data_type='bigint') THEN
    RAISE EXCEPTION 'Unexpected Petugas primary-key type';
  END IF;
  IF EXISTS (SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='petugas' AND
    ((column_name='uuid' AND data_type<>'uuid') OR
     (column_name='row_version' AND (data_type<>'bigint' OR is_nullable<>'NO')) OR
     (column_name='deleted_at' AND data_type<>'timestamp with time zone'))) THEN
    RAISE EXCEPTION 'Existing sync column definitions require review';
  END IF;
  IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='petugas' AND column_name='jenis_kelamin' AND data_type='integer') THEN
    RAISE EXCEPTION 'Unexpected gender schema; manual review required';
  END IF;
  IF EXISTS (SELECT FROM public.petugas p WHERE p.jenis_kelamin IS NOT NULL AND NOT EXISTS (SELECT FROM public.jenis_kelamin j WHERE j.id=p.jenis_kelamin))
     OR EXISTS (SELECT FROM public.petugas p WHERE p.user_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.users u WHERE u.id=p.user_id)) THEN
    RAISE EXCEPTION 'Unresolved server references';
  END IF;
END $$;
-- Writers/clients/publisher must remain stopped across ALL three phases. This
-- table lock protects phase 1 only; it is not a deployment-wide maintenance gate.
LOCK TABLE public.petugas IN SHARE ROW EXCLUSIVE MODE;
-- First existing migration has no transaction boundaries; wrap it explicitly.
\ir ../migrations/20261029_01_petugas_cloud_sync.sql
COMMIT;
-- These files manage their own transactions. If interrupted, review receipts /
-- actual object definitions before re-running; IF NOT EXISTS is NOT validation.
\ir ../migrations/20261030_01_petugas_publication.sql
\ir ../migrations/20261030_02_petugas_uuid_hardening.sql
RESET search_path;
RESET lock_timeout;
RESET statement_timeout;
-- No bootstrap/publication/client activation here. Review separately.
-- Rollback strategy: disable clients/writers, retain UUIDs, outbox and receipts.
-- Do NOT drop columns, reset publication counters or rewrite existing identities.
