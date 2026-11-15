-- Keep drafts private and serialize file metadata writes with Turn in.
begin;
drop policy submissions_read on storage.objects;
create policy submissions_read on storage.objects for select to authenticated
using (bucket_id = 'submissions' and public.current_user_ok() and (
  (storage.foldername(name))[3] = auth.uid()::text
  or exists (
    select 1 from public.submission_items i
    join public.submissions s on s.id=i.submission_id
    join public.posts p on p.id=s.post_id
    where i.storage_path=objects.name and i.kind='file' and i.deleted_at is null
      and s.status='turned_in' and p.deleted_at is null
      and public.is_class_owner(p.class_id)
      and starts_with(objects.name,p.class_id::text||'/'||p.id::text||'/'||s.student_id::text||'/')
  )
));

create function public.guard_submission_storage_write() returns trigger
language plpgsql security definer set search_path = '' as $$
declare path text; parts text[]; s public.submissions;
begin
  if current_setting('role',true) <> 'authenticated' then
    return case when tg_op='DELETE' then old else new end;
  end if;
  if tg_op='UPDATE' and (old.bucket_id='submissions' or new.bucket_id='submissions')
    and (new.bucket_id is distinct from old.bucket_id or new.name is distinct from old.name) then
    raise exception 'Submission files cannot be moved' using errcode='42501';
  end if;
  if tg_op='DELETE' then
    if old.bucket_id<>'submissions' then return old; end if;
    path:=old.name;
  else
    if new.bucket_id<>'submissions' then return new; end if;
    path:=new.name;
  end if;
  parts:=string_to_array(path,'/');
  if cardinality(parts)<>4 or parts[4] in ('','.','..') then
    raise exception 'Invalid submission file path' using errcode='42501';
  end if;
  -- The parent lock makes an overlapping Turn in wait or makes this write see its committed status.
  select sub.* into s from public.submissions sub join public.posts p on p.id=sub.post_id
    where p.class_id::text=parts[1] and p.id::text=parts[2]
      and sub.student_id=auth.uid() and sub.student_id::text=parts[3]
      and p.deleted_at is null and p.kind='assignment'
    for update of sub;
  if not found or s.status<>'draft' or not public.current_user_ok()
    or not public.own_draft_submission(s.id)
    or exists(select 1 from public.submission_grades g where g.submission_id=s.id and g.returned_at is not null) then
    raise exception 'This submission is locked' using errcode='42501';
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function public.guard_submission_storage_write() from public,anon,authenticated;
create trigger guard_submission_storage_write before insert or update or delete on storage.objects
for each row execute function public.guard_submission_storage_write();
commit;
