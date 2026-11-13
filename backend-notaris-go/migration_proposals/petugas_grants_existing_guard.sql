-- SELECT/catalog assertions only. Any ambiguity blocks; never repairs schema.
DO $$
DECLARE
 app text := current_setting('notaris.review_app_role');
 e record; actual_default text; idx record; pred text; privilege_name text;
 seq regclass; seq_state record; key_number smallint;
BEGIN
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname=app AND rolcanlogin
   AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolbypassrls)
   OR has_schema_privilege(app,'public','CREATE') THEN
  RAISE EXCEPTION 'Nonprivileged application login required';
 END IF;
 FOR e IN SELECT unnest(ARRAY['petugas','petugas_sync_mutations','petugas_sync_outbox','petugas_sync_publication']) AS name LOOP
  IF NOT EXISTS (SELECT FROM pg_class WHERE oid=to_regclass('public.'||e.name)
    AND relkind='r' AND relpersistence='p' AND NOT relrowsecurity AND NOT relforcerowsecurity
    AND (e.name='petugas' OR pg_has_role(current_user,pg_get_userbyid(relowner),'USAGE'))
    AND NOT pg_has_role(app,pg_get_userbyid(relowner),'MEMBER')) THEN
   RAISE EXCEPTION 'Missing/incompatible table or ownership: %',e.name;
  END IF;
  IF EXISTS (SELECT FROM pg_trigger WHERE tgrelid=to_regclass('public.'||e.name) AND NOT tgisinternal)
    OR EXISTS (SELECT FROM pg_rewrite WHERE ev_class=to_regclass('public.'||e.name)) THEN
   RAISE EXCEPTION 'Unexpected trigger/rule: %',e.name;
  END IF;
 END LOOP;
 -- Exact columns of new tables; legacy Petugas keeps its existing columns.
 FOR e IN SELECT * FROM (VALUES
  ('petugas','id','bigint',true,NULL::text),
  ('petugas','uuid','uuid',true,'uuid'),
  ('petugas','row_version','bigint',true,'1'),
  ('petugas','deleted_at','timestamp with time zone',false,'none'),
  ('petugas_sync_mutations','mutation_id','uuid',true,'none'),
  ('petugas_sync_mutations','petugas_uuid','uuid',true,'none'),
  ('petugas_sync_mutations','request_hash','text',true,'none'),
  ('petugas_sync_mutations','acknowledgement','jsonb',true,'none'),
  ('petugas_sync_mutations','created_at','timestamp with time zone',true,'now()'),
  ('petugas_sync_outbox','id','bigint',true,'sequence'),
  ('petugas_sync_outbox','petugas_uuid','uuid',true,'none'),
  ('petugas_sync_outbox','row_version','bigint',true,'none'),
  ('petugas_sync_outbox','tombstone','boolean',true,'none'),
  ('petugas_sync_outbox','payload','jsonb',true,'none'),
  ('petugas_sync_outbox','publication_seq','bigint',false,'none'),
  ('petugas_sync_outbox','published_at','timestamp with time zone',false,'none'),
  ('petugas_sync_outbox','created_at','timestamp with time zone',true,'now()'),
  ('petugas_sync_publication','id','smallint',true,'none'),
  ('petugas_sync_publication','last_seq','bigint',true,'none'),
  ('petugas_sync_publication','min_cursor','bigint',true,'0')
 ) AS expected(tbl,col,typ,nn,def) LOOP
  IF NOT EXISTS (SELECT FROM pg_attribute WHERE attrelid=to_regclass('public.'||e.tbl)
    AND attname=e.col AND attnum>0 AND NOT attisdropped
    AND format_type(atttypid,atttypmod)=e.typ AND attnotnull=e.nn
    AND attidentity='' AND attgenerated='') THEN
   RAISE EXCEPTION 'Column mismatch: %.%',e.tbl,e.col;
  END IF;
  SELECT pg_get_expr(d.adbin,d.adrelid) INTO actual_default FROM pg_attribute a
   LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
   WHERE a.attrelid=to_regclass('public.'||e.tbl) AND a.attname=e.col;
  IF e.def='uuid' AND COALESCE(actual_default,'') !~ '^(public\.|pg_catalog\.)?gen_random_uuid\(\)$'
    OR e.def='none' AND actual_default IS NOT NULL
    OR e.def NOT IN ('uuid','none','sequence') AND actual_default IS DISTINCT FROM e.def THEN
   RAISE EXCEPTION 'Default mismatch: %.%',e.tbl,e.col;
  END IF;
 END LOOP;
 FOR e IN SELECT * FROM (VALUES ('petugas_sync_mutations',5),('petugas_sync_outbox',8),('petugas_sync_publication',3)) AS v(tbl,n) LOOP
  IF (SELECT count(*) FROM pg_attribute WHERE attrelid=to_regclass('public.'||e.tbl) AND attnum>0 AND NOT attisdropped)<>e.n THEN
   RAISE EXCEPTION 'Unexpected columns: %',e.tbl;
  END IF;
 END LOOP;
 -- Definitions, not just the existence of familiar index names.
 FOR e IN SELECT * FROM (VALUES
  ('petugas','petugas_pkey',true,'id',''),
  ('petugas','petugas_uuid_unique',true,'uuid','uuidisnotnull'),
  ('petugas_sync_mutations','petugas_sync_mutations_pkey',true,'mutation_id',''),
  ('petugas_sync_mutations','petugas_sync_mutations_petugas_uuid_idx',false,'petugas_uuid',''),
  ('petugas_sync_outbox','petugas_sync_outbox_pkey',true,'id',''),
  ('petugas_sync_outbox','petugas_sync_outbox_publication_seq_key',true,'publication_seq',''),
  ('petugas_sync_outbox','petugas_sync_outbox_unpublished_idx',false,'id','publication_seqisnull'),
  ('petugas_sync_outbox','petugas_sync_outbox_publication_idx',false,'publication_seq','publication_seqisnotnull'),
  ('petugas_sync_publication','petugas_sync_publication_pkey',true,'id','')
 ) AS v(tbl,name,uniq,col,predicate) LOOP
  SELECT i.*,am.amname INTO idx FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
   JOIN pg_am am ON am.oid=c.relam WHERE i.indexrelid=to_regclass('public.'||e.name);
  IF NOT FOUND THEN RAISE EXCEPTION 'Missing index: %',e.name; END IF;
  IF idx.indrelid<>to_regclass('public.'||e.tbl) OR NOT idx.indisvalid OR NOT idx.indisready
    OR NOT idx.indimmediate OR idx.indisunique<>e.uniq OR idx.indnkeyatts<>1 OR idx.indnatts<>1
    OR idx.amname<>'btree' OR pg_get_indexdef(idx.indexrelid,1,true)<>e.col THEN
   RAISE EXCEPTION 'Incompatible index: %',e.name;
  END IF;
  pred:=lower(regexp_replace(COALESCE(pg_get_expr(idx.indpred,idx.indrelid),''),'[()[:space:]]','','g'));
  IF pred<>e.predicate AND NOT (e.name='petugas_uuid_unique' AND pred='') THEN
   RAISE EXCEPTION 'Index predicate mismatch: %',e.name;
  END IF;
 END LOOP;
 FOR e IN SELECT * FROM (VALUES
  ('petugas','petugas_pkey','p','id',''),
  ('petugas_sync_mutations','petugas_sync_mutations_pkey','p','mutation_id',''),
  ('petugas_sync_outbox','petugas_sync_outbox_pkey','p','id',''),
  ('petugas_sync_outbox','petugas_sync_outbox_publication_seq_key','u','publication_seq',''),
  ('petugas_sync_publication','petugas_sync_publication_pkey','p','id',''),
  ('petugas_sync_publication','petugas_sync_publication_id_check','c','id','id=1'),
  ('petugas_sync_publication','petugas_sync_publication_last_seq_check','c','last_seq','last_seq>=0'),
  ('petugas_sync_publication','petugas_sync_publication_check','c','min_cursor,last_seq','min_cursor>=0andmin_cursor<=last_seq')
 ) AS v(tbl,name,kind,col,expression) LOOP
  IF NOT EXISTS (SELECT FROM pg_constraint c WHERE c.conrelid=to_regclass('public.'||e.tbl)
    AND c.conname=e.name AND c.contype::text=e.kind AND c.convalidated AND NOT c.condeferrable
    AND (e.kind='c' AND lower(regexp_replace(pg_get_expr(c.conbin,c.conrelid),'[()[:space:]]','','g'))=e.expression
      OR e.kind<>'c' AND (SELECT string_agg(a.attname,',' ORDER BY k.n) FROM unnest(c.conkey) WITH ORDINALITY k(num,n)
         JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.num)=e.col)) THEN
   RAISE EXCEPTION 'Constraint mismatch: %',e.name;
  END IF;
 END LOOP;
 FOR e IN SELECT * FROM (VALUES ('petugas_sync_mutations',1),('petugas_sync_outbox',2),('petugas_sync_publication',4)) AS v(tbl,n) LOOP
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid=to_regclass('public.'||e.tbl) AND contype IN ('p','u','c','f','x'))<>e.n THEN
   RAISE EXCEPTION 'Unexpected constraints: %',e.tbl;
  END IF;
 END LOOP;
 seq:=to_regclass('public.petugas_sync_outbox_id_seq');
 IF seq IS NULL OR pg_get_serial_sequence('public.petugas_sync_outbox','id')::regclass IS DISTINCT FROM seq
   OR NOT EXISTS (SELECT FROM pg_class WHERE oid=seq AND relkind='S'
     AND relowner=(SELECT relowner FROM pg_class WHERE oid='public.petugas_sync_outbox'::regclass)) THEN
  RAISE EXCEPTION 'Sequence identity/owner mismatch';
 END IF;
 SELECT attnum INTO key_number FROM pg_attribute WHERE attrelid='public.petugas_sync_outbox'::regclass AND attname='id';
 IF (SELECT count(*) FROM pg_depend WHERE classid='pg_class'::regclass AND objid=seq AND deptype IN ('a','i'))<>1
   OR NOT EXISTS (SELECT FROM pg_depend WHERE classid='pg_class'::regclass AND objid=seq
     AND refclassid='pg_class'::regclass AND refobjid='public.petugas_sync_outbox'::regclass AND refobjsubid=key_number AND deptype='a')
   OR NOT EXISTS (SELECT FROM pg_sequence WHERE seqrelid=seq AND seqtypid='bigint'::regtype
     AND seqstart=1 AND seqincrement=1 AND seqmin=1 AND seqmax=9223372036854775807 AND seqcache=1 AND NOT seqcycle) THEN
  RAISE EXCEPTION 'Sequence ownership/dependency/definition mismatch';
 END IF;
 SELECT pg_get_expr(d.adbin,d.adrelid) INTO actual_default FROM pg_attrdef d
  WHERE d.adrelid='public.petugas_sync_outbox'::regclass AND d.adnum=key_number;
 IF actual_default IS DISTINCT FROM format('nextval(%L::regclass)',seq::text) THEN
  RAISE EXCEPTION 'Outbox sequence default mismatch';
 END IF;
 IF (SELECT array_agg(id ORDER BY id) FROM public.petugas) IS DISTINCT FROM ARRAY[101,102,103,104]::bigint[]
   OR (SELECT count(DISTINCT uuid) FROM public.petugas)<>4
   OR EXISTS (SELECT FROM public.petugas WHERE row_version<>1 OR deleted_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Existing Petugas identity/version mismatch';
 END IF;
 IF (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p)-ARRAY['uuid','row_version','deleted_at'] ORDER BY id)::text,'[]')) FROM public.petugas p)<>current_setting('notaris.petugas_hash')
   OR (SELECT md5(string_agg(id::text||':'||uuid::text,',' ORDER BY id)) FROM public.petugas)<>current_setting('notaris.uuid_hash')
   OR (SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]')) FROM public.transaksi t)<>current_setting('notaris.transaction_hash')
   OR (SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d)<>current_setting('notaris.detail_hash')
   OR (SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.transaksi_riwayat_pembayaran p)<>current_setting('notaris.payment_hash') THEN
  RAISE EXCEPTION 'Approved identity/data fingerprint changed';
 END IF;
 IF EXISTS (SELECT FROM public.petugas p WHERE jenis_kelamin IS NOT NULL AND NOT EXISTS(SELECT FROM public.jenis_kelamin g WHERE g.id=p.jenis_kelamin))
   OR EXISTS (SELECT FROM public.petugas p WHERE user_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.users u WHERE u.id=p.user_id)) THEN
  RAISE EXCEPTION 'Missing server reference';
 END IF;
 SELECT last_value,is_called INTO seq_state FROM public.petugas_sync_outbox_id_seq;
 IF (SELECT count(*) FROM public.petugas_sync_publication)<>1
   OR NOT EXISTS (SELECT FROM public.petugas_sync_publication WHERE id=1 AND last_seq=0 AND min_cursor=0)
   OR EXISTS (SELECT FROM public.petugas_sync_mutations) OR EXISTS (SELECT FROM public.petugas_sync_outbox)
   OR seq_state.last_value<>1 OR seq_state.is_called THEN
  RAISE EXCEPTION 'Pre-activation counter/journal/sequence state changed';
 END IF;
 FOR e IN SELECT * FROM (VALUES
  ('petugas_sync_mutations',ARRAY['SELECT','INSERT']::text[]),
  ('petugas_sync_outbox',ARRAY['SELECT','INSERT','UPDATE']::text[]),
  ('petugas_sync_publication',ARRAY['SELECT','UPDATE']::text[])
 ) AS v(tbl,allowed) LOOP
  FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
   IF (NOT privilege_name=ANY(e.allowed) AND has_table_privilege(app,'public.'||e.tbl,privilege_name))
      OR has_table_privilege(app,'public.'||e.tbl,privilege_name||' WITH GRANT OPTION') THEN
    RAISE EXCEPTION 'Unexpected application privilege/grant option: % %',e.tbl,privilege_name;
   END IF;
  END LOOP;
  IF current_setting('server_version_num')::integer>=170000 THEN
   IF has_table_privilege(app,'public.'||e.tbl,'MAINTAIN') THEN
    RAISE EXCEPTION 'Unexpected application MAINTAIN privilege: %',e.tbl;
   END IF;
  END IF;
 END LOOP;
 IF has_sequence_privilege(app,seq,'UPDATE') OR has_sequence_privilege(app,seq,'SELECT WITH GRANT OPTION')
    OR has_sequence_privilege(app,seq,'USAGE WITH GRANT OPTION') THEN
  RAISE EXCEPTION 'Unexpected application sequence privilege/grant option';
 END IF;
END $$;
