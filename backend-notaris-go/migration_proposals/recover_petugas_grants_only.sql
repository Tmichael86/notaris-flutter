-- REVIEWED RECOVERY ONLY. No identity/publication/hardening migration includes.
-- Must be separately authorized for permanent notarisdev. No implicit startup.
\set ON_ERROR_STOP on
\if :{?NOTARIS_DEV_GRANTS_APPROVED}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Separate grants-only approval required'; END $$;
\endif
\if :NOTARIS_DEV_GRANTS_APPROVED
\else
 DO $$ BEGIN RAISE EXCEPTION 'Grants-only approval not supplied'; END $$;
\endif
\ir petugas_grants_context.sql
SET search_path=public,pg_catalog;
SET lock_timeout='5s';
SET statement_timeout='60s';
BEGIN;
\ir petugas_grants_target_guard.sql
-- Protect validation and grants from concurrent row/DDL changes. Backend/clients
-- must still remain stopped: these locks are not an external maintenance fence.
LOCK TABLE public.petugas_sync_mutations, public.petugas_sync_outbox,
 public.petugas_sync_publication IN SHARE MODE;
-- Existing business tables need only SELECT privileges, not DDL/write access.
-- ACCESS SHARE protects their definitions; the maintenance gate keeps writers off.
LOCK TABLE public.petugas, public.transaksi, public.transaksi_detail_proses,
 public.transaksi_riwayat_pembayaran IN ACCESS SHARE MODE;
\ir petugas_grants_existing_guard.sql
SELECT format('GRANT SELECT,INSERT ON public.petugas_sync_mutations TO %I', :'NOTARIS_DEV_APP_ROLE') \gexec
SELECT format('GRANT SELECT,INSERT,UPDATE ON public.petugas_sync_outbox TO %I', :'NOTARIS_DEV_APP_ROLE') \gexec
SELECT format('GRANT SELECT,UPDATE ON public.petugas_sync_publication TO %I', :'NOTARIS_DEV_APP_ROLE') \gexec
SELECT format('GRANT USAGE,SELECT ON SEQUENCE public.petugas_sync_outbox_id_seq TO %I', :'NOTARIS_DEV_APP_ROLE') \gexec
COMMIT;
\echo PETUGAS_GRANTS_ONLY_COMMITTED
