-- Tighten existing materials policies without changing other buckets.
begin;

insert into storage.buckets (id, name, public, file_size_limit)
values ('materials', 'materials', false, 26214400)
on conflict (id) do update set public = false, file_size_limit = 26214400;

-- Invoker rights retain posts RLS. Invalid UUID paths return false, not cast errors.
create or replace function public.material_path_ok(p_name text)
returns boolean language plpgsql stable set search_path = public as $$
declare
  parts text[] := string_to_array(p_name, '/');
  class_key uuid;
  post_key uuid;
begin
  if cardinality(parts) <> 3 or coalesce(parts[3], '') in ('', '.', '..') then
    return false;
  end if;
  begin
    class_key := parts[1]::uuid;
    post_key := parts[2]::uuid;
  exception when invalid_text_representation then return false;
  end;
  return exists (select 1 from public.posts p
    where p.id = post_key and p.class_id = class_key and p.deleted_at is null);
end $$;
revoke all on function public.material_path_ok(text) from public;
grant execute on function public.material_path_ok(text) to authenticated;

-- Restrictive checks apply to inserts AND update/rename/upsert destinations.
create policy materials_path_read on storage.objects as restrictive
for select to authenticated
using (bucket_id <> 'materials' or public.material_path_ok(name));

create policy materials_path_insert on storage.objects as restrictive
for insert to authenticated
with check (bucket_id <> 'materials' or (
  public.material_path_ok(name)
  and lower(coalesce(storage.extension(name), '')) not in
    ('mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp', 'wmv')));

create policy materials_path_update on storage.objects as restrictive
for update to authenticated
using (bucket_id <> 'materials' or public.material_path_ok(name))
with check (bucket_id <> 'materials' or (
  public.material_path_ok(name)
  and public.is_class_owner(((storage.foldername(name))[1])::uuid)
  and lower(coalesce(storage.extension(name), '')) not in
    ('mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp', 'wmv')));

commit;
