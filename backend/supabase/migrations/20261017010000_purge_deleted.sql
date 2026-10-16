-- Storage metadata is read only. Blob deletion belongs to the Edge Storage API.
create index if not exists idx_classes_deleted_purge
  on public.classes (deleted_at, id) where deleted_at is not null;

create or replace function public.list_deleted_class_files(p_class uuid)
returns table(bucket_id text, name text)
language sql stable security definer set search_path = '' as $$
  select o.bucket_id, o.name from storage.objects o
  where o.bucket_id in ('banners', 'materials', 'submissions')
    and starts_with(o.name, p_class::text || '/')
    and exists (select 1 from public.classes c where c.id = p_class
      and c.deleted_at < now() - interval '14 days')
  order by o.bucket_id, o.name limit 500;
$$;

create or replace function public.finish_deleted_class_purge(p_class uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.classes c where c.id = p_class
    and c.deleted_at < now() - interval '14 days' for update;
  if not found then return false; end if;
  if exists (select 1 from storage.objects o
    where o.bucket_id in ('banners', 'materials', 'submissions')
      and starts_with(o.name, p_class::text || '/')) then
    raise exception 'Class still has Storage files; retry cleanup first';
  end if;
  delete from public.classes where id = p_class;
  return true;
end $$;

revoke all on function public.list_deleted_class_files(uuid) from public, anon, authenticated;
revoke all on function public.finish_deleted_class_purge(uuid) from public, anon, authenticated;
grant execute on function public.list_deleted_class_files(uuid) to service_role;
grant execute on function public.finish_deleted_class_purge(uuid) to service_role;

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Configure Vault project_url and purge_deleted_secret before the first run.
create or replace function public.invoke_purge_deleted()
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  project_url text;
  purge_secret text;
  request_id bigint;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets
    where name = 'project_url';
  select decrypted_secret into purge_secret from vault.decrypted_secrets
    where name = 'purge_deleted_secret';
  if nullif(project_url, '') is null or nullif(purge_secret, '') is null then
    raise exception 'Configure Vault project_url and purge_deleted_secret';
  end if;
  select net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/purge-deleted',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', purge_secret),
    body := '{}'::jsonb, timeout_milliseconds := 120000
  ) into request_id;
  return request_id;
end $$;
revoke all on function public.invoke_purge_deleted() from public, anon, authenticated, service_role;

-- 04:00 UTC / 12:00 Asia/Manila. Same name updates an existing schedule.
select cron.schedule('filo-purge-deleted', '0 4 * * *',
  'select public.invoke_purge_deleted()');
