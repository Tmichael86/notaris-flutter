# Project backlog after Petugas Baseline UI

Inventory date2026-11-02, branch feature/pemohon-cloud-sync, source checkpoint
0f35f4d. Read-only source/document review; not a new runtime validation. Historical
checklists can be stale: current code evidence below takes precedence. A screen
existing, or a class being named Dummy, alone does not establish end-to-end status.

## Accepted checkpoint

Petugas Baseline UI: **PASSED, manual7/7**, reported by the user. Banner, login,
Petugas4, Pemohon20, shared shell navigation, table/pagination/scrollbar and restart
persistence all passed. See PETUGAS_FLUTTER_BASELINE_PULL.md for scope. No claim of
completed push, publisher, bidirectional/global sync or production release.

## Remaining modules and concrete gaps

- **Monitoring Sinkronisasi — manager request, backlog.** A dedicated per-module
  status view (green/yellow/red), selective manual upload/download and progress.
  Existing pekerjaan_provider.dart exposes a global in-memory SyncStatus and an
  ordered combined push/pull; it is not a per-module control panel. Define status
  meaning, permissions, pending/conflict/blocked handling and supported directions
  before enabling actions. Unsupported module/direction must not imply success.
  Keep smoke mode write guards; adding this backlog does not enable sync.
- **Log Sinkronisasi — manager request, backlog.** Persistent history for success,
  failure and retry, with timestamp, module, direction and error reason. Existing
  session_sync_controller.dart/SyncStatus/debugPrint are not a durable cross-module
  history. Petugas journal/conflict storage is entity/protocol metadata, not the
  requested attempt-history UI. Retain existing journals; log no passwords/tokens.
- **Petugas cloud operations — partial.** Baseline pull/import/UI accepted;
  repository/API/conflict components exist. Normal-app push, publisher activation,
  bidirectional operational acceptance, conflict-resolution UX,410 recovery and
  multi-device acceptance remain separate. Evidence: PETUGAS_FLUTTER_BASELINE_PULL,
  PETUGAS_DEVELOPMENT_OPERATIONS and ADR-0001-MULTI-DEVICE-SYNC. ADR's old development
  provisioning blockers are historical, superseded by newer baseline checkpoints.
- **Master Data — local implementation present, cloud completion partial.** Petugas
  and Pemohon displayed4/20 in smoke; pekerjaan_notaris/pekerjaan_ppat screens use
  repository-backed providers, as do category/expense masters. Do not classify them
  as wholly dummy. Complete/audit each module's sync contract, references, conflict
  handling and acceptance separately; existing category/Pemohon sync is not proof
  of complete multi-device synchronization for all masters.
- **Transaksi and process validation — partial.** transaction_desktop_screen.dart
  uses transactionControllerProvider and local repositories; transaction save is
  not merely a static form. ADR-0001 documents missing aggregate cloud contract,
  mapping/journal/recovery; current backend has models/transaksi.go without the
  complete authoritative process-validation slice. Audit server list/detail,
  permissions/transitions and atomic history before enabling aggregate writes.
  Tax calculator, PPAT status, document/note workflow, invoice/receipt still need
  scoped completion/acceptance (historical non-goals in process-validation-
  implementation.md are backlog, not authorization to implement them now).
- **Monitoring menu (transactions) — prototype.** monitoring_desktop_screen.dart
  directly seeds monitoringData with DummyMonitoringItem. Bind to authoritative
  transaction/process data. This existing menu is distinct from the new Monitoring
  Sinkronisasi requirement.
- **Pengeluaran/Piutang/Penghasilan — prototype screens.** These screen files seed
  in-memory _PengeluaranItem/_PiutangItem/_Row lists. Complete persistence, payment/
  transaction linkage, business calculations, API authorization and acceptance.
  The real Jenis Pengeluaran master is a different module.
- **Laporan Materai/Pendapatan — prototype screens.** laporan_materai and
  laporan_pendapatan use seeded MateraiDummy/PendapatanDummy lists; connect actual
  stock/financial ledger sources and verify calculation/filter/export contracts.
- **Users/Groups/Sidebars/Konfigurasi Umum — admin UI integration incomplete.**
  users/groups/sidebar screens seed local Dummy lists; configuration seeds example
  _ConfigItem values. Integrate persistent APIs and authorization. Real login and
  server-provided menu permissions already exist; these are not evidence that the
  separate administrative CRUD screens are complete.
- **Dashboard — prototype metrics.** dashboard_desktop_screen.dart _buildStats
  contains fixed metrics (e.g. Total Transaksi128). Replace with actual aggregated
  data and validate year filters/calculations after core ledger contracts settle.

## Recommended next priorities

1. Specify and implement persistent Log Sinkronisasi on existing sync boundaries;
   retain module/direction/attempt/retry/error facts without activating workers.
2. Build Monitoring Sinkronisasi from those facts, with green/yellow/red status,
   progress and selective controls gated by capability, permissions and explicit
   operational approval. Preserve shared shell; smoke mode remains protected.
3. Deliver a read-only Transaksi/Monitoring vertical slice with an agreed data/API
   contract and authoritative process rules before aggregate/bidirectional writes.

This documentation task changes no application source, database or operational
activation. No new tests, E2E, migration, bootstrap, publisher or global sync ran.
