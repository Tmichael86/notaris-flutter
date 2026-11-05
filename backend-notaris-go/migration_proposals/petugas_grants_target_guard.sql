-- Grants-only needs object ownership/read access, not schema CREATE or DDL.
DO $$
BEGIN
 IF current_database() IS DISTINCT FROM 'notarisdev'
   OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
   OR inet_server_port() IS DISTINCT FROM current_setting('notaris.review_port')::integer
   OR (SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1)
      IS DISTINCT FROM 'NOTARISDEV SYNTHETIC v1' THEN
  RAISE EXCEPTION 'Grants-only development target identity mismatch';
 END IF;
 IF current_user=current_setting('notaris.review_app_role') THEN
  RAISE EXCEPTION 'Separate provisioning account required';
 END IF;
 IF EXISTS (SELECT FROM pg_stat_activity WHERE datname=current_database()
     AND backend_type='client backend' AND pid<>pg_backend_pid()) THEN
  RAISE EXCEPTION 'Maintenance changed: another target session is connected';
 END IF;
END $$;
