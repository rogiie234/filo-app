-- Grading corrections; applied migration history is unchanged.
create or replace function public.save_grade(p_submission uuid, p_score integer, p_feedback text default null)
returns submission_grades
language plpgsql security definer set search_path = public as $$
declare s submissions; p posts; g submission_grades;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission for update;
  if not found then raise exception 'Submission not found'; end if;
  select * into p from posts where id = s.post_id for share;
  if not is_class_owner(p.class_id) then raise exception 'Not allowed'; end if;
  if p.deleted_at is not null or p.kind <> 'assignment' then raise exception 'Assignment not found'; end if;
  if s.status <> 'turned_in' then raise exception 'Nothing to grade yet'; end if;
  if p_score is null or p_score < 0 or p_score > p.points then
    raise exception 'Score must be between 0 and %', p.points;
  end if;
  insert into submission_grades (submission_id, score, feedback, graded_by, graded_at)
  values (p_submission, p_score, left(p_feedback, 2000), auth.uid(), now())
  on conflict (submission_id) do update
    set score = excluded.score, feedback = excluded.feedback,
        graded_by = excluded.graded_by, graded_at = now(), updated_at = now()
  returning * into g;
  return g;
end $$;

create or replace function public.return_grades(p_ids uuid[]) returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  -- Serialize against unsubmit/save; stable order also avoids bulk lock inversions.
  perform s.id from submissions s join posts p on p.id=s.post_id
    where s.id=any(p_ids) and is_class_owner(p.class_id)
    order by s.id for update of s;
  for r in
    with u as (
      update submission_grades g set returned_at = now()
        from submissions s join posts p on p.id = s.post_id
       where g.submission_id = s.id
         and g.submission_id = any(p_ids)
         and s.status = 'turned_in'
         and p.deleted_at is null
         and class_is_open(p.class_id)
         and g.score is not null
         and g.graded_at is not null
         and g.returned_at is null
         and is_class_owner(p.class_id)
      returning s.student_id, p.class_id, p.id as post_id, p.title)
    select * from u
  loop
    perform notify(r.student_id, 'grade_returned', r.class_id, 'Grade returned',
                   'Your work for ' || r.title || ' was graded', 'post', r.post_id);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.return_all_graded(p_post uuid) returns integer
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select return_grades(array(
    select g.submission_id from submission_grades g
      join submissions s on s.id = g.submission_id
     where s.post_id = p_post)));
end;
$$;


create or replace function public.unsubmit(p_submission uuid) returns submissions
language plpgsql security definer set search_path = public as $$
declare s submissions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission and student_id = auth.uid() for update;
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'turned_in' then raise exception 'This work is not turned in'; end if;
  if s.unsubmit_until is null or now() >= s.unsubmit_until then raise exception 'The unsubmit window has passed'; end if;
  if exists (select 1 from submission_grades g
              where g.submission_id = s.id and g.returned_at is not null) then
    raise exception 'A grade was already returned';
  end if;
  update submissions
     set status = 'draft', submitted_at = null, is_late = false, unsubmit_until = null
   where id = s.id returning * into s;
  return s;
end $$;
