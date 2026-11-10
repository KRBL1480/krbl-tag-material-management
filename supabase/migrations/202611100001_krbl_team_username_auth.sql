alter table public.krbl_team_profiles
  add column if not exists username text,
  add column if not exists last_login_at timestamptz,
  add column if not exists last_activity_at timestamptz;

create unique index if not exists krbl_team_profiles_username_lower_uidx
  on public.krbl_team_profiles (lower(username))
  where username is not null and btrim(username) <> '';

create index if not exists krbl_team_profiles_employee_id_lower_idx
  on public.krbl_team_profiles (lower(employee_id))
  where employee_id is not null;

alter table public.krbl_user_roles drop constraint if exists krbl_user_roles_role_check;
alter table public.krbl_user_roles add constraint krbl_user_roles_role_check
  check (role in ('admin','office','team','viewer'));

create or replace function public.krbl_touch_team_last_activity()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.actor_id is not null then
    update public.krbl_team_profiles set last_activity_at = new.occurred_at
    where user_id = new.actor_id;
  end if;
  return new;
end;
$$;

drop trigger if exists krbl_activity_touch_profile on public.krbl_activity_log;
create trigger krbl_activity_touch_profile after insert on public.krbl_activity_log
for each row execute function public.krbl_touch_team_last_activity();

create index if not exists krbl_activity_actor_time
on public.krbl_activity_log(actor_id, occurred_at desc);
