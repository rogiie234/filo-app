-- Recheck current assignment settings for work saved before an instructor edit.
-- Do not remove existing draft items or storage objects automatically.
begin;

create or replace function public.turn_in(p_submission uuid, p_comment text default null)
returns public.submissions
language plpgsql security definer set search_path = public as $$
declare
  s submissions;
  p posts;
  v_late boolean;
  v_items integer;
  v_files integer;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions
   where id = p_submission and student_id = auth.uid() for update;
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'draft' then raise exception 'Already turned in'; end if;
  -- Serialize with instructor setting edits until this turn-in commits.
  select * into p from posts
   where id = s.post_id and kind = 'assignment' and deleted_at is null for share;
  if not found then
    raise exception 'This item is no longer available.' using errcode = '22023';
  end if;
  if not is_class_member(p.class_id) then raise exception 'Not allowed'; end if;
  if not class_is_open(p.class_id) then raise exception 'This class is archived'; end if;
  if exists (select 1 from submission_grades g
              where g.submission_id = s.id and g.returned_at is not null) then
    raise exception 'A grade was already returned';
  end if;
  select count(*), count(*) filter (where kind = 'file')
    into v_items, v_files from submission_items
   where submission_id = s.id and deleted_at is null;
  if v_items = 0 then raise exception 'Add at least one item before turning in'; end if;
  if v_files > 0 and not p.allow_files then
    raise exception 'File uploads are turned off for this assignment. Remove the saved files before turning in. You can add a link or text instead.'
      using errcode = '22023';
  end if;
  if v_files > least(p.max_files, 5) then
    raise exception 'The file limit changed. Remove extra files before turning in. This assignment allows up to % files.', least(p.max_files, 5)
      using errcode = '22023';
  end if;
  v_late := now() > p.due_at;
  if v_late and not p.accept_late then
    raise exception 'Submissions are closed for this assignment';
  end if;
  update submissions
     set status = 'turned_in', submitted_at = now(), is_late = v_late,
         private_comment = left(p_comment, 1000),
         unsubmit_until = case when v_late then now()
                               else least(now() + interval '10 minutes', p.due_at) end
   where id = s.id returning * into s;
  return s;
end $$;

-- Coordinate item writes with turn_in's parent lock. Otherwise a concurrent
-- insert could validate a draft before turn_in and commit a file afterwards.
create or replace function public.enforce_submission_item_rules() returns trigger
language plpgsql security definer set search_path = public as $$
declare s submissions; p posts; n integer;
begin
  select * into s from submissions where id = new.submission_id for update;
  if s.status <> 'draft' then raise exception 'This submission is locked'; end if;
  if tg_op = 'INSERT' then
    select * into p from posts where id = s.post_id for share;
    if new.kind = 'file' then
      if not p.allow_files then raise exception 'File uploads are turned off for this assignment'; end if;
      select count(*) into n from submission_items
       where submission_id = new.submission_id and kind = 'file' and deleted_at is null;
      if n >= least(p.max_files, 5) then raise exception 'File limit reached'; end if;
    elsif new.kind = 'link' then
      select count(*) into n from submission_items
       where submission_id = new.submission_id and kind = 'link' and deleted_at is null;
      if n >= 5 then raise exception 'Link limit reached'; end if;
    else
      select count(*) into n from submission_items
       where submission_id = new.submission_id and kind = 'text' and deleted_at is null;
      if n >= 1 then raise exception 'Only one text entry is allowed'; end if;
    end if;
  end if;
  return new;
end $$;

commit;
