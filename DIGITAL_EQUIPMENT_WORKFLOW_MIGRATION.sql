-- KRBL Equipment Register workflow migration
-- Additive only: preserves existing equipment rows and all Tag Material data.
begin;
alter table public.krbl_equipment_transactions
 add column if not exists receipt_source text,
 add column if not exists supplier_name text,
 add column if not exists po_number text,
 add column if not exists invoice_number text,
 add column if not exists source_plant text;
do $$
begin
 if not exists(select 1 from pg_constraint where conname='krbl_equipment_receipt_source_check') then
  alter table public.krbl_equipment_transactions add constraint krbl_equipment_receipt_source_check
  check(receipt_source is null or receipt_source in ('head_office','store_purchase','dh01_transfer'));
 end if;
end $$;
create index if not exists krbl_equipment_tx_receipt_source on public.krbl_equipment_transactions(receipt_source,transaction_date desc);
commit;
select column_name,data_type from information_schema.columns where table_schema='public' and table_name='krbl_equipment_transactions' and column_name in ('receipt_source','supplier_name','po_number','invoice_number','source_plant') order by column_name;