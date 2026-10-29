-- KRBL Digital Equipment Management (separate from tag consumables)
-- Safe additive setup: creates new tables only; does not modify existing tag, receipt, issue or balance records.
create table if not exists public.krbl_equipment_transactions (
  id bigint generated always as identity primary key,
  transaction_date date not null default current_date,
  transaction_type text not null check (transaction_type in ('receive','issue','return')),
  item_name text not null check (item_name in ('Zebra Printer','HHT Device','Charger Cable','Cutter','Connector Cable')),
  quantity integer not null check (quantity > 0),
  mandi_code text,
  mandi_name text,
  person text,
  reference text,
  remarks text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists krbl_equipment_tx_date on public.krbl_equipment_transactions(transaction_date desc);
create index if not exists krbl_equipment_tx_item on public.krbl_equipment_transactions(item_name, transaction_type);
alter table public.krbl_equipment_transactions enable row level security;
drop policy if exists krbl_equipment_admin_read on public.krbl_equipment_transactions;
create policy krbl_equipment_admin_read on public.krbl_equipment_transactions for select to authenticated
using (exists (select 1 from public.krbl_user_roles r where r.user_id=(select auth.uid()) and r.role='admin'));
drop policy if exists krbl_equipment_admin_insert on public.krbl_equipment_transactions;
create policy krbl_equipment_admin_insert on public.krbl_equipment_transactions for insert to authenticated
with check (created_by=(select auth.uid()) and exists (select 1 from public.krbl_user_roles r where r.user_id=(select auth.uid()) and r.role='admin'));
-- Intentionally no update/delete policies: transaction history is append-only for this first version.
