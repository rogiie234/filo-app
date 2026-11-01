-- M13-BE-03. Forward migration; no remote application/testing implied.
begin;
alter function public.begin_student_account_deletion(uuid,uuid) rename to begin_account_deletion;

create function public.guard_deleting_class_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='UPDATE' then
    perform id from public.profiles where id in (old.owner_id,new.owner_id) order by id for update;
    if exists(select 1 from public.account_deletions where user_id=old.owner_id) then
      raise exception 'Account deletion is permanent' using errcode='42501';
    end if;
  else
    perform id from public.profiles where id=new.owner_id for update;
  end if;
  if exists(select 1 from public.account_deletions where user_id=new.owner_id) then
    raise exception 'Account deletion is permanent' using errcode='42501';
  end if;
  return new;
end $$;
create trigger guard_deleting_class_owner before insert or update on public.classes
  for each row execute function public.guard_deleting_class_owner();

create or replace function public.guard_deleted_storage_writer() returns trigger
language plpgsql security definer set search_path = '' as $$
declare class_owner uuid; folder text;
begin
  if current_setting('role',true)='authenticated' then
    if new.bucket_id in ('banners','materials','submissions') then
      folder:=split_part(new.name,'/',1);
      if folder ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select owner_id into class_owner from public.classes where id=folder::uuid;
      end if;
    end if;
    -- Serialize even a student's in-flight class upload with the deleting owner.
    perform id from public.profiles where id in (auth.uid(),class_owner) order by id for update;
    if exists(select 1 from public.account_deletions where user_id in (auth.uid(),class_owner)) then
      raise exception 'Account deletion is permanent' using errcode='42501';
    end if;
  end if;
  return new;
end $$;

create or replace function public.begin_account_deletion(p_user uuid,p_session uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles; class_count integer;
begin
  select * into p from public.profiles where id=p_user for update;
  if not found then
    raise exception 'Verified account required' using errcode='42501';
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
  select count(*)::integer into class_count from public.classes
    where owner_id=p_user and deleted_at is null;
  if class_count>0 then
    raise exception 'Owned classes exist' using errcode='P1303',
      detail=jsonb_build_object('count',class_count)::text;
  end if;
  if p.role='student' and exists(select 1 from public.classes where owner_id=p_user) then
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


create function public.next_account_deletion_class(p_user uuid,p_lease uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null) then
    raise exception 'Deletion lease unavailable' using errcode='42501';
  end if;
  return (select c.id from public.classes c join public.profiles p on p.id=c.owner_id
    where c.owner_id=p_user and p.role='instructor' and c.deleted_at is not null order by c.id limit 1);
end $$;

create function public.list_account_deletion_class_files(p_user uuid,p_lease uuid,p_class uuid)
returns table(bucket_id text,name text) language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null)
    or not exists(select 1 from public.classes c join public.profiles p on p.id=c.owner_id
      where c.id=p_class and c.owner_id=p_user and p.role='instructor' and c.deleted_at is not null) then
    raise exception 'Deletion class unavailable' using errcode='42501';
  end if;
  return query select o.bucket_id,o.name from storage.objects o
    where o.bucket_id in ('banners','materials','submissions') and starts_with(o.name,p_class::text||'/')
    order by o.bucket_id,o.name limit 500;
end $$;

create function public.purge_account_deletion_class(p_user uuid,p_lease uuid,p_class uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null for update;
  if not found then raise exception 'Deletion lease unavailable' using errcode='42501'; end if;
  perform 1 from public.classes c join public.profiles p on p.id=c.owner_id
    where c.id=p_class and c.owner_id=p_user and p.role='instructor' and c.deleted_at is not null for update of c;
  -- Another legitimate purge worker may have completed this class already.
  if not found then
    if exists(select 1 from public.classes where id=p_class) then
      raise exception 'Deletion class unavailable' using errcode='42501';
    end if;
    return;
  end if;
  if exists(select 1 from public.list_account_deletion_class_files(p_user,p_lease,p_class)) then
    raise exception 'Class files remain';
  end if;
  delete from public.classes where id=p_class;
end $$;

create or replace function public.prepare_account_auth_deletion(p_user uuid,p_lease uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null for update;
  if not found then raise exception 'Deletion lease unavailable' using errcode='42501'; end if;
  if exists(select 1 from public.classes where owner_id=p_user) then
    raise exception 'Owned class cleanup incomplete';
  end if;
  if exists(select 1 from public.list_account_avatars(p_user,p_lease)) then
    raise exception 'Avatar cleanup incomplete';
  end if;
  -- Retained blobs keep their paths/bytes and class RLS; detach only Auth ownership.
  update storage.objects set owner=null,owner_id=null
    where bucket_id<>'avatars' and (owner=p_user or owner_id=p_user::text);
  update storage.buckets set owner=null,owner_id=null where owner=p_user or owner_id=p_user::text;
end $$;

create or replace function public.finish_account_deletion(p_user uuid,p_lease uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.account_deletions where user_id=p_user and lease_id=p_lease
    and lease_until>clock_timestamp() and completed_at is null for update;
  if not found then raise exception 'Deletion lease unavailable' using errcode='42501'; end if;
  if exists(select 1 from public.classes where owner_id=p_user) then
    raise exception 'Owned class cleanup incomplete';
  end if;
  if exists(select 1 from auth.users where id=p_user)
    or exists(select 1 from public.list_account_avatars(p_user,p_lease)) then
    raise exception 'External cleanup incomplete';
  end if;
  delete from public.verified_sessions where user_id=p_user;
  update public.account_deletions set completed_at=now(),lease_id=null,lease_until=null,last_error=null where user_id=p_user;
end $$;

do $$
declare sig text;
begin
  foreach sig in array array['guard_deleting_class_owner()','begin_account_deletion(uuid,uuid)',
    'next_account_deletion_class(uuid,uuid)','list_account_deletion_class_files(uuid,uuid,uuid)',
    'purge_account_deletion_class(uuid,uuid,uuid)'] loop
    execute 'revoke all on function public.'||sig||' from public,anon,authenticated';
    execute 'grant execute on function public.'||sig||' to service_role';
  end loop;
end $$;
commit;
