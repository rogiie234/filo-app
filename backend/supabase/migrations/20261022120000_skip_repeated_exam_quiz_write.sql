-- M8-BE-03: reduce redundant writes observed on the synchronized Start path.
-- Preserve the quiz row lock, publication/edit serialization and all caller checks.
begin;

create or replace function public.start_exam(p_quiz uuid) returns exam_sessions
language plpgsql security definer set search_path = public as $$
declare q quizzes; s exam_sessions; v_deadline timestamptz;
        v_order uuid[]; v_opts jsonb; v_attempt integer;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not current_user_ok() then raise exception 'Not signed in'; end if;
  select * into q from quizzes where id = p_quiz and status = 'published' and deleted_at is null for update;
  if not found or not is_class_member(q.class_id) then raise exception 'Quiz not found'; end if;
  if not class_is_open(q.class_id) then raise exception 'This class is archived'; end if;
  select * into s from exam_sessions
   where quiz_id = p_quiz and student_id = auth.uid() and status <> 'voided';
  if found then
    if s.status = 'in_progress' and now() <= s.deadline_at + interval '15 seconds' then
      return s;    -- resume: the timer is never reset
    end if;
    raise exception 'You have already taken this quiz';
  end if;
  if now() < q.opens_at then raise exception 'This quiz has not opened yet'; end if;
  if now() >= q.closes_at then raise exception 'This quiz has closed'; end if;
  v_deadline := least(now() + make_interval(mins => q.time_limit_minutes), q.closes_at);
  select array_agg(id order by case when q.shuffle_questions then random()
                                    else position::double precision end)
    into v_order from questions where quiz_id = p_quiz;
  select coalesce(jsonb_object_agg(x.qid::text, x.opts), '{}'::jsonb) into v_opts
    from (select qu.id as qid,
                 (select jsonb_agg(o.id order by case when q.shuffle_options then random()
                                                      else o.position::double precision end)
                    from question_options o where o.question_id = qu.id) as opts
            from questions qu
           where qu.quiz_id = p_quiz and qu.type = 'multiple_choice') x;
  select count(*) + 1 into v_attempt from exam_sessions
   where quiz_id = p_quiz and student_id = auth.uid();
  insert into exam_sessions (quiz_id, student_id, attempt_no, deadline_at, question_order, option_orders)
  values (p_quiz, auth.uid(), v_attempt, v_deadline, coalesce(v_order, '{}'), v_opts)
  returning * into s;
  -- Only the first attempt needs the quiz write and its update triggers.
  if q.locked_at is null then
    update quizzes set locked_at = now() where id = p_quiz;
  end if;
  return s;
end $$;

commit;
