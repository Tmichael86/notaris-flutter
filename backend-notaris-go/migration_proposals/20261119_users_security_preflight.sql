-- Read-only review. Any returned anomaly blocks migration. Never repair automatically.
BEGIN TRANSACTION READ ONLY;
SELECT lower(btrim(username)) AS identity,count(*) FROM users
 GROUP BY lower(btrim(username)) HAVING count(*)>1 OR lower(btrim(username)) IS NULL OR lower(btrim(username))='';
SELECT lower(btrim(email)) AS identity,count(*) FROM users
 GROUP BY lower(btrim(email)) HAVING count(*)>1 OR lower(btrim(email)) IS NULL OR lower(btrim(email))='';
SELECT u.id,v.id FROM users u JOIN users v ON lower(btrim(u.username))=lower(btrim(v.email)) AND u.id<>v.id;
SELECT group_id,sidebar_id,count(*) FROM sidebar_akses GROUP BY group_id,sidebar_id HAVING count(*)>1;
SELECT sidebar_kode,count(*) FROM sidebar GROUP BY sidebar_kode
 HAVING count(*)>1 OR sidebar_kode IS NULL OR btrim(sidebar_kode)='';
SELECT u.id FROM users u LEFT JOIN groups g ON g.id=u.group_id
 WHERE g.id IS NULL OR u.status IS NULL OR u.status NOT IN(0,1);
SELECT id FROM groups WHERE status IS NULL OR status NOT IN(0,1) OR group_jenis IS NULL OR group_jenis NOT IN('user','superadmin');
SELECT id FROM sidebar WHERE status IS NULL OR status NOT IN(0,1) OR sidebar_route IS NULL;
SELECT a.id FROM sidebar_akses a LEFT JOIN groups g ON g.id=a.group_id
 LEFT JOIN sidebar s ON s.id=a.sidebar_id WHERE g.id IS NULL OR s.id IS NULL
 OR a."read" IS NULL OR a."create" IS NULL OR a."update" IS NULL OR a."delete" IS NULL
 OR a."read" NOT IN(0,1) OR a."create" NOT IN(0,1) OR a."update" NOT IN(0,1) OR a."delete" NOT IN(0,1);
SELECT table_name,column_name FROM information_schema.columns WHERE table_schema=current_schema()
 AND ((table_name='users' AND column_name IN('revision','security_version'))
 OR (table_name='groups' AND column_name='revision'));
SELECT tablename FROM pg_tables WHERE schemaname=current_schema() AND tablename='administrative_audit';
ROLLBACK;
