-- Read-only installed-schema validation; does not use the first-install runner.
\ir petugas_grants_context.sql
SET search_path=public,pg_catalog;
SET lock_timeout='5s';
SET statement_timeout='60s';
BEGIN READ ONLY;
\ir petugas_grants_target_guard.sql
\ir petugas_grants_existing_guard.sql
ROLLBACK;
\echo PETUGAS_EXISTING_VERIFIED
