# Petugas publication runtime

The service worker calls the existing transactional publisher repository. The
singleton database counter still serializes every publication through commit,
including across backend processes. The worker allocates no cursor and deletes
no events. It attempts one batch immediately, then waits after every batch,
including full/empty batches. Failures retry with exponential backoff capped at
the configured maximum; success resets the delay. Attempts have a context deadline.
Logs contain only published counts and retry delay, never raw database errors,
payloads, UUIDs or connection strings. An error may mean missing migrations or
permissions as well as a temporary outage; inspect readiness/configuration via
the operator workflow, not by dumping data into public logs.

Environment configuration (existing .env loading applies):

| Variable | Default | Meaning |
| --- | --- | --- |
| PETUGAS_PUBLISHER_ENABLED | false | Explicit opt-in at backend startup |
| PETUGAS_PUBLISHER_BATCH | 100 | Events per transaction, 1..500 |
| PETUGAS_PUBLISHER_INTERVAL | 1s | Minimum delay between successful batches/retry base |
| PETUGAS_PUBLISHER_TIMEOUT | 10s | Deadline per publication transaction |
| PETUGAS_PUBLISHER_MAX_BACKOFF | 30s | Retry cap, at least the interval |

Invalid enabled worker settings fail startup. Disable by setting ENABLED=false
and restarting the backend. Durations use Go syntax (e.g. 500ms, 5s). Interval
must be at least 1ms; use the defaults initially. No global environment or
system configuration is modified by this implementation.

SIGINT/SIGTERM cancels worker context, stops HTTP acceptance and drains HTTP
requests for up to 15s. Database publication cancellation rolls back uncommitted
work; the process waits for the worker to return before closing the pool. A
listener failure also cancels and joins the worker. Multiple instances may enable
it: database serialization prevents duplicate publication. No admin route is added.

Deployment order: apply reviewed SQL migrations explicitly -> invoke Bootstrap
through a controlled operator workflow -> enable publication worker and drain
the baseline -> verify pull -> activate a reviewed client. Startup never runs
migrations or Bootstrap. Existing records, unresolved reference mappings, client
conflict handling/full-resync, and Flutter activation remain separate workflows.
Bootstrap exists as a repository operation; no new public admin endpoint/CLI is
provided here. Production migrations have not been run by this checkpoint.

Tests require NOTARIS_SYNC_TEST_DSN for isolated PostgreSQL schemas. Runtime
integration verifies two real workers, later commit of a smaller outbox ID,
restart with pending work, unique sequence assignments, and unchanged Petugas
data. Existing repository tests cover crash rollback and publisher serialization.
