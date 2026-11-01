-- M13-BE-02. Apply on DEV first. External Storage/Auth cleanup is owner-deployed.
begin;

do $$
begin
  if (select count(*) from information_schema.columns
    where table_schema='storage' and table_name in ('objects','buckets')
      and column_name in ('owner','owner_id'))<>4 then
    raise exception 'Expected Supabase Storage owner/owner_id columns on objects and buckets';
  end if;
end $$;

create table public.account_deletions (
  user_id uuid primary key references public.profiles(id),
  requested_at timestamptz not null default now(),
  attempted_at timestamptz,
  completed_at timestamptz,
  lease_id uuid,
  lease_until timestamptz,
  last_error text check (last_error in ('storage','auth','database','deferred'))
);
alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from public, anon, authenticated;
grant select on public.account_deletions to service_role;
create index account_deletions_pending on public.account_deletions(attempted_at nulls first,requested_at)
  where completed_at is null;

-- Preserve pre-profile onboarding; a deletion request alone permanently closes access.
create or replace function public.current_user_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.is_session_verified()
    and not exists (select 1 from public.account_deletions d where d.user_id=auth.uid());
$$;

create function public.guard_deleted_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.account_deletions where user_id=old.id)
    and (new.id is distinct from old.id or new.role is distinct from old.role
      or new.deleted_at is null or new.display_name<>'Deleted User'
      or new.email is not null or new.school is not null or new.google_photo_url is not null
      or new.avatar_path is not null or new.privacy_accepted_at is not null
      or new.privacy_version is not null) then
    raise exception 'Account deletion is permanent' using errcode='42501';
  end if;
  return new;
end $$;
create trigger guard_deleted_profile before update on public.profiles
  for each row execute function public.guard_deleted_profile();

create function public.guard_deleted_membership() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Serialize membership activation with the profile lock taken by deletion.
  perform 1 from public.profiles where id=new.student_id for update;
  if new.status<>'left' and exists (
    select 1 from public.account_deletions where user_id=new.student_id) then
    raise exception 'Deleted account cannot rejoin' using errcode='42501';
  end if;
  return new;
end $$;
create trigger guard_deleted_membership before insert or update on public.class_members
  for each row execute function public.guard_deleted_membership();

create function public.guard_deleted_recipient() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.profiles where id=new.recipient_id for update;
  -- Instructor grade/result publication must still succeed without recreating an inbox.
  if exists (select 1 from public.account_deletions where user_id=new.recipient_id) then
    return null;
  end if;
  return new;
end $$;
create trigger guard_deleted_recipient before insert or update on public.notifications
  for each row execute function public.guard_deleted_recipient();

create function public.guard_deleted_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.profiles where id=new.user_id for update;
  if exists (select 1 from public.account_deletions where user_id=new.user_id) then
    raise exception 'Account deletion is permanent' using errcode='42501';
  end if;
  return new;
