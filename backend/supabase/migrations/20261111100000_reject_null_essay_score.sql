-- Preserve existing grade_essay permissions; reject missing marks before any write.
begin;
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
  if p_points is null or p_points < 0 or p_points > qu.points then
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
