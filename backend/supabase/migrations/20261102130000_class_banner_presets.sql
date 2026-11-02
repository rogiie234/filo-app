-- M14-BE-01: canonical banner keys and private image access.
begin;

-- Hold writers until preflight and constraint installation finish together.
lock table public.classes in share row exclusive mode;
do $$
declare incompatible bigint;
begin
  select count(*) into incompatible from public.classes
    where banner_color is not null and banner_color not in
      ('forest','teal','sage','pine','ocean','slate','olive','plum');
  if incompatible > 0 then
    raise exception '% classes contain unsupported banner_color values', incompatible
      using hint = 'Inspect classes.id and banner_color as an administrator; agree corrections with the owner before retrying. No values were changed.';
  end if;
  if not exists (select 1 from storage.buckets where id = 'banners') then
    raise exception 'banners bucket missing; apply migration 0008 first';
  end if;
end $$;

alter table public.classes add constraint classes_banner_color_preset_check
  check (banner_color is null or banner_color in
    ('forest','teal','sage','pine','ocean','slate','olive','plum'));

update storage.buckets set public = false, file_size_limit = 2097152,
  allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'banners';

alter policy banners_read on storage.objects using (
  bucket_id = 'banners' and public.current_user_ok() and (
    public.is_class_owner(((storage.foldername(name))[1])::uuid)
    or public.is_class_member(((storage.foldername(name))[1])::uuid)));

alter policy banners_update on storage.objects
  using (bucket_id = 'banners' and public.current_user_ok()
    and public.is_class_owner(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'banners' and public.current_user_ok()
    and public.is_class_owner(((storage.foldername(name))[1])::uuid));

commit;
