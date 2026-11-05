-- Shared input validation. All settings are session-only, not persistent objects.
\set ON_ERROR_STOP on
\if :{?NOTARIS_DEV_APP_ROLE}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Explicit app role required'; END $$;
\endif
\if :{?EXPECTED_PORT}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Explicit expected port required'; END $$;
\endif
\if :{?PETUGAS_HASH}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Verified original Petugas fingerprint required'; END $$;
\endif
\if :{?UUID_HASH}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Verified installed UUID fingerprint required'; END $$;
\endif
\if :{?TRANSACTION_HASH}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Verified transaction fingerprint required'; END $$;
\endif
\if :{?DETAIL_HASH}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Verified detail fingerprint required'; END $$;
\endif
\if :{?PAYMENT_HASH}
\else
 DO $$ BEGIN RAISE EXCEPTION 'Verified payment fingerprint required'; END $$;
\endif
SELECT set_config('notaris.review_app_role', :'NOTARIS_DEV_APP_ROLE', false),
 set_config('notaris.review_port', :'EXPECTED_PORT', false),
 set_config('notaris.petugas_hash', :'PETUGAS_HASH', false),
 set_config('notaris.uuid_hash', :'UUID_HASH', false),
 set_config('notaris.transaction_hash', :'TRANSACTION_HASH', false),
 set_config('notaris.detail_hash', :'DETAIL_HASH', false),
 set_config('notaris.payment_hash', :'PAYMENT_HASH', false);
