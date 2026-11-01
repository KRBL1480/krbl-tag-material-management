-- KRBL Digital Equipment Management: READ-ONLY schema inventory
-- Safe to run in Supabase SQL Editor. This script does NOT create, update or delete anything.
-- Export each result grid as CSV and keep it with your JSON data backup.

-- 1) Tables and estimated row counts
select schemaname, tablename, n_live_tup as estimated_rows
from pg_stat_user_tables
where schemaname = 'public'
  and (tablename like 'krbl_equipment_%' or tablename = 'krbl_user_roles')
order by tablename;

-- 2) Columns, types, defaults and nullability
select table_name, ordinal_position, column_name, data_type, udt_name,
       is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and (table_name like 'krbl_equipment_%' or table_name = 'krbl_user_roles')
order by table_name, ordinal_position;

-- 3) Primary keys, foreign keys, unique and check constraints
select tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name, ccu.table_name as foreign_table_name,
       ccu.column_name as foreign_column_name, cc.check_clause
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on tc.constraint_schema = kcu.constraint_schema
 and tc.table_name = kcu.table_name
 and tc.constraint_name = kcu.constraint_name
left join information_schema.constraint_column_usage ccu
  on tc.constraint_schema = ccu.constraint_schema
 and tc.table_name = ccu.table_name
 and tc.constraint_name = ccu.constraint_name
left join information_schema.check_constraints cc
  on tc.constraint_schema = cc.constraint_schema
 and tc.constraint_name = cc.constraint_name
where tc.table_schema = 'public'
  and (tc.table_name like 'krbl_equipment_%' or tc.table_name = 'krbl_user_roles')
order by tc.table_name, tc.constraint_name;

-- 4) Index definitions
select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and (tablename like 'krbl_equipment_%' or tablename = 'krbl_user_roles')
order by tablename, indexname;

-- 5) Row Level Security status
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and (c.relname like 'krbl_equipment_%' or c.relname = 'krbl_user_roles')
order by c.relname;

-- 6) RLS policies
select schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and (tablename like 'krbl_equipment_%' or tablename = 'krbl_user_roles')
order by tablename, policyname;

-- 7) Triggers and trigger definitions
select event_object_table as table_name, trigger_name, event_manipulation,
       action_timing, action_orientation, action_statement
from information_schema.triggers
where trigger_schema = 'public'
  and (event_object_table like 'krbl_equipment_%' or event_object_table = 'krbl_user_roles')
order by event_object_table, trigger_name;

-- 8) Custom functions used by the equipment module
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname like 'krbl_equipment_%' or p.proname like 'krbl_user_%')
order by p.proname;
