#!/usr/bin/env bash
# Runs the activity moderation database tests on a throwaway local
# Postgres database (never the Supabase project).
#
#   PGHOST=localhost PGPORT=5432 PGUSER=postgres ./supabase/tests/activity_moderation/run.sh
#
# Needs a local Postgres 15+ server where you can create databases.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
db="synk_activity_moderation_test"
run() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

run -d postgres -c "drop database if exists $db"
run -d postgres -c "create database $db"
trap 'run -d postgres -c "drop database if exists $db"' EXIT

# Roles belong to the whole server, so create them only when missing.
run -d "$db" -c "do \$\$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end \$\$;"
run -d "$db" -f <(grep -v '^create role ' "$here/stub.sql") >/dev/null

migration="$root/supabase/migrations/20261112100000_activity_save_requests.sql"
run -d "$db" -f "$migration" >/dev/null
run -d "$db" -f "$migration" >/dev/null
echo "ok: migration applies, and again"

cd "$here"
for test_file in test_save_requests.sql test_lockdown.sql; do
  if ! output="$(run -d "$db" -f "$test_file" 2>&1)"; then
    printf '%s\n' "$output" | grep -E 'NOTICE:  ok|ERROR|CONTEXT' | sed 's/.*NOTICE:  //'
    echo "FAILED: $test_file"
    exit 1
  fi
  printf '%s\n' "$output" | sed -n 's/.*NOTICE:  \(ok:.*\)/\1/p'
done

run -d "$db" -f "$root/supabase/manual/activity_moderation/phase1_rollback.sql" >/dev/null
run -d "$db" -c "do \$\$ begin
  assert to_regclass('private.activity_save_requests') is null, 'table removed';
  assert not exists (select 1 from information_schema.columns
    where table_name = 'activities' and column_name = 'edit_version'), 'column removed';
end \$\$;"
echo "ok: phase 1 rollback removes what the migration added"
echo "ALL DATABASE TESTS PASSED"
