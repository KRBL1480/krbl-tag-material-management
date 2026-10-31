-- KRBL Digital Equipment workflow migration (safe / additive)
-- Run this in Supabase SQL Editor for project sbshldtfvvuuluyeedtv.
-- Does not delete or alter Tag Material Management records.
begin;

alter table public.krbl_equipment_transactions
  add column if not exists receipt_source text,
  add column if not exists supplier_name text,
  add column if not exists po_number text,
  add column if not exists invoice_number text,
  add column if not exists source_plant text,
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by uuid references auth.users(id),
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references auth.users(id),
  add column if not exists void_reason text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='krbl_equipment_receipt_source_check') then
    alter table public.krbl_equipment_transactions
      add constraint krbl_equipment_receipt_source_check
      check (receipt_source is null or receipt_source in ('head_office','store_purchase','dh01_transfer'));
  end if;
end $$;

-- Existing legacy receipts are classified as Head Office so their quantities remain in stock.
update public.krbl_equipment_transactions
set receipt_source='head_office'
where transaction_type='receive' and receipt_source is null;

create index if not exists krbl_equipment_tx_receipt_source
  on public.krbl_equipment_transactions(receipt_source, transaction_date desc);

-- Admin update permission is required for Edit and Cancel transaction actions.
drop policy if exists krbl_equipment_admin_update on public.krbl_equipment_transactions;
create policy krbl_equipment_admin_update
on public.krbl_equipment_transactions
for update to authenticated
using (exists (
  select 1 from public.krbl_user_roles r
  where r.user_id=(select auth.uid()) and r.role='admin'
))
with check (exists (
  select 1 from public.krbl_user_roles r
  where r.user_id=(select auth.uid()) and r.role='admin'
));

commit;

-- Verify the expected columns and policy are present.
select column_name
from information_schema.columns
where table_schema='public'
  and table_name='krbl_equipment_transactions'
  and column_name in ('receipt_source','supplier_name','po_number','invoice_number','source_plant','updated_at','updated_by','voided_at','voided_by','void_reason')
order by column_name;

select policyname, cmd
from pg_policies
where schemaname='public'
  and tablename='krbl_equipment_transactions'
order by policyname;
-- Transfer-out support: records stock sent from Company Store to another plant/location.
alter table public.krbl_equipment_transactions
  add column if not exists transfer_destination text;

-- Expand the transaction type constraint without deleting existing transactions.
do $$
declare
  con record;
begin
  for con in
    select conname from pg_constraint
    where conrelid='public.krbl_equipment_transactions'::regclass
      and contype='c'
      and pg_get_constraintdef(oid) ilike '%transaction_type%'
  loop
    execute format('alter table public.krbl_equipment_transactions drop constraint %I', con.conname);
  end loop;
  alter table public.krbl_equipment_transactions
    add constraint krbl_equipment_transaction_type_check
    check (transaction_type in ('receive','issue','return','transfer_out'));
end $$;

create index if not exists krbl_equipment_tx_transfer_destination
  on public.krbl_equipment_transactions(transfer_destination, transaction_date desc);

-- Verify transfer-out schema is available.
select column_name from information_schema.columns
where table_schema='public' and table_name='krbl_equipment_transactions'
  and column_name='transfer_destination';
select pg_get_constraintdef(oid) as transaction_type_rule
from pg_constraint
where conrelid='public.krbl_equipment_transactions'::regclass
  and conname='krbl_equipment_transaction_type_check';
