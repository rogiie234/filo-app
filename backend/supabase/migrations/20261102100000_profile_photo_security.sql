-- M13-BE-01: profile edits and private avatar constraints.
begin;

-- Remove both table and column UPDATE grants before granting the edit surface.
revoke update on public.profiles from authenticated;
do $$
declare c record;
begin
  for c in select column_name from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
  loop
    execute format('revoke update (%I) on public.profiles from authenticated', c.column_name);
  end loop;
end $$;
grant update (display_name, school, avatar_path) on public.profiles to authenticated;

update storage.buckets set public = false, file_size_limit = 524288,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'avatars';
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'avatars') then
    raise exception 'avatars bucket missing; apply migration 0008 first';
  end if;
end $$;

-- Deleted classes must not keep profile/photo relationships alive.
create or replace function public.shares_class_with(p_user uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select p_user = auth.uid()
    or exists (select 1 from class_members m join classes c on c.id = m.class_id
      where m.student_id = p_user and c.owner_id = auth.uid() and c.deleted_at is null)
    or exists (select 1 from classes c join class_members m on m.class_id = c.id
      where c.owner_id = p_user and m.student_id = auth.uid()
        and m.status in ('pending', 'active') and c.deleted_at is null)
    or exists (select 1 from class_members a join class_members b on a.class_id = b.class_id
      join classes c on c.id = a.class_id
      where a.student_id = auth.uid() and a.status = 'active'
        and b.student_id = p_user and b.status = 'active' and c.deleted_at is null));
end $$;
commit;
