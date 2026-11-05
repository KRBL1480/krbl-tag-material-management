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
  v_transactions_deleted integer := 0;
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

  -- The dashboard requires password re-entry before calling this RPC.
  -- Enforce the admin role here; auth_time is not reliable for password re-entry
  -- when Supabase reuses an existing browser session.
  -- Clear equipment transactions and both Excel reference/import tables.
  -- Keep authentication users, KRBL roles, and unrelated application data.
  delete from public.krbl_equipment_transactions;
  get diagnostics v_transactions_deleted = row_count;

  delete from public.krbl_equipment_excel_import;
  get diagnostics v_excel_rows_deleted = row_count;

  delete from public.krbl_equipment_excel_balance_check;
  get diagnostics v_excel_balance_deleted = row_count;

  return jsonb_build_object(
    'transactions_deleted', v_transactions_deleted,
    'excel_import_rows_deleted', v_excel_rows_deleted,
    'excel_balance_rows_deleted', v_excel_balance_deleted,
    'status', 'cleared'
  );
end;
$$;

revoke all on function public.krbl_clear_equipment_transactions() from public;
grant execute on function public.krbl_clear_equipment_transactions() to authenticated;
