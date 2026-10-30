# notarisdev: review proposal, 30 October 2026

Status: **NO DATA CLONE APPROVED OR CREATED**. Owner selected sanitization review
before copying data. No Cloud Sync migration has been applied to either database.
This document is for consultation with the supervisor, not a production runbook.

Follow-up: [legacy relationships and synthetic fixture review](NOTARISDEV_LEGACY_AND_FIXTURE_REVIEW.md)
separates intended parentage from unproven archive matches, proposes fully synthetic
smoke/volume/negative profiles and records revised first-install migration guards.
No historical record is classified as corrupt solely because its current parent
is absent. The fixture option does not authorize any raw source data clone.
For the new fully synthetic route, use new fixture-owned IDs with internally
consistent links. The source-ID-preserving transformation below remains an
alternative proposal only; it is not a prerequisite or authorization for fixtures.

## Evidence from the running database

Read-only connections to localhost:5432 succeeded on PostgreSQL 18.6. Database
notarislokal is owned by postgres, size observed 16,258,751 bytes (~15.5 MiB).
notarisdev does not exist. No service restart was needed. Schema public contains
38 tables; extensions plpgsql 1.0, pgcrypto 1.4, uuid-ossp 1.1. The connecting role
is superuser postgres (has CREATE DATABASE), unsuitable for the future app role.
No public foreign-key constraints were found: many relationships are implicit.
No foreign tables, subscriptions or event triggers were observed. These checks
are not a complete audit of extension functions, triggers or privileges.

Exact aggregate counts: petugas 4, pemohon 2070, users 6, transaksi 0,
transaksi_old 130. All four Petugas have contact/identifier fields populated;
all six users have nonempty password values. Values were NOT displayed or
classified as definitely real/synthetic. Treat them as sensitive by default.
Statistics also show thousands of process, payment, stamp and expense rows;
statistics are estimates, not certified export row counts.

Petugas currently has bigint PK id + sequence, nullable integer jenis_kelamin
and user_id; nullable timestamps without time zone; status smallint NOT NULL;
no uuid, row_version or deleted_at. Only its PK index was found (no email/NIK
unique constraint). Both gender/user orphan counts are zero. Gender has bigint
id and nama/status, no canonical code or UUID. Users have bigint id, group_id,
username/password/email and status. No assumption that SQLite IDs equal these IDs.

Source structural fingerprint was compared before/after schema-only pg_dump.
It covers columns, indexes, constraints, views, public functions, triggers and
sequence definitions, not row content or a guarantee against another application's
writes. Every audit connection set default_transaction_read_only=on. No writes,
migrations, CREATE DATABASE, full-data dump or restore were issued.

## Sensitive-column inventory and proposed treatment

This covers all 38 observed tables. **Every column must have an explicit export
rule**; any unknown column/type/table aborts export. Preserve counts for business
tables after approval; do not preserve original secrets merely to preserve volume.

