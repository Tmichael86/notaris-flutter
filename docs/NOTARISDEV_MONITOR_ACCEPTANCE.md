# Controlled Windows Monitoring acceptance

Prepared receipt: `.local/transaction-live-readiness-20261106-113242`.
Its `ui-preparation.json` records both temporary SQLite paths and fixture UUIDs.
Normal development/daily profiles are not used. This is a separate acceptance
factory; `TransactionManualProfile.validateLocation` still rejects live targets.
UI Smoke and normal Monitoring execution remain blocked.

## Approval and write boundary

Do not run any stage other than Check until the user approves this exact plan:

`40100CACDD416FD4682759163514B6477AD78DC3D2DA774419FB6D000898DEB8`

Only two new Master CREATE and two Transaction CREATE, two initial payments, two
final numbers, four new publication events. No UPDATE/DELETE/cleanup. Transaction
cursor 6 -> 8, Master cursors 5 -> 6 each. Fixtures are labelled E2E-TX-e4d625c2.
Do not use the broader old lifecycle executor or its ten-event allowlist.

The owned backend is started with a hash-pinned four-event plan. Its global
acceptance gate denies every other business write, validates JWT actor 2001/11,
exact domain/UUID/CREATE, zero expected revision and one initial payment. Existing
aggregate transactions, durable receipts and fingerprints enforce idempotency.
Wrong-target, unrelated pending or cursor-budget mismatch blocks further writes.
Transaction writes additionally require both Master publications; PPAT follows
publication of the Notaris Transaction. Existing bounded publisher independently
checks allowlist, target, pending events and expected cursor inside publication.

Authenticated GET `/api/v1/development/transaction-acceptance` queries the active
connection for current_database(), inet_server_addr/port and the synthetic marker;
it returns only target facts, account/group and plan hash. It exists only on the
owned acceptance backend. The launcher attests before dependencies/Flutter/publish;
the service attests before every sync HTTP request and the backend rechecks before
every mutation. No passwords, DSNs or JWTs enter manifests or attestation files.

## Commands after explicit approval

From repository root in each terminal:

```powershell
$h='40100CACDD416FD4682759163514B6477AD78DC3D2DA774419FB6D000898DEB8'
.\scripts\run-notarisdev-monitor-acceptance.ps1 -Stage Check
```

Stop the existing backend on 8081 yourself, then keep terminal 1 running:

```powershell
.\scripts\run-notarisdev-monitor-acceptance.ps1 -Stage Backend -ApprovedPlanSha256 $h
```

Terminal 2, once only:

```powershell
.\scripts\run-notarisdev-monitor-acceptance.ps1 -Stage Dependencies -ApprovedPlanSha256 $h
```

This reuses Master CREATE repositories, publishes one event per domain, validates
receipts and pulls both Masters into A/B through the cloud repositories. It creates
a one-attempt lock before writing and a readiness receipt only after verification.
Failure/ambiguous commit: stop, retain lock, inspect read-only; no automatic retry.

Run Windows devices **sequentially**, avoiding concurrent builds of one executable:

1. `-Stage DeviceA -ApprovedPlanSha256 $h`: login fixture.operator, confirm banner
   DEV notarisdev ISOLATED ACCEPTANCE. System > Monitoring: choose Notaris Upload,
   select the prepared record and confirm. Inspect Log; ACK remains unconfirmed
   publication. Quit Flutter with q.
2. `-Stage PublishNotaris -ApprovedPlanSha256 $h`.
3. DeviceA again: PPAT Upload only, then quit. `-Stage PublishPPAT ...`.
4. `-Stage DeviceB ...`: Download Transaksi (feed gabungan). Count 2, cursor 8;
   repeat count 0. Check numbers, snapshots, payments once, Log and Monitoring.
   Quit/restart B to confirm persisted state.
5. DeviceA: Download shared feed to cursor 8, confirm both ACKs become observed
   publication evidence. No implicit upload occurs during download.

Prefix each stage with `.\scripts\run-notarisdev-monitor-acceptance.ps1`.
No additional Master mutation or publication stage is exposed by the launcher.
Any unexpected event, scope/identity mismatch, failure or ambiguous outcome:
stop; retain receipts, profiles and locks. Do not reset cursors or force cleanup.

Readiness testing uses disposable PostgreSQL/SQLite and injected HTTP attestation
responses. Actual notarisdev HTTP attestation is collected after the approved
backend restart, before the first live write; no live CREATE has run in preparation.
