-- KRBL Digital Equipment: controlled edit and cancel (soft-delete) support.
-- Run once in the same KRBL Supabase project. Existing transactions are preserved.
alter table public.krbl_equipment_transactions
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by uuid references auth.users(id),
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references auth.users(id),
  add column if not exists void_reason text;

drop policy if exists krbl_equipment_admin_update on public.krbl_equipment_transactions;
create policy krbl_equipment_admin_update
on public.krbl_equipment_transactions
for update to authenticated
using (exists (select 1 from public.krbl_user_roles r where r.user_id=(select auth.uid()) and r.role='admin'))
with check (exists (select 1 from public.krbl_user_roles r where r.user_id=(select auth.uid()) and r.role='admin'));

create table if not exists public.krbl_equipment_audit_log (
  id bigint generated always as identity primary key,
  transaction_id bigint not null,
  action text not null check (action in ('UPDATE','CANCEL')),
  old_data jsonb not null,
  new_data jsonb not null,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now()
);
alter table public.krbl_equipment_audit_log enable row level security;
drop policy if exists krbl_equipment_audit_admin_read on public.krbl_equipment_audit_log;
create policy krbl_equipment_audit_admin_read
on public.krbl_equipment_audit_log for select to authenticated
using (exists (select 1 from public.krbl_user_roles r where r.user_id=(select auth.uid()) and r.role='admin'));

create or replace function public.krbl_equipment_audit_fn()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.krbl_equipment_audit_log(transaction_id,action,old_data,new_data,changed_by)
  values (old.id,
    case when new.voided_at is not null and old.voided_at is null then 'CANCEL' else 'UPDATE' end,
    to_jsonb(old),to_jsonb(new),auth.uid());
  return new;
end;
$$;
drop trigger if exists krbl_equipment_audit_trigger on public.krbl_equipment_transactions;
create trigger krbl_equipment_audit_trigger
after update on public.krbl_equipment_transactions
for each row execute function public.krbl_equipment_audit_fn();
