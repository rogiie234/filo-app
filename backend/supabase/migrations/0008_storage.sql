-- =====================================================================
-- Filo migration 0008: storage buckets and policies
-- All buckets are private. The app uses short-lived signed links.
-- Verify the free plan's overall and per-file limits before relying on these values.
-- Video is blocked by file extension. No MIME allow-list is used because Android
-- often reports files such as PSD with a generic type.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit) values
  ('avatars',     'avatars',     false,   524288),    -- 512 KB
  ('banners',     'banners',     false,  2097152),    -- 2 MB
  ('materials',   'materials',   false, 26214400),    -- 25 MB
  ('submissions', 'submissions', false, 26214400)     -- 25 MB
on conflict (id) do update set file_size_limit = excluded.file_size_limit;

-- ---------- avatars: user_id/file ----------
create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and current_user_ok() and (
    (storage.foldername(name))[1] = auth.uid()::text
    or shares_class_with(((storage.foldername(name))[1])::uuid)));
create policy avatars_write on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and current_user_ok()
              and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and current_user_ok()
         and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and current_user_ok()
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- banners: class_id/file ----------
create policy banners_read on storage.objects for select to authenticated
  using (bucket_id = 'banners' and current_user_ok()
         and has_class_link(((storage.foldername(name))[1])::uuid));
create policy banners_write on storage.objects for insert to authenticated
  with check (bucket_id = 'banners' and current_user_ok()
              and is_class_owner(((storage.foldername(name))[1])::uuid));
create policy banners_update on storage.objects for update to authenticated
  using (bucket_id = 'banners' and current_user_ok()
         and is_class_owner(((storage.foldername(name))[1])::uuid));
create policy banners_delete on storage.objects for delete to authenticated
  using (bucket_id = 'banners' and current_user_ok()
         and is_class_owner(((storage.foldername(name))[1])::uuid));

-- ---------- materials: class_id/post_id/file ----------
create policy materials_read on storage.objects for select to authenticated
  using (bucket_id = 'materials' and current_user_ok() and (
    is_class_owner(((storage.foldername(name))[1])::uuid)
    or is_class_member(((storage.foldername(name))[1])::uuid)));
create policy materials_write on storage.objects for insert to authenticated
  with check (bucket_id = 'materials' and current_user_ok()
              and is_class_owner(((storage.foldername(name))[1])::uuid)
              and lower(coalesce(storage.extension(name), '')) not in
                  ('mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp', 'wmv'));
create policy materials_update on storage.objects for update to authenticated
  using (bucket_id = 'materials' and current_user_ok()
         and is_class_owner(((storage.foldername(name))[1])::uuid));
create policy materials_delete on storage.objects for delete to authenticated
  using (bucket_id = 'materials' and current_user_ok()
         and is_class_owner(((storage.foldername(name))[1])::uuid));

-- ---------- submissions: class_id/post_id/student_id/file ----------
create policy submissions_read on storage.objects for select to authenticated
  using (bucket_id = 'submissions' and current_user_ok() and (
    (storage.foldername(name))[3] = auth.uid()::text
    or is_class_owner(((storage.foldername(name))[1])::uuid)));
create policy submissions_write on storage.objects for insert to authenticated
  with check (bucket_id = 'submissions' and current_user_ok()
              and (storage.foldername(name))[3] = auth.uid()::text
              and is_class_member(((storage.foldername(name))[1])::uuid)
              and lower(coalesce(storage.extension(name), '')) not in
                  ('mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp', 'wmv'));
create policy submissions_update on storage.objects for update to authenticated
  using (bucket_id = 'submissions' and current_user_ok()
         and (storage.foldername(name))[3] = auth.uid()::text);
create policy submissions_delete on storage.objects for delete to authenticated
  using (bucket_id = 'submissions' and current_user_ok()
         and (storage.foldername(name))[3] = auth.uid()::text);
