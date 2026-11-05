-- KRBL Digital Equipment: allow admins to edit equipment transactions.
-- Run once in the same Supabase project used by digital-equipment.html.

alter table public.krbl_equipment_transactions enable row level security;

drop policy if exists krbl_equipment_admin_update on public.krbl_equipment_transactions;

create policy krbl_equipment_admin_update
on public.krbl_equipment_transactions
for update
to authenticated
using (
  exists (
    select 1
    from public.krbl_user_roles r
    where r.user_id = (select auth.uid())
      and r.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.krbl_user_roles r
    where r.user_id = (select auth.uid())
      and r.role = 'admin'
  )
);

grant select, insert, update on public.krbl_equipment_transactions to authenticated;
