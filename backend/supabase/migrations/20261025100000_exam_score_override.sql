-- M9-BE-04: M9-SA-01 acceptance confirmed by owner; preserve manual marks.
begin;

create function public.override_points(
  p_session uuid, p_question uuid, p_points integer, p_feedback text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare s exam_sessions; qz quizzes; qu questions;
begin
  if auth.uid() is null or not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions where id = p_session for update;
  if not found then raise exception 'Session not found'; end if;
  select * into qz from quizzes where id = s.quiz_id;
  if not is_class_owner(qz.class_id) then raise exception 'Not allowed'; end if;
  if s.status not in ('submitted', 'auto_submitted') then
    raise exception 'This attempt is not submitted yet';
  end if;
  select * into qu from questions where id = p_question and quiz_id = s.quiz_id;
  if not found then raise exception 'Question not found'; end if;
  if p_points is null or p_points < 0 or p_points > qu.points then
    raise exception 'Points must be between 0 and %', qu.points;
  end if;
  if char_length(p_feedback) > 2000 then
    raise exception 'Feedback must be at most 2000 characters';
  end if;
  insert into exam_answers (session_id, question_id, points_awarded, is_correct, feedback, graded_by)
  values (s.id, qu.id, p_points, p_points = qu.points, p_feedback, auth.uid())
  on conflict (session_id, question_id) do update
    set points_awarded = excluded.points_awarded, is_correct = excluded.is_correct,
        feedback = excluded.feedback, graded_by = excluded.graded_by, updated_at = now();
  perform recalc_session_scores(s.id);
  perform maybe_release_results(s.quiz_id);
end $$;

revoke all on function public.override_points(uuid, uuid, integer, text) from public, anon;
grant execute on function public.override_points(uuid, uuid, integer, text) to authenticated;

-- All grading writers lock the session before changing answers or recalculating totals.
create or replace function public.grade_session(p_session uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from exam_sessions where id = p_session for update;
  with scored as (
    select a.id as aid, q.points as pts,
           coalesce(case q.type
             when 'multiple_choice' then a.option_id is not null and a.option_id = k.correct_option_id
             when 'true_false'      then a.bool_answer is not null and a.bool_answer = k.correct_boolean
             when 'identification'  then norm_text(a.text_answer) <> '' and exists (
                select 1 from unnest(coalesce(k.accepted_answers, '{}'::text[])) acc
                 where norm_text(acc) = norm_text(a.text_answer))
             else false end, false) as ok
      from exam_answers a
      join questions q on q.id = a.question_id
      left join answer_keys k on k.question_id = q.id
     where a.session_id = p_session and q.type <> 'essay' and a.graded_by is null)
  update exam_answers a
     set is_correct = s.ok, points_awarded = case when s.ok then s.pts else 0 end
    from scored s where a.id = s.aid;
  perform recalc_session_scores(p_session);
end $$;

create or replace function public.grade_essay(p_answer uuid, p_points integer, p_feedback text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare a exam_answers; s exam_sessions; qz quizzes; qu questions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into a from exam_answers where id = p_answer;
  if not found then raise exception 'Answer not found'; end if;
  select * into s from exam_sessions where id = a.session_id for update;
  select * into qz from quizzes where id = s.quiz_id;
  if not is_class_owner(qz.class_id) then raise exception 'Not allowed'; end if;
  select * into qu from questions where id = a.question_id;
  if qu.type <> 'essay' then raise exception 'Only essay answers are graded by hand'; end if;
  if s.status not in ('submitted', 'auto_submitted') then
    raise exception 'This attempt is not submitted yet';
  end if;
  if p_points < 0 or p_points > qu.points then
    raise exception 'Points must be between 0 and %', qu.points;
  end if;
  update exam_answers
     set points_awarded = p_points, is_correct = null,
         feedback = left(p_feedback, 2000), graded_by = auth.uid(), updated_at = now()
   where id = p_answer;
  perform recalc_session_scores(a.session_id);
  perform maybe_release_results(s.quiz_id);
end $$;

commit;