end $$;
do $$
declare t text;
begin
  foreach t in array array['trusted_devices','device_tokens','otp_codes','verified_sessions','notification_settings'] loop
    execute format('create trigger guard_deleted_device before insert or update on public.%I
      for each row execute function public.guard_deleted_device()',t);
  end loop;
end $$;

create function public.guard_deleted_storage_writer() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role',true)='authenticated' then
    -- An in-flight upload must finish before deletion starts enumerating its files.
    perform 1 from public.profiles where id=auth.uid() for update;
    if exists (select 1 from public.account_deletions where user_id=auth.uid()) then
      raise exception 'Account deletion is permanent' using errcode='42501';
    end if;
  end if;
  return new;
end $$;
create trigger guard_deleted_storage_writer before insert or update on storage.objects
  for each row execute function public.guard_deleted_storage_writer();

create function public.begin_student_account_deletion(p_user uuid,p_session uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles;
begin
  select * into p from public.profiles where id=p_user for update;
  if not found or p.role<>'student' then
    raise exception 'Verified student required' using errcode='42501';
  end if;
  -- Explicit session proof also permits resuming an already accepted deletion.
  perform 1 from auth.sessions s join public.verified_sessions v
    on v.session_id=s.id and v.user_id=s.user_id
    where s.id=p_session and s.user_id=p_user for update of s;
  if not found then raise exception 'OTP verification required' using errcode='42501'; end if;
  if exists(select 1 from public.account_deletions where user_id=p_user and completed_at is not null) then
    raise exception 'Deletion already completed' using errcode='42501';
  end if;
  if p.deleted_at is not null and not exists(select 1 from public.account_deletions where user_id=p_user) then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  if exists(select 1 from public.classes where owner_id=p_user) then
    raise exception 'Student owns classes' using errcode='42501';
  end if;
  insert into public.account_deletions(user_id) values(p_user) on conflict do nothing;
  update public.profiles set display_name='Deleted User',email=null,school=null,
    google_photo_url=null,avatar_path=null,privacy_accepted_at=null,privacy_version=null,
    deleted_at=coalesce(deleted_at,now()) where id=p_user;
  update public.class_members set status='left',left_at=coalesce(left_at,now()) where student_id=p_user;
  delete from public.notifications where recipient_id=p_user;
  delete from public.notification_settings where user_id=p_user;
  delete from public.device_tokens where user_id=p_user;
  delete from public.trusted_devices where user_id=p_user;
  delete from public.otp_codes where user_id=p_user;
  -- Keep this proof only for cleanup retries; current_user_ok already denies app access.
  delete from public.verified_sessions where user_id=p_user and session_id<>p_session;
end $$;

create function public.claim_account_deletion(p_user uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare lease uuid:=gen_random_uuid();
begin
  update public.account_deletions set lease_id=lease,lease_until=clock_timestamp()+interval '180 seconds',
    attempted_at=clock_timestamp(),last_error=null
    where user_id=p_user and completed_at is null
      and (lease_until is null or lease_until<clock_timestamp());
  if not found then return null; end if;
  return lease;
end $$;

create function public.list_account_avatars(p_user uuid,p_lease uuid)
returns table(name text) language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.account_deletions where user_id=p_user
    and lease_id=p_lease and lease_until>clock_timestamp() and completed_at is null) then
    raise exception 'Deletion lease unavailable' using errcode='42501';
  end if;
  return query select o.name from storage.objects o where o.bucket_id='avatars'
    and (starts_with(o.name,p_user::text||'/') or o.owner_id=p_user::text or o.owner=p_user)
    order by o.name limit 500;
end $$;

create function public.prepare_account_auth_deletion(p_user uuid,p_lease uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null for update;
  if not found then raise exception 'Deletion lease unavailable' using errcode='42501'; end if;
  if exists(select 1 from public.list_account_avatars(p_user,p_lease)) then
    raise exception 'Avatar cleanup incomplete';
  end if;
  -- Retained blobs keep their paths/bytes and class RLS; detach only Auth ownership.
  update storage.objects set owner=null,owner_id=null
    where bucket_id<>'avatars' and (owner=p_user or owner_id=p_user::text);
  update storage.buckets set owner=null,owner_id=null where owner=p_user or owner_id=p_user::text;
end $$;

create function public.finish_account_deletion(p_user uuid,p_lease uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null for update;
  if not found then raise exception 'Deletion lease unavailable' using errcode='42501'; end if;
  if exists(select 1 from auth.users where id=p_user)
    or exists(select 1 from public.list_account_avatars(p_user,p_lease)) then
    raise exception 'External cleanup incomplete';
  end if;
  delete from public.verified_sessions where user_id=p_user;
  update public.account_deletions set completed_at=now(),lease_id=null,lease_until=null,last_error=null where user_id=p_user;
end $$;

create function public.release_account_deletion(p_user uuid,p_lease uuid,p_error text) returns void
language sql security definer set search_path = '' as $$
  update public.account_deletions set lease_id=null,lease_until=null,last_error=p_error
    where user_id=p_user and lease_id=p_lease and completed_at is null;
$$;

-- Only trusted Edge code can nominate an account/session or manipulate a job.
do $$
declare sig text;
begin
  foreach sig in array array['guard_deleted_profile()','guard_deleted_membership()',
    'guard_deleted_recipient()','guard_deleted_device()','guard_deleted_storage_writer()',
    'begin_student_account_deletion(uuid,uuid)','claim_account_deletion(uuid)',
    'list_account_avatars(uuid,uuid)','prepare_account_auth_deletion(uuid,uuid)',
    'finish_account_deletion(uuid,uuid)','release_account_deletion(uuid,uuid,text)'] loop
    execute 'revoke all on function public.'||sig||' from public,anon,authenticated';
    execute 'grant execute on function public.'||sig||' to service_role';
  end loop;
end $$;
commit;
