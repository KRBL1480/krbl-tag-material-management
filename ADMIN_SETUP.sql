-- Run this only AFTER you create/confirm your own account in the dashboard.
-- Replace EMAIL_HERE with the exact email of the account that should be Admin.
-- Run this separately in Supabase SQL Editor.
insert into public.krbl_user_roles (user_id, role)
select id, 'admin'
from auth.users
where email = 'EMAIL_HERE'
on conflict (user_id) do update set role = 'admin';

-- Verify it updated one row. If it updated zero rows, the account email does not exist yet.
