-- KRBL Digital Equipment: secure admin-only clear of transaction rows.
-- Deletes ONLY equipment transaction rows. Excel reference/import, users, roles,
-- tag-material data, and the audit log are deliberately preserved.
-- Run this SQL once in the linked Supabase project's SQL Editor.

create or replace function public.krbl_clear_equipment_transactions()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer := 0;
  v_auth_time bigint := 0;
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

  v_auth_time := coalesce((auth.jwt() ->> 'auth_time')::bigint, 0);
  if v_auth_time < extract(epoch from (now() - interval '5 minutes'))::bigint then
    raise exception 'Please re-enter your password immediately before clearing data';
  end if;

  delete from public.krbl_equipment_transactions;
  get diagnostics v_deleted = row_count;

  return jsonb_build_object('deleted_rows', v_deleted, 'status', 'cleared');
end;
$$;

revoke all on function public.krbl_clear_equipment_transactions() from public;
grant execute on function public.krbl_clear_equipment_transactions() to authenticated;