| Tables / fields | Proposed synthetic replacement |
| --- | --- |
| petugas: nama, nik, alamat, tempat_lahir, tanggal_lahir, no_telp, email | Generated person labels, unique fixed-length synthetic NIK, fictitious address/city, generated birth date, non-routable contact placeholders, unique `@example.invalid` email. No hashes of original PII. |
| pemohon: nama, nik, alamat, no_telp | Same policy, namespace distinct from Petugas. Preserve null patterns only if approved. |
| users: username, nama, email, no_telp, alamat, image | Synthetic account names/emails; remove image/path/URL. Keep user PK and group links; do not copy credentials. |
| users.password | Generate fresh random per-account secrets and bcrypt-compatible hashes using backend auth format; no original hashes. Separately provision one least-privilege test operator via normal login. Password stays outside Git/logs. Verify Go accepts generated hash. |
| sessions (id, ip_address, user_agent, payload), password_resets (email, token), personal_access_tokens (token, name, abilities, tokenable_type), failed_jobs (uuid, connection, queue, payload, exception) | Default export **zero rows**; approvals required if synthetic volume is needed. Never copy live tokens, reset tokens, serialized sessions, credentials, stack traces or request bodies. |
| konfigurasi_umum: alamat, telp_*, email, notaris_bersangkutan, ppat_bersangkutan | Entirely synthetic office and practitioner identities. Financial configuration regenerated under consistent fixture rules. |
| transaksi AND transaksi_old: no_akta, nomor_akta, judul, keterangan, uraian_cetak_pemohon, keperluan_cetak_pemohon, tanggal_* | Synthetic deed/document identifiers and text; generated dates preserving required order, not original dates. Both current and archive tables require rules. |
| transaksi: locked_by, locked_at | Clear transient locks in target only. Keep permanent relationship fields. |
| transaksi financial fields incl biaya_*, sub_total, potongan_biaya, total, tax fields, pengecekan, ploting_validasi, surat_kuasa_membebankan_hak_tanggungan | Generate synthetic amounts consistently; recompute formula totals, do not retain exact real amounts. Specify string-number formats and rounding in fixture manifest. |
| transaksi_detail_proses: atribut JSON, catatan, pekerjaanNama, kategoriNama, prosesNama | Rebuild from allowlisted typed template; no copying arbitrary nested values. Regenerate snapshots from synthetic master data. Unknown JSON structure aborts export. |
| transaksi_cetak_serah_terima: no_transaksi, list_keperluan, uraian, keperluan | Rebuild printable text; document-number references must use the SAME explicit translation as payment rows. |
| transaksi_riwayat_pembayaran: no_transaksi, tanggal_pembayaran, jumlah_dibayar, keterangan | Synthetic document translation, dates, text, amounts consistent with synthetic transaction/payment history. |
| pengeluaran: no_faktur, jumlah, tanggal_pengeluaran, keterangan; pendapatan: tanggal and all money/balance columns | Synthetic invoice identifiers and financial ledger with recomputed balances. No original financial history. |
| materais + materais_copy1: date, keterangan, stock/count columns | Synthetic dates/text; retain volume and recompute stock consistency in each fixture history. |
| pekerjaan_notaris/ppat, *_proses (detail), *_atributs (atribut), *_harga (harga, estimasi_waktu), pekerjaan_kategori, pekerjaan_jenis, pengeluaran_jenis, pembayaran_jenis, jenis_pajak, transaksi_status, jenis_kelamin | Master labels require approved classification. Keep verified operational codes only; replace uncontrolled text and prices with synthetic equivalents. Do not infer canonical gender identity from label/id. |
| groups; sidebar; sidebar_akses | Preserve reviewed permission structure/route codes to test normal authorization. Generate group display names if identifying. Review broad permissions before enabling test operator. |
| migrations | Preserve reviewed migration identifiers/batch only as historical metadata, not proof Go SQL has run. |
| transaksi_materai + transaksi_materai_copy1 | Preserve integer PK/relationship/status structure; audit orphan baseline before export. |
| all tables: created_by, updated_by, created_at, updated_at, status | Preserve valid user links and statuses; deterministic synthetic audit dates consistent across dependencies. Account IDs remain existing numeric references to newly synthetic users. |
| existing uuid/is_dirty/last_synced_at/deleted_at on Pemohon/transaksi/process/master tables | Distinct development identity namespace: regenerate UUIDs via explicit old->new mapping for every UUID reference, preserve numeric PKs. No old sync journal/cursor/auth cache. Review tombstone distribution and dirty defaults explicitly. |

## Relational and representativeness contract

1. Preserve every business integer primary key, sequence ownership and link value;
   rebase sequence next values above maximum imported keys. No renumbering.
2. Inventory implicit links including petugas.user_id/jenis_kelamin, users.group_id,
   created_by/updated_by, transaksi.petugas_id/pemohon_id, materais.petugas_id,
   process/price/category links, sidebar_parent_id/sidebar_akses, polymorphic
   pekerjaan_id/prosesId, payments/print records linked by no_transaksi. A column
   suffix is a candidate, not proof of a relationship.
3. Current transaksi has zero rows while archive/process tables are populated.
   Do NOT silently redirect archive relationships, fabricate missing parents,
   or claim referential integrity from absent FK constraints. Record per-link
   orphan counts in source and preserve that baseline; decide separately whether
   tests need a second fully consistent generated fixture dataset.
   Actual check: all 7058 process-detail rows lack a parent in current transaksi;
   only 289 match an ID in transaksi_old. An archive ID match alone is NOT proof
   of the intended relationship. Resolve this with the supervisor, never by
   silently repairing or deleting source rows.
4. One readonly REPEATABLE READ exported snapshot across the approved exporter
   gives consistent row counts/dependencies. Stream source rows into a fail-closed
   transformer; write ONLY sanitized rows to target/artifact. Do not make a raw
   full clone/dump then sanitize it afterwards. Source never receives UPDATE.
5. Generated names/identifiers must satisfy lengths, NULL/NOT NULL, uniqueness,
   enum/status domains and application validation. Keep no reversible mapping
   of real names/NIK/contact values. ID-based fixture labels are local test
   labels, NEVER UUID identities for cloud deployments.
6. Run source/target count, PK, FK/implicit-orphan and financial invariants before
   app access. Scan all textual/JSON fields against an explicit allowlist of
   generated forms and ban original credential/token columns from export. A
   random sample alone is insufficient. If completeness cannot be demonstrated,
   use schema-only + fully synthetic fixtures with matching aggregate volumes.

## Backup / creation proposal (not executed)

Only a schema-only custom archive exists under ignored .local/notarisdev-review-*;
pg_restore --list and SHA256 validate archive structure, NOT restore correctness.
It is NOT a full data backup. No target exists, so no source-target comparison
or restore success can be claimed. Schema definitions may themselves be private;
keep the archive local and review functions/defaults/comments before sharing.

