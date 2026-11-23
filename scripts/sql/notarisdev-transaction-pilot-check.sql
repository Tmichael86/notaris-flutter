BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT current_database() = 'notarisdev'
   AND host(inet_server_addr()) = '127.0.0.1'
   AND inet_server_port() = 5432
   AND current_user = :'APP_ROLE' AS target_ok \gset
\if :target_ok
\else
  \quit
\endif
SELECT COALESCE((SELECT notaris_bersangkutan = 'NOTARISDEV SYNTHETIC v1'
                 FROM konfigurasi_umum WHERE id = 1), false) AS marker_ok \gset
\if :marker_ok
\else
  \quit
\endif

SELECT jsonb_build_object(
  'target', '127.0.0.1:5432/notarisdev',
  'marker', 'NOTARISDEV SYNTHETIC v1',
  'role', current_user,
  'account_active', EXISTS(SELECT 1 FROM users WHERE id=2001 AND group_id=11 AND status=1),
  'permissions', (SELECT jsonb_object_agg(s.sidebar_kode, jsonb_build_object('read',a."read",'create',a."create"))
    FROM sidebar s JOIN sidebar_akses a ON a.sidebar_id=s.id
    WHERE a.group_id=11 AND s.status=1 AND s.sidebar_kode IN ('transaksi','pekerjaan_notaris')),
  'master_publication', (SELECT to_jsonb(p) FROM pekerjaan_notaris_sync_publication p WHERE id=1),
  'master_pending', (SELECT count(*) FROM pekerjaan_notaris_sync_outbox WHERE publication_seq IS NULL),
  'ppat_pending', (SELECT count(*) FROM pekerjaan_ppat_sync_outbox WHERE publication_seq IS NULL),
  'master_feed', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'sequence',e.publication_seq,'uuid',e.aggregate_uuid,'payload_uuid',e.payload->>'uuid','operation',e.operation,'revision',e.revision,
    'nama',e.payload->'nama','harga',e.payload->'harga','proses',e.payload->'proses') ORDER BY e.publication_seq),'[]')
    FROM pekerjaan_notaris_sync_outbox e WHERE e.publication_seq IS NOT NULL),
  'active_masters', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'uuid',m.uuid,'name',m.nama,'revision',m.row_version,'sequence',e.publication_seq,
    'price_uuid',h.uuid,'category_uuid',c.uuid,'price',h.harga,'estimate',h.estimasi_waktu,
    'price_matches_publication',EXISTS(SELECT 1 FROM jsonb_array_elements(e.payload->'harga') hp
      WHERE hp->>'uuid'=h.uuid::text AND hp->>'category_uuid'=c.uuid::text
        AND hp->>'harga'=h.harga AND hp->>'estimasi_waktu'=h.estimasi_waktu))), '[]')
    FROM pekerjaan_notaris m
    LEFT JOIN pekerjaan_notaris_sync_outbox e ON e.aggregate_uuid=m.uuid AND e.revision=m.row_version
      AND e.operation IN ('create','update') AND e.publication_seq IS NOT NULL
    LEFT JOIN pekerjaan_notaris_harga h ON h.pekerjaan_notaris_id=m.id AND h.status=1
    LEFT JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id AND c.status=1
      AND (to_jsonb(c)->>'deleted_at') IS NULL
    WHERE m.status=1 AND m.deleted_at IS NULL),
  'pemohon_active', EXISTS(SELECT 1 FROM pemohon WHERE uuid=:'PEMOHON_UUID'::uuid AND status=1 AND deleted_at IS NULL),
  'petugas_version', (SELECT row_version FROM petugas WHERE id=101 AND uuid=:'PETUGAS_UUID'::uuid AND status=1 AND deleted_at IS NULL),
  'transaction_publication', (SELECT to_jsonb(p) FROM transaction_cloud_publication p WHERE id=1),
  'transaction_pending', (SELECT count(*) FROM transaction_cloud_outbox WHERE publication_seq IS NULL)
);
ROLLBACK;
