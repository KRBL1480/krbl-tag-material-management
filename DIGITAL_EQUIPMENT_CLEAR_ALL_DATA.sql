-- KRBL Digital Equipment Register: fresh start / clear all current equipment data.
-- IMPORTANT: This permanently clears equipment transactions (including test/cancelled rows),
-- imported Excel archive rows, opening-balance comparison rows, and their audit log.
-- It does NOT touch White Roll / Black Ribbon tag-material tables or user accounts/roles.
begin;

delete from public.krbl_equipment_audit_log;
delete from public.krbl_equipment_transactions;
delete from public.krbl_equipment_excel_import;
delete from public.krbl_equipment_excel_balance_check;

commit;

-- Verification: all four counts should be 0.
select 'equipment_transactions' as table_name, count(*) as remaining_rows from public.krbl_equipment_transactions
union all
select 'equipment_audit_log', count(*) from public.krbl_equipment_audit_log
union all
select 'equipment_excel_import', count(*) from public.krbl_equipment_excel_import
union all
select 'equipment_excel_balance_check', count(*) from public.krbl_equipment_excel_balance_check;
