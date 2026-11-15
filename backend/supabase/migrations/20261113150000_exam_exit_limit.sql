-- New attempts adopt the limit; existing attempts remain logging-only.
-- Deploy with the compatible client before opening new student attempts.
begin;
alter table public.exam_sessions add column leave_limit integer check (leave_limit is null or leave_limit = 5);
alter table public.exam_sessions add column auto_submit_reason text check (auto_submit_reason is null or auto_submit_reason in ('leave_limit', 'timeout'));
alter table public.exam_sessions alter column leave_limit set default 5;

create or replace function public.get_exam(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s exam_sessions; v_questions jsonb; v_saved jsonb;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions where id = p_session and student_id = auth.uid();
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id) and class_is_open(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  if s.status <> 'in_progress' then raise exception 'This attempt is finished'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', qu.id, 'type', qu.type, 'prompt', qu.prompt, 'points', qu.points,
           'options', case when qu.type = 'multiple_choice' then
              (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'text', o.text) order by t.ord), '[]'::jsonb)
                 from jsonb_array_elements_text(s.option_orders -> (qu.id)::text)
                      with ordinality as t(oid, ord)
                 join question_options o on o.id = t.oid::uuid)
              else null end)
           order by u.ord), '[]'::jsonb)
    into v_questions
    from unnest(s.question_order) with ordinality as u(qid, ord)
    join questions qu on qu.id = u.qid;
  select coalesce(jsonb_agg(jsonb_build_object(
           'question_id', a.question_id, 'option_id', a.option_id,
           'bool_answer', a.bool_answer, 'text_answer', a.text_answer)), '[]'::jsonb)
    into v_saved from exam_answers a where a.session_id = s.id;
  return jsonb_build_object(
    'session_id', s.id, 'quiz_id', s.quiz_id, 'started_at', s.started_at,
    'deadline_at', s.deadline_at, 'server_now', now(),
    'leave_limit', s.leave_limit, 'leave_count', s.leave_count, 'auto_submit_reason', s.auto_submit_reason, 'leave_event_ids', (select coalesce(jsonb_agg(e.id order by e.left_at,e.id), '[]'::jsonb) from leave_events e where e.session_id=s.id),
    'questions', v_questions, 'saved_answers', v_saved);
end $$;

create or replace function public.get_my_session(p_quiz uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s exam_sessions; v_rel timestamptz;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions
   where quiz_id = p_quiz and student_id = auth.uid() and status <> 'voided'
   order by attempt_no desc limit 1;
  if not found then return null; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  select results_released_at into v_rel from quizzes where id = p_quiz;
  return jsonb_build_object(
           'session_id', s.id, 'status', s.status, 'attempt_no', s.attempt_no,
           'started_at', s.started_at, 'deadline_at', s.deadline_at,
           'submitted_at', s.submitted_at, 'results_released', v_rel is not null,
           'server_now', now(), 'leave_limit', s.leave_limit, 'leave_count', s.leave_count, 'auto_submit_reason', s.auto_submit_reason, 'leave_event_ids', (select coalesce(jsonb_agg(e.id order by e.left_at,e.id), '[]'::jsonb) from leave_events e where e.session_id=s.id))
         || case when v_rel is not null then jsonb_build_object('score', s.total_score)
                 else '{}'::jsonb end;
end $$;

create or replace function public.log_leave(p_event uuid, p_session uuid, p_left_at timestamptz)
returns void
language plpgsql security definer set search_path = public as $$
declare s exam_sessions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions where id = p_session and student_id = auth.uid() for update;
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id) and class_is_open(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  if s.leave_limit is not null and s.status <> 'in_progress' then return; end if;
  if p_left_at > s.deadline_at + interval '1 minute' then return; end if;
  insert into leave_events (id, session_id, student_id, left_at)
  values (p_event, p_session, auth.uid(), p_left_at)
  on conflict (id) do nothing;
end $$;

create or replace function public.finalize_session(p_session uuid, p_status session_status) returns void
language plpgsql security definer set search_path = public as $$
begin
  update exam_sessions
     set status = p_status,
         auto_submit_reason = case when p_status = 'auto_submitted'
           then coalesce(auto_submit_reason, 'timeout') else auto_submit_reason end,
         submitted_at = case when p_status = 'auto_submitted'
                             then least(now(), deadline_at) else now() end
   where id = p_session and status = 'in_progress';
  if found then perform grade_session(p_session); end if;
end $$;

create or replace function public.bump_leave_count() returns trigger
language plpgsql security definer set search_path = public as $$
declare s exam_sessions;
begin
  update exam_sessions set leave_count=leave_count+1 where id=new.session_id returning * into s;
  if s.leave_limit is not null and s.leave_count >= s.leave_limit and s.status='in_progress' then
    update exam_sessions set auto_submit_reason='leave_limit' where id=s.id;
    perform finalize_session(s.id, 'auto_submitted');
    perform maybe_release_results(s.quiz_id);
  end if;
  return null;
end $$;

create or replace function public.submit_exam(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s exam_sessions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions where id = p_session and student_id = auth.uid();
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id) and class_is_open(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  if s.status = 'in_progress' then
    perform finalize_session(p_session,
      (case when now() > s.deadline_at then 'auto_submitted' else 'submitted' end)::session_status);
    perform maybe_release_results(s.quiz_id);
  end if;
  select * into s from exam_sessions where id = p_session;
  return jsonb_build_object('status', s.status, 'submitted_at', s.submitted_at, 'auto_submit_reason', s.auto_submit_reason);
end $$;

commit;
