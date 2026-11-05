-- KRBL Digital Equipment: secure admin-only reset of equipment and Excel reference rows.
-- Preserves authentication users, KRBL roles, and unrelated application modules.
-- Run this SQL once in the linked Supabase project's SQL Editor.

create or replace function public.krbl_clear_equipment_transactions()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receive_deleted integer := 0;
  v_issue_deleted integer := 0;
  v_return_deleted integer := 0;
  v_transfer_deleted integer := 0;
  v_cancelled_deleted integer := 0;
  v_transactions_deleted integer := 0;
  v_audit_deleted integer := 0;
  v_excel_rows_deleted integer := 0;
  v_excel_balance_deleted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.krbl_user_roles
    where user_id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Admin access required';
  end if;

  -- All movement types are stored in one equipment transaction table.
  -- Count each type first so the result proves what was removed.
  select count(*) into v_receive_deleted from public.krbl_equipment_transactions where transaction_type='receive';
  select count(*) into v_issue_deleted from public.krbl_equipment_transactions where transaction_type='issue';
  select count(*) into v_return_deleted from public.krbl_equipment_transactions where transaction_type='return';
  select count(*) into v_transfer_deleted from public.krbl_equipment_transactions where transaction_type='transfer_out';
  select count(*) into v_cancelled_deleted from public.krbl_equipment_transactions where voided_at is not null;

  -- Clear all equipment movement rows, including cancelled rows.
  delete from public.krbl_equipment_transactions where true;
  get diagnostics v_transactions_deleted = row_count;

  -- Clear the equipment audit history and both Excel reference/import tables.
  delete from public.krbl_equipment_audit_log where true;
  get diagnostics v_audit_deleted = row_count;

  delete from public.krbl_equipment_excel_import where true;
  get diagnostics v_excel_rows_deleted = row_count;

  delete from public.krbl_equipment_excel_balance_check where true;
  get diagnostics v_excel_balance_deleted = row_count;

  return jsonb_build_object(
    'receive_deleted', v_receive_deleted,
    'issue_deleted', v_issue_deleted,
    'return_deleted', v_return_deleted,
    'transfer_out_deleted', v_transfer_deleted,
    'cancelled_deleted', v_cancelled_deleted,
    'transactions_deleted', v_transactions_deleted,
    'audit_rows_deleted', v_audit_deleted,
    'excel_import_rows_deleted', v_excel_rows_deleted,
    'excel_balance_rows_deleted', v_excel_balance_deleted,
    'status', 'cleared'
  );
end;
$$;

revoke all on function public.krbl_clear_equipment_transactions() from public;
grant execute on function public.krbl_clear_equipment_transactions() to authenticated;
