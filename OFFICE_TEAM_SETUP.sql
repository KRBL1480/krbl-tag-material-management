-- KRBL Office / Team access foundation. Run in Supabase SQL Editor as project owner.
-- Back up database first. Does not delete existing material records.
create table if not exists public.krbl_team_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  employee_id text unique,
  department text,
  area text not null default 'team' check (area in ('office','team')),
  mandi_code text,
  mandi_name text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.krbl_activity_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity text,
  entity_id text,
  mandi_code text,
  old_data jsonb,
  new_data jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists krbl_activity_actor_time on public.krbl_activity_log(actor_id,occurred_at desc);
create index if not exists krbl_activity_time on public.krbl_activity_log(occurred_at desc);
create or replace function public.krbl_is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.krbl_user_roles where user_id=(select auth.uid()) and role='admin') $$;
revoke all on function public.krbl_is_admin() from public;
grant execute on function public.krbl_is_admin() to authenticated;
alter table public.krbl_team_profiles enable row level security;
alter table public.krbl_activity_log enable row level security;
drop policy if exists krbl_profiles_read on public.krbl_team_profiles;
create policy krbl_profiles_read on public.krbl_team_profiles for select to authenticated
using (user_id=(select auth.uid()) or public.krbl_is_admin());
drop policy if exists krbl_profiles_admin_insert on public.krbl_team_profiles;
create policy krbl_profiles_admin_insert on public.krbl_team_profiles for insert to authenticated with check (public.krbl_is_admin());
drop policy if exists krbl_profiles_admin_update on public.krbl_team_profiles;
create policy krbl_profiles_admin_update on public.krbl_team_profiles for update to authenticated
using (public.krbl_is_admin()) with check (public.krbl_is_admin());
drop policy if exists krbl_profiles_admin_delete on public.krbl_team_profiles;
create policy krbl_profiles_admin_delete on public.krbl_team_profiles for delete to authenticated using (public.krbl_is_admin());
drop policy if exists krbl_activity_admin_read on public.krbl_activity_log;
create policy krbl_activity_admin_read on public.krbl_activity_log for select to authenticated using (public.krbl_is_admin());
-- Audit material record writes inside database so client cannot falsify the actor.
create or replace function public.krbl_material_audit()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare oldrow jsonb; newrow jsonb; rec_id text; mcode text;
begin
  if tg_op <> 'INSERT' then oldrow=to_jsonb(old); end if;
  if tg_op <> 'DELETE' then newrow=to_jsonb(new); end if;
  rec_id=coalesce(newrow->>'id',oldrow->>'id');
  mcode=coalesce(newrow->>'mandi_code',oldrow->>'mandi_code');
  insert into public.krbl_activity_log(actor_id,action,entity,entity_id,mandi_code,old_data,new_data)
  values ((select auth.uid()),lower(tg_op),tg_table_name,rec_id,mcode,oldrow,newrow);
  return case when tg_op='DELETE' then old else new end;
end $$;
drop trigger if exists krbl_audit_receipts on public.krbl_material_receipts;
create trigger krbl_audit_receipts after insert or update or delete on public.krbl_material_receipts
for each row execute function public.krbl_material_audit();
drop trigger if exists krbl_audit_issues on public.krbl_mandi_issues;
create trigger krbl_audit_issues after insert or update or delete on public.krbl_mandi_issues
for each row execute function public.krbl_material_audit();
-- NOTE: Team write RLS must be configured separately after inspecting existing table policies.
-- Never put service_role credentials in GitHub Pages / client-side JavaScript.
