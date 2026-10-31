-- Read-only aggregate diagnostics. Does not export names/documents/JSON values.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='20s';
SET LOCAL lock_timeout='3s';
SELECT json_build_object('section','context','database',current_database(),
 'read_only',current_setting('transaction_read_only'),
 'target_exists',EXISTS(SELECT FROM pg_database WHERE datname='notarisdev'),
 'tables',(SELECT count(*) FROM pg_tables WHERE schemaname='public'),
 'fk_count',(SELECT count(*) FROM pg_constraint WHERE contype='f' AND connamespace='public'::regnamespace));
SELECT json_build_object('section','parents','detail_rows',count(*),
 'distinct_parent_ids',count(DISTINCT d.transaksi_id),
 'minimum_parent_id',min(d.transaksi_id),'maximum_parent_id',max(d.transaksi_id),
 'matches_current',count(*) FILTER(WHERE t.id IS NOT NULL),
 'matches_archive',count(*) FILTER(WHERE a.id IS NOT NULL),
 'matches_neither',count(*) FILTER(WHERE t.id IS NULL AND a.id IS NULL),
 'archive_distinct_parents',count(DISTINCT a.id),
 'uuid_present',count(d.uuid),'uuid_distinct',count(DISTINCT d.uuid))
FROM public.transaksi_detail_proses d
LEFT JOIN public.transaksi t ON t.id=d.transaksi_id
LEFT JOIN public.transaksi_old a ON a.id=d.transaksi_id;
SELECT json_build_object('section','master_links','rows',count(*),
 'missing_job_type',count(*) FILTER(WHERE j.id IS NULL),
 'process_notaris_only',count(*) FILTER(WHERE n.id IS NOT NULL AND p.id IS NULL),
 'process_ppat_only',count(*) FILTER(WHERE p.id IS NOT NULL AND n.id IS NULL),
 'process_in_both',count(*) FILTER(WHERE n.id IS NOT NULL AND p.id IS NOT NULL),
 'process_in_neither',count(*) FILTER(WHERE n.id IS NULL AND p.id IS NULL),
 'json_object',count(*) FILTER(WHERE json_typeof(d.atribut)='object'),
 'json_array',count(*) FILTER(WHERE json_typeof(d.atribut)='array'))
FROM public.transaksi_detail_proses d
LEFT JOIN public.pekerjaan_jenis j ON j.id=d.jenis_pekerjaan_id
LEFT JOIN public.pekerjaan_notaris_proses n ON n.id=d."prosesId"
LEFT JOIN public.pekerjaan_ppat_proses p ON p.id=d."prosesId";
SELECT json_build_object('section','other_links',
 'current_rows',(SELECT count(*) FROM public.transaksi),
 'archive_rows',(SELECT count(*) FROM public.transaksi_old),
 'stamp_rows',(SELECT count(*) FROM public.transaksi_materai),
 'stamp_current_matches',(SELECT count(*) FROM public.transaksi_materai m JOIN public.transaksi t ON t.id=m.transaksi_id),
 'stamp_archive_matches',(SELECT count(*) FROM public.transaksi_materai m JOIN public.transaksi_old t ON t.id=m.transaksi_id),
 'payments',(SELECT count(*) FROM public.transaksi_riwayat_pembayaran),
 'payment_current_number_matches',(SELECT count(*) FROM public.transaksi_riwayat_pembayaran r WHERE EXISTS(SELECT FROM public.transaksi t WHERE t.no_akta=r.no_transaksi)),
 'payment_archive_number_matches',(SELECT count(*) FROM public.transaksi_riwayat_pembayaran r WHERE EXISTS(SELECT FROM public.transaksi_old t WHERE t.no_akta=r.no_transaksi)),
 'detail_triggers',(SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid='public.transaksi_detail_proses'::regclass),
 'archive_triggers',(SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid='public.transaksi_old'::regclass));
SELECT json_build_object('section','schema_history',
 'migration_names',(SELECT json_agg(migration ORDER BY id) FROM public.migrations),
 'candidate_tables',(SELECT json_agg(tablename ORDER BY tablename) FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'transaksi%'),
 'current_has_pemohon_uuid',EXISTS(SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='transaksi' AND column_name='pemohon_uuid'));
ROLLBACK;