After explicit approval: recheck target absence, review extension/owner privileges,
create notarisdev once through an authorized local administrator, restore reviewed
schema without --clean/--create, then import sanitized stream or synthetic fixtures.
Use a dedicated notarisdev-only application role, no superuser or source DB grants.
Sanitization necessarily changes data fingerprints; compare schema, counts and
relational invariants instead of byte equality. On failure, stop access and retain
logs; do not overwrite/drop an existing target or retry blindly.

## Cloud Sync migration review order

Proposal: backend-notaris-go/migration_proposals/20261030_03_notarisdev_petugas.sql
(psql-only; refuses by default, explicitly guards current_database()). No runner
discovers this folder. It references the three existing versioned source migrations:

1. 20261029_01: random server UUID backfill, row_version default 1, deleted_at,
   partial UUID uniqueness, mutation receipts and atomic outbox tables.
2. 20261030_01: singleton transactional publication counter/min_cursor, initialized
   under outbox lock. Outbox BIGSERIAL is NOT the pull cursor.
3. 20261030_02: preserve assigned UUIDs, UUID default/NOT NULL and positive legacy
   versions. Same-name IF NOT EXISTS index creation is not definition verification;
   inspect actual index before declaring migration complete. No ID-derived UUID.
4. Validate object definitions/types/permissions against sanitized target, legacy
   CRUD and reference checks, atomic receipt/outbox and concurrency tests. Do not
   reinterpret timestamp-without-time-zone values without a timezone decision.
5. Bootstrap existing Petugas under the existing repository locks; inspect counts
   and tombstones. Enable publication separately, then manual client only after
   identity/reference/operator reconciliation. No auto matching name/email/NIK.

The source Petugas layout resembles repository assumptions but has no sync columns.
Backend repositories already SELECT uuid/row_version/deleted_at and journal writes,
so current Petugas CRUD is NOT compatible with the unmigrated schema. Login alone
does not prove full application compatibility. General SQL migrations may contain
CREATE/UPDATE and are proposals here, not read-only scripts. Rollback means stop
client/worker and preserve newly assigned identity/receipts/events; no destructive
down migration, publication reset or UUID rewrite.

## Conventional developer workflow (gated until review)

Copy backend-notaris-go/.env.notarisdev.example to ignored .env.notarisdev AFTER
approval/provisioning. Fill only dedicated development credentials and a NEW JWT
secret; never copy source hashes, JWTs or tokens. Terminal 1, repository root:

    .\scripts\run-notarisdev-backend.ps1

This wraps normal go run ./cmd, overrides .env DB settings, fixes localhost:5432 /
notarisdev and HTTP 8081, refuses postgres application role, forces publisher OFF,
and restores process environment afterwards. It does not migrate/bootstrap/create
a database. It currently refuses because no private development config is provided.

Terminal 2 must NOT yet use plain flutter run -d windows: normal main.dart opens
Documents/notaris_offline.sqlite and shared secure auth cache. A separate profile
is a required next implementation, not an existing feature claimed by this phase:

- Debug-only bootstrap of the existing MyApp/AuthStartupGate (normal login,
  permission/sidebar/master flows), API URL http://127.0.0.1:8081/api/v1 only.
- Override AppDatabase provider to a new development/server-generation-specific
  directory and namespace secure auth storage. Never copy daily SQLite or cache.
- Empty new journal/cursor/identity map; preserve daily profile without resets.
  Changing sanitized server generation requires a new profile, not cursor reset.
- No Petugas UI activation/global coordinator addition. Verify existing automatic
  Pemohon/master session sync against sanitized server before first login.
- Only then publish the exact normal-development Flutter command. The existing
  petugas_manual_main.dart target is a harness profile, not a notarisdev profile.

## Required owner decisions / acceptance

Validation in this checkpoint: both PowerShell files parsed; development backend
refused missing private configuration as expected; schema-only archive listing,
SHA256 and before/after structural fingerprint passed; exact counts for all 38
tables were recorded locally; archive has zero TABLE DATA / SEQUENCE SET entries.
Both SQL refusal paths were executed read-only against postgres (not source),
each exiting 3 before DDL. This does NOT validate running the migration body or
restoring a sanitized target. Go `go test -count=1 ./...` exited 0 with integration
DSN unset; PostgreSQL integration cases were not run against either main DB.
Flutter runtime/tests were not re-run: no Flutter code changed and a new normal
development profile remains a required implementation before launching against
notarisdev. No database-normal regression or production readiness is claimed.

Approve sanitization manifest and all unknown JSON/free-text handling; approve
auth-table zero-row exception to volume preservation; choose acceptable synthetic
financial/date distributions; determine archive/orphan semantics; authorize a new
restricted DB role and synthetic operator permission group. If any rule is not
provable, choose fully synthetic fixtures. No unmasked full clone is authorized.

Acceptance: source readonly checks + identical structural fingerprints; target
created once; no source PII/hashes/tokens in export; approved business volumes and
PK/reference baselines; independently verified restore; migrated target only after
review; fresh isolated Flutter profile and normal auth; publication disabled until
bootstrap validation. Full-resync recovery remains blocked; not production-ready.
