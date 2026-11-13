\pset format unaligned
\pset tuples_only on
BEGIN READ ONLY;
SELECT jsonb_build_object(
 'target',jsonb_build_object('database',current_database(),'host',inet_server_addr()::text,'port',inet_server_port(),'role',current_user,'marker',(SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1)),
 'account',(SELECT jsonb_build_object('id',id,'group_id',group_id,'status',status) FROM users WHERE id=2001),
 'permissions',(SELECT jsonb_object_agg(s.sidebar_kode,jsonb_build_object('read',a."read",'create',a."create",'update',a."update",'delete',a."delete",'status',s.status)) FROM sidebar s JOIN sidebar_akses a ON a.sidebar_id=s.id WHERE a.group_id=11 AND s.sidebar_kode IN ('transaksi','pekerjaan_notaris','pekerjaan_ppat')),
 'pemohon',(SELECT jsonb_build_object('id',id,'uuid',uuid) FROM pemohon WHERE status=1 AND deleted_at IS NULL ORDER BY id LIMIT 1),
 'petugas',(SELECT jsonb_build_object('id',id,'uuid',uuid,'row_version',row_version) FROM petugas WHERE status=1 AND deleted_at IS NULL ORDER BY id LIMIT 1),
 'category',(SELECT jsonb_build_object('id',id,'uuid',uuid) FROM pekerjaan_kategori c WHERE uuid='fa000002-0000-4000-8000-000000000001'::uuid AND status=1 AND (to_jsonb(c)->>'deleted_at') IS NULL),
 'masters',jsonb_build_object('notaris',(SELECT jsonb_build_object('last_seq',last_seq,'min_cursor',min_cursor,'pending',(SELECT count(*) FROM pekerjaan_notaris_sync_outbox WHERE publication_seq IS NULL),'receipts',(SELECT count(*) FROM pekerjaan_notaris_sync_mutation),'events',(SELECT count(*) FROM pekerjaan_notaris_sync_outbox)) FROM pekerjaan_notaris_sync_publication WHERE id=1),'ppat',(SELECT jsonb_build_object('last_seq',last_seq,'min_cursor',min_cursor,'pending',(SELECT count(*) FROM pekerjaan_ppat_sync_outbox WHERE publication_seq IS NULL),'receipts',(SELECT count(*) FROM pekerjaan_ppat_sync_mutation),'events',(SELECT count(*) FROM pekerjaan_ppat_sync_outbox)) FROM pekerjaan_ppat_sync_publication WHERE id=1)),
 'transactions',(SELECT jsonb_build_object('last_seq',last_seq,'min_cursor',min_cursor,'pending',(SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq IS NULL),'receipts',(SELECT count(*) FROM transaction_cloud_mutation),'events',(SELECT count(*) FROM transaction_cloud_outbox),'parents',(SELECT count(*) FROM transaction_cloud),'payments',(SELECT count(*) FROM transaction_cloud_payment),'counters',(SELECT coalesce(jsonb_agg(to_jsonb(c)),'[]') FROM transaction_cloud_number_counter c)) FROM transaction_cloud_publication WHERE id=1),
 'other_sessions',(SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid())
)::text;
ROLLBACK;
