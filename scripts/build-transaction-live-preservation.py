"""Generate read-only preservation queries for exactly the reviewed fixture UUIDs."""
import json,re,sys
from pathlib import Path
p=Path(sys.argv[1]);plan=json.loads((p/'fixture-plan.json').read_text());filters={};collisions=[]
for domain,e in plan['entities'].items():
 if domain not in ('notaris','ppat'):raise SystemExit('Invalid domain')
 for k in ('master_uuid','price_uuid','process_uuid','attribute_uuid','transaction_uuid','detail_uuid','transaction_process_uuid','payment_uuid'):
  if not re.fullmatch('[0-9a-f-]{36}',e[k]):raise SystemExit('Invalid fixture UUID')
 parent=f"SELECT id FROM pekerjaan_{domain} WHERE uuid='{e['master_uuid']}'::uuid"
 filters['pekerjaan_'+domain]=f"t.uuid<>'{e['master_uuid']}'::uuid"
 for suffix in ('harga','proses','atributs'):filters[f'pekerjaan_{domain}_{suffix}']=f't.pekerjaan_{domain}_id NOT IN ({parent})'
 filters[f'pekerjaan_{domain}_sync_atribut']=f"t.uuid<>'{e['attribute_uuid']}'::uuid"
 filters[f'pekerjaan_{domain}_sync_mutation']=f"t.acknowledgement->>'uuid'<>'{e['master_uuid']}'"
 filters[f'pekerjaan_{domain}_sync_outbox']=f"t.aggregate_uuid<>'{e['master_uuid']}'::uuid"
 for suffix,key in [('', 'master_uuid'),('_harga','price_uuid'),('_proses','process_uuid'),('_sync_atribut','attribute_uuid')]:collisions.append(f"(SELECT count(*) FROM pekerjaan_{domain}{suffix} WHERE uuid='{e[key]}'::uuid)")
uuids=','.join("'"+e['transaction_uuid']+"'::uuid" for e in plan['entities'].values());ids=f'SELECT id FROM transaction_cloud WHERE uuid IN ({uuids})'
filters.update(transaction_cloud=f't.uuid NOT IN ({uuids})',transaction_cloud_detail=f't.transaction_id NOT IN ({ids})',transaction_cloud_process=f't.detail_uuid NOT IN (SELECT uuid FROM transaction_cloud_detail WHERE transaction_id IN ({ids}))',transaction_cloud_payment=f't.transaction_id NOT IN ({ids})',transaction_cloud_mutation="(t.acknowledgement->>'uuid')::uuid NOT IN ("+uuids+')',transaction_cloud_outbox=f't.aggregate_uuid NOT IN ({uuids})',transaction_cloud_number_counter="t.domain NOT IN ('notaris','ppat')")
for table,key in [('transaction_cloud','transaction_uuid'),('transaction_cloud_detail','detail_uuid'),('transaction_cloud_process','transaction_process_uuid'),('transaction_cloud_payment','payment_uuid')]:
 for e in plan['entities'].values():collisions.append(f"(SELECT count(*) FROM {table} WHERE uuid='{e[key]}'::uuid)")
q=lambda s:"'"+s.replace("'","''")+"'"
where='CASE tablename '+''.join('WHEN '+q(t)+' THEN '+q(w)+' ' for t,w in filters.items())+"ELSE 'true' END"
pubs="'pekerjaan_notaris_sync_publication','pekerjaan_ppat_sync_publication','transaction_cloud_publication'"
projection=f"CASE WHEN tablename IN ({pubs}) THEN 'to_jsonb(t)-''last_seq''' ELSE 'to_jsonb(t)' END"
sql="\\pset format unaligned\n\\pset tuples_only on\nBEGIN READ ONLY;\nSET LOCAL TimeZone='UTC';\nSELECT jsonb_build_object('approved_collisions',"+'+'.join(collisions)+")::text;\n"
sql+=f"SELECT format('SELECT jsonb_build_object(''table'',%L,''count'',count(*),''hash'',md5(coalesce(string_agg((%s)::text,E''\\n'' ORDER BY (%s)::text),'''')))::text FROM public.%I t WHERE %s;',tablename,{projection},{projection},tablename,{where}) FROM pg_tables WHERE schemaname='public' ORDER BY tablename \\gexec\nROLLBACK;\n"
(p/'preservation.sql').write_text(sql,encoding='utf-8')
