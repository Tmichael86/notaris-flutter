# H04 — Cloud Simple Master and Pemohon action authorization

Baseline: `0b15a70`, branch `feature/pemohon-cloud-sync`.
H04 implemented and focused validation passed on 21 November 2026.
Operational activation remains OFF. H05 is not closed by this change.

## Scope and actual operations

| Entity/table | Canonical grant | HTTP resource |
| --- | --- | --- |
| `pekerjaan_kategori` | `kategori_pekerjaan` | `/api/v1/kategori-pekerjaan` |
| `pengeluaran_jenis` | `jenis_pengeluaran` | `/api/v1/jenis-pengeluaran` |
| `pemohon` | `pemohon` | `/api/v1/pemohon` |

Previously Simple Master POST with a UUID called an upsert, allowing a
CREATE-only caller to change an existing row. Sync PUT used only an UPDATE
route guard even when the repository inserted a previously unknown UUID.

The normal POST is now CREATE-only. Simple Master's supplied UUID can return
its original active row without writing only when the payload is identical,
the actor is its original creator, no update has occurred, and CREATE is still
granted. A different payload, another creator, an updated row, or inactive UUID
conflicts (409). Even CREATE+UPDATE rights cannot make POST update an existing
UUID. Normal Pemohon POST retains server-generated UUIDs and its existing DTO.

Normal PUT-by-ID requires UPDATE and returns 404 for a missing/inactive row;
it never inserts. Sync PUT `/sync/:uuid` retains the approved upsert wire:
new UUID requires CREATE; changed existing UUID requires UPDATE. The route
checks READ as a preliminary gate, not as write authority. The repository
determines and enforces the actual action inside its database transaction.

An exact sync retry is a no-op: no timestamp, `last_synced_at`, audit-user or
sequence change. An original creator retaining CREATE can replay the initial
unmodified CREATE; other existing-row retries require UPDATE. READ alone,
group labels, aliases, inactive/ambiguous grants, stale security versions and
mismatched authenticated identities do not authorize writes. Inactive rows
are never resurrected. Missing/invalid authentication produces 401; denied
actions produce 403. Existing duplicate name/NIK conflicts remain 409.

## Repository boundary and concurrency

`JWTAuth` supplies a typed request-context actor only after JWT verification.
The numeric `userID` argument must match that actor. Current active user,
group, conditional P0 security version and exactly one canonical action grant
are resolved inside the same transaction as the write. JWT expiry is checked
again before commit. The existing `UsersSecurityEnabled` policy is unchanged.

The transaction takes the administration advisory lock `71920261119` SHARED;
approved Users/Groups/grant changes take it EXCLUSIVE. Current user/group/grant
rows are also locked. A preceding permission revocation is observed before
writing. This follows the existing administration rule that uncoordinated
external authorization DML must be prohibited. Session group mismatches fail
closed; reads retain their existing current-group behavior.

Sync UUID advisory locks include absent-row creation and normalize UUID case;
row locks and existing normalized name/NIK locks protect duplicates. Concurrent
identical CREATEs persist one row; competing changed payloads from CREATE-only
callers cannot update the winner. Authorized UPDATEs serialize. These legacy
APIs have no expected-revision field: H04 does not introduce optimistic 409
conflicts or claim lost-update detection for two authorized updates.

Pemohon response/reference reads now occur inside the write transaction,
preventing an ACK from reading a different concurrent post-commit state.
Simple Master/Pemohon have no durable mutation-receipt/outbox/feed protocol;
UUID no-op retries remain their existing identity contract. No fake receipts,
new migrations, publication or global synchronization were introduced.
Petugas's separate versioned receipt contract is unchanged.

## Executed validation

```powershell
python .\scripts\test-users-security-disposable.py --h04
cd backend-notaris-go
go vet ./controllers ./repositories ./middleware ./routes
cd ..\frontend_notaris
flutter analyze --no-pub
```

The existing runner creates a fresh owned PostgreSQL cluster on port 55793,
verifies its data directory/database marker, and stops it on completion.
It never accepts an operational DSN. Isolated schemas use existing Users P0
migration/test infrastructure. Ambiguous-grant testing fault-injects a legacy
duplicate only in an owned disposable schema; production constraints remain
unchanged. Every denied request/direct call fingerprints all actual fixture
tables (including administrative audit) and sequences to prove no side effects.

Results: **17 Go top-level tests / 58 leaf cases PASS**, including **38 H04
leaf cases**, Users security, Groups revocation and Petugas regression;
**0 skipped, 0 failed** in the final run. **3 Flutter publisher HTTP tests PASS**:
the actual category, expense-type and applicant repository publishers use
fresh SQLite memory databases, authenticated Go HTTP and disposable PostgreSQL.
Lost ACK keeps dirty state; exact retry does not duplicate rows; subsequent
UPDATE persists; clean publishers send no further write. Integrity/FK pass.
`go vet` passes; `flutter analyze` reports no issues. Evidence:
`.local/h04/disposable-go.log` and `.local/h04/flutter-analyze.log`.

Earlier fixture-test corrections distinguished P0's 401 inactive-group session
response from repository 403, and deliberately constructed legacy ambiguous
grants despite the normal P0 unique index. No runtime guard was weakened.

No Flutter runtime source, Windows binding, H01/H02/H03/H07, operational
database, original SQLite, old acceptance profile or existing restore cluster
was modified or opened. No release rebuild was needed. H02/H03 manual Windows
acceptance and H05 release-security gates remain separate. H01 remains
`DISABLED_BY_POLICY`; no push/merge or operational activation is authorized.
