# Read-only source review and SCHEMA-ONLY archive. Never creates/restores a DB.
param([string]$PostgresBin = 'D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$settings = @{}
foreach ($line in Get-Content (Join-Path $repo 'backend-notaris-go/.env')) {
    if ($line -match '^\s*(DB_[A-Z_]+)\s*=\s*(.*)$') { $settings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'") }
}
$previous = @{}
foreach ($key in @('PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT')) { $previous[$key] = [Environment]::GetEnvironmentVariable($key) }
$root = Join-Path $repo ('.local/notarisdev-review-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$sql = @'
SELECT json_build_object(
 'source',current_database(),'read_only',current_setting('transaction_read_only'),
 'bytes',pg_database_size(current_database()),
 'target_exists',EXISTS(SELECT 1 FROM pg_database WHERE datname='notarisdev'),
 'table_count',(SELECT count(*) FROM pg_tables WHERE schemaname='public'),
 'extensions',(SELECT json_agg(extname ORDER BY extname) FROM pg_extension),
 'schema_fingerprint',(SELECT md5(string_agg(def,E'\n' ORDER BY def)) FROM (
   SELECT row_to_json(c)::text AS def FROM information_schema.columns c WHERE table_schema='public'
   UNION ALL SELECT indexdef FROM pg_indexes WHERE schemaname='public'
   UNION ALL SELECT conrelid::regclass::text||conname||pg_get_constraintdef(oid) FROM pg_constraint WHERE connamespace='public'::regnamespace
   UNION ALL SELECT schemaname||viewname||definition FROM pg_views WHERE schemaname='public'
   UNION ALL SELECT pg_get_functiondef(oid) FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind IN ('f','p')
   UNION ALL SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace)
   UNION ALL SELECT row_to_json(s)::text FROM information_schema.sequences s WHERE sequence_schema='public'
 ) definitions));
'@
try {
    $env:PGPASSWORD = $settings['DB_PASSWORD']
    $env:PGOPTIONS = '-c default_transaction_read_only=on'
    $env:PGCONNECT_TIMEOUT = '5'
    $connection = @('-h','localhost','-p','5432','-U',$settings['DB_USER'],'-d','notarislokal','-w')
    $before = & (Join-Path $PostgresBin 'psql.exe') -X @connection -Atc $sql
    if ($LASTEXITCODE) { throw 'Read-only discovery failed' }
    $before | Set-Content (Join-Path $root 'metadata-before.json')
    $columns = & (Join-Path $PostgresBin 'psql.exe') -X @connection -Atc "SELECT json_agg(c ORDER BY table_name,ordinal_position) FROM (SELECT table_name,column_name,ordinal_position,data_type,is_nullable,character_maximum_length,column_default FROM information_schema.columns WHERE table_schema='public') c;"
    if ($LASTEXITCODE) { throw 'Column inventory failed' }
    $columns | Set-Content (Join-Path $root 'columns.json')
    $countSql = & (Join-Path $PostgresBin 'psql.exe') -X @connection -Atc "SELECT 'SELECT json_agg(c ORDER BY table_name) FROM (' || string_agg(format('SELECT %L AS table_name, count(*) AS rows FROM %I.%I',tablename,schemaname,tablename),' UNION ALL ' ORDER BY tablename) || ') c;' FROM pg_tables WHERE schemaname='public';"
    if ($LASTEXITCODE) { throw 'Count query preparation failed' }
    $counts = & (Join-Path $PostgresBin 'psql.exe') -X @connection -Atc $countSql
    if ($LASTEXITCODE) { throw 'Read-only table counts failed' }
    $counts | Set-Content (Join-Path $root 'table-counts.json')
    & (Join-Path $PostgresBin 'pg_dump.exe') @connection --schema-only --format=custom --no-owner --no-privileges --file (Join-Path $root 'source-schema.dump')
    if ($LASTEXITCODE) { throw 'Schema-only pg_dump failed' }
    & (Join-Path $PostgresBin 'pg_restore.exe') --list (Join-Path $root 'source-schema.dump') | Set-Content (Join-Path $root 'archive-list.txt')
    if ($LASTEXITCODE) { throw 'Archive listing validation failed' }
    $after = & (Join-Path $PostgresBin 'psql.exe') -X @connection -Atc $sql
    if ($LASTEXITCODE) { throw 'Post-backup source check failed' }
    $after | Set-Content (Join-Path $root 'metadata-after.json')
    if (($before | ConvertFrom-Json).schema_fingerprint -ne ($after | ConvertFrom-Json).schema_fingerprint) { throw 'Source schema changed during review; do not proceed' }
    Get-FileHash (Join-Path $root 'source-schema.dump') | Select-Object Algorithm,Hash | ConvertTo-Json | Set-Content (Join-Path $root 'archive-sha256.json')
    Write-Output "Read-only schema archive verified (NOT a data backup): $root"
    Write-Output 'No database was created or restored. Source structural fingerprint unchanged.'
} finally {
    foreach ($key in $previous.Keys) {
        if ($null -eq $previous[$key]) { Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($key, $previous[$key]) }
    }
}
