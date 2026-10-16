-- Correct the SQL alias collision with the get_result PL/pgSQL q variable.
-- Preserve the already-applied lifecycle migration and existing RPC contract.
begin;

create or replace function public.get_result(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s exam_sessions; q quizzes; v_review jsonb; v_percent integer;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions where id = p_session and student_id = auth.uid();
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes access_quiz where access_quiz.id = s.quiz_id and is_class_member(access_quiz.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  select * into q from quizzes where id = s.quiz_id;
  if q.results_released_at is null then raise exception 'Results are not available yet'; end if;
  v_percent := case when q.total_points > 0
                    then round(100.0 * s.total_score / q.total_points)::int else 0 end;
  if q.show_correct_answers then
    select coalesce(jsonb_agg(jsonb_build_object(
             'question_id', qu.id, 'type', qu.type, 'prompt', qu.prompt, 'points', qu.points,
             'points_awarded', a.points_awarded, 'is_correct', a.is_correct,
             'feedback', a.feedback, 'explanation', qu.explanation,
             'your_answer', case qu.type
                when 'multiple_choice' then to_jsonb((select o.text from question_options o where o.id = a.option_id))
                when 'true_false' then to_jsonb(a.bool_answer)
                else to_jsonb(a.text_answer) end,
             'correct_answer', case qu.type
                when 'multiple_choice' then to_jsonb((select o.text from question_options o where o.id = k.correct_option_id))
                when 'true_false' then to_jsonb(k.correct_boolean)
                when 'identification' then to_jsonb(k.accepted_answers)
                else null end)
           order by u.ord), '[]'::jsonb)
      into v_review
      from unnest(s.question_order) with ordinality as u(qid, ord)
      join questions qu on qu.id = u.qid
      left join exam_answers a on a.session_id = s.id and a.question_id = qu.id
      left join answer_keys k on k.question_id = qu.id;
  end if;
  return jsonb_build_object(
    'score', s.total_score, 'total_points', q.total_points, 'percent', v_percent,
    'passed', case when q.passing_percent is null then null
                   else v_percent >= q.passing_percent end,
    'review', v_review);
end $$;

commit;
