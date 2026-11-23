-- Connection/maintenance assertion only; no persistent objects or data writes.
-- Included before EACH phase by the reviewed psql entry point.
DO $$
DECLARE owner_name text;
BEGIN
  IF current_database() IS DISTINCT FROM 'notarisdev'
     OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR inet_server_port() IS DISTINCT FROM current_setting('notaris.review_port')::integer
     OR (SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1)
        IS DISTINCT FROM 'NOTARISDEV SYNTHETIC v1' THEN
    RAISE EXCEPTION 'Development target identity changed';
  END IF;
  SELECT pg_get_userbyid(relowner) INTO owner_name
    FROM pg_class WHERE oid='public.petugas'::regclass;
  IF current_user = current_setting('notaris.review_app_role')
     OR NOT pg_has_role(current_user, owner_name, 'USAGE')
     OR NOT has_schema_privilege(current_user,'public','CREATE') THEN
    RAISE EXCEPTION 'Separate provisioning account with table ownership and schema CREATE required';
  END IF;
  IF EXISTS (SELECT FROM pg_stat_activity WHERE datname=current_database()
      AND backend_type='client backend' AND pid<>pg_backend_pid()) THEN
    RAISE EXCEPTION 'Maintenance changed: another target session is connected';
  END IF;
END $$;
