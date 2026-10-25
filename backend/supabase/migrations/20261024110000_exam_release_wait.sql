-- M9-BE-03: owner confirms M9-SA-01 acceptance; wait after the latest submission.
begin;

create or replace function public.maybe_release_results(p_quiz uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare q quizzes; v_all_done boolean; v_latest_submission timestamptz;
  v_release_wait_minutes constant integer := 10;
begin
  select * into q from quizzes
   where id = p_quiz and status = 'published'
     and results_released_at is null and deleted_at is null;
  if not found then return false; end if;
  v_all_done := q.closes_at <= now() or not exists (
    select 1 from class_members m
     where m.class_id = q.class_id and m.status = 'active'
       and not exists (select 1 from exam_sessions s
                        where s.quiz_id = q.id and s.student_id = m.student_id
                          and s.status in ('submitted', 'auto_submitted')));
  if not v_all_done then return false; end if;
  -- Closing time (including manual release) bypasses only the submission wait.
  if q.closes_at > now() then
    select max(s.submitted_at) into v_latest_submission from exam_sessions s
     where s.quiz_id = q.id and s.status in ('submitted', 'auto_submitted');
    if v_latest_submission is null
       or now() < v_latest_submission + make_interval(mins => v_release_wait_minutes) then
      return false;
    end if;
  end if;
  if exists (select 1 from exam_sessions s where s.quiz_id = q.id and s.status = 'in_progress') then
    return false;
  end if;
  if exists (select 1 from exam_sessions s
              where s.quiz_id = q.id and s.status in ('submitted', 'auto_submitted')
                and not s.grading_complete) then
    return false;
  end if;
  update quizzes set results_released_at = now() where id = q.id;
  insert into notifications (recipient_id, class_id, type, title, body, target_type, target_id)
  select s.student_id, q.class_id, 'results_released', 'Results available',
         'Results are available: ' || q.title, 'quiz', q.id
    from exam_sessions s
   where s.quiz_id = q.id and s.status in ('submitted', 'auto_submitted');
  return true;
end $$;

commit;
