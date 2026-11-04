begin;
alter table public.classes add column if not exists purge_requested_at timestamptz;

create function public.request_permanent_class_deletion(p_class uuid, p_section text)
returns void language plpgsql security definer set search_path='' as $$
declare c public.classes;
begin
  if not public.current_user_ok() then raise exception 'Verified session required' using errcode='42501'; end if;
  select * into c from public.classes where id=p_class for update;
  if not found or c.owner_id <> auth.uid() or c.deleted_at is null or c.section <> p_section then
    raise exception 'Deleted owned class and matching section required' using errcode='42501';
  end if;
  if not exists(select 1 from public.profiles where id=auth.uid() and role='instructor') then
    raise exception 'Instructor required' using errcode='42501';
  end if;
  update public.classes set purge_requested_at=coalesce(purge_requested_at,now()) where id=p_class;
end $$;
revoke all on function public.request_permanent_class_deletion(uuid,text) from public,anon;
grant execute on function public.request_permanent_class_deletion(uuid,text) to authenticated;

create function public.guard_permanent_class_deletion() returns trigger
language plpgsql set search_path='' as $$
begin
  if old.purge_requested_at is not null and
    (new.deleted_at is null or new.purge_requested_at is distinct from old.purge_requested_at or new.owner_id is distinct from old.owner_id) then
    raise exception 'Permanent deletion has started' using errcode='42501';
  end if;
  return new;
end $$;
create trigger guard_permanent_class_deletion before update on public.classes
for each row execute function public.guard_permanent_class_deletion();

create or replace function public.list_deleted_class_files(p_class uuid)
returns table(bucket_id text,name text) language sql stable security definer set search_path='' as $$
select o.bucket_id,o.name from storage.objects o
where o.bucket_id in ('banners','materials','submissions') and starts_with(o.name,p_class::text||'/')
and exists(select 1 from public.classes c where c.id=p_class and c.deleted_at is not null
  and (c.deleted_at < now()-interval '14 days' or c.purge_requested_at is not null))
order by o.bucket_id,o.name limit 500;
$$;
create or replace function public.finish_deleted_class_purge(p_class uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.classes where id=p_class and deleted_at is not null
    and (deleted_at < now()-interval '14 days' or purge_requested_at is not null) for update;
  if not found then return false; end if;
  if exists(select 1 from storage.objects where bucket_id in ('banners','materials','submissions')
    and starts_with(name,p_class::text||'/')) then raise exception 'Storage cleanup incomplete'; end if;
  delete from public.classes where id=p_class;
  return true;
end $$;
revoke all on function public.list_deleted_class_files(uuid),public.finish_deleted_class_purge(uuid) from public,anon,authenticated;
grant execute on function public.list_deleted_class_files(uuid),public.finish_deleted_class_purge(uuid) to service_role;
commit;
