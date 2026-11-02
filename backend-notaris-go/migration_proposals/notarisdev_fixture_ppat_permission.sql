-- Permission-only proposal. NOT executed by provisioning/startup.
-- Requires separate user approval and a freshly reviewed read-only preflight.
\set ON_ERROR_STOP on
\if :{?approved_target}
SELECT :'approved_target' = '127.0.0.1:5432/notarisdev' AS approved \gset
\else
\echo 'STOP: separate approval and approved_target required'
\quit
\endif
\if :approved
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='20s';
LOCK TABLE public.sidebar,public.sidebar_akses IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE menu_id bigint; seq_value bigint; seq_called boolean;
BEGIN
 IF current_database()<>'notarisdev' OR inet_server_addr()<>'127.0.0.1'::inet OR inet_server_port()<>5432
    OR (SELECT notaris_bersangkutan FROM konfigurasi_umum WHERE id=1) IS DISTINCT FROM 'NOTARISDEV SYNTHETIC v1'
    OR NOT EXISTS(SELECT 1 FROM groups WHERE id=11 AND group_nama='Fixture Operators' AND status=1)
    OR NOT EXISTS(SELECT 1 FROM users WHERE id=2001 AND username='fixture.operator' AND group_id=11 AND status=1)
 THEN RAISE EXCEPTION 'Development fixture identity mismatch'; END IF;
 IF (SELECT count(*) FROM sidebar WHERE sidebar_kode='pekerjaan_ppat')>1 THEN RAISE EXCEPTION 'Ambiguous sidebar'; END IF;
 SELECT id INTO menu_id FROM sidebar WHERE sidebar_kode='pekerjaan_ppat';
 IF menu_id IS NULL THEN
   SELECT last_value,is_called INTO seq_value,seq_called FROM public.sidebar_id_seq;
   IF seq_value<(SELECT coalesce(max(id),0) FROM sidebar) OR (NOT seq_called AND seq_value<=(SELECT coalesce(max(id),0) FROM sidebar)) THEN RAISE EXCEPTION 'Sidebar sequence needs separate review'; END IF;
   INSERT INTO sidebar(sidebar_nama,sidebar_route,sidebar_kode,sidebar_icon,sidebar_index,status)
     VALUES('Pekerjaan PPAT','/pekerjaan_ppat','pekerjaan_ppat','folder',7,1) RETURNING id INTO menu_id;
 ELSE
   IF NOT EXISTS(SELECT 1 FROM sidebar WHERE id=menu_id AND sidebar_nama='Pekerjaan PPAT' AND sidebar_route='/pekerjaan_ppat' AND status=1) THEN RAISE EXCEPTION 'Existing sidebar differs; do not overwrite'; END IF;
 END IF;
 IF (SELECT count(*) FROM sidebar_akses WHERE sidebar_id=menu_id AND group_id=11)>1 THEN RAISE EXCEPTION 'Duplicate scoped access'; END IF;
 IF NOT EXISTS(SELECT 1 FROM sidebar_akses WHERE sidebar_id=menu_id AND group_id=11) THEN
   SELECT last_value,is_called INTO seq_value,seq_called FROM public.sidebar_akses_id_seq;
   IF seq_value<(SELECT coalesce(max(id),0) FROM sidebar_akses) OR (NOT seq_called AND seq_value<=(SELECT coalesce(max(id),0) FROM sidebar_akses)) THEN RAISE EXCEPTION 'Access sequence needs separate review'; END IF;
   INSERT INTO sidebar_akses(sidebar_id,group_id,"read","create","update","delete") VALUES(menu_id,11,1,1,1,1);
 ELSIF NOT EXISTS(SELECT 1 FROM sidebar_akses WHERE sidebar_id=menu_id AND group_id=11 AND "read"=1 AND "create"=1 AND "update"=1 AND "delete"=1) THEN RAISE EXCEPTION 'Existing permission differs; review rather than widening silently';
 END IF;
END $$;
COMMIT;
\echo 'FIXTURE_PPAT_PERMISSION_COMMITTED'
\else
\echo 'STOP: wrong approved_target'
\endif
