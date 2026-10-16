-- Class lifecycle access fixes. Existing migrations remain unchanged.
-- No RPC signatures change. Apply after the verified-session gate.
begin;

create or replace function public.delete_class(p_class uuid, p_section text) returns void
language plpgsql security definer set search_path = public as $$
declare c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  select * into c from classes where id = p_class for update;
  if c.section is distinct from p_section then
    raise exception 'The section name does not match';
  end if;
  update classes set deleted_at = now() where id = p_class;
end $$;

drop policy classes_select on public.classes;
create policy classes_select on public.classes for select to authenticated
using (public.current_user_ok() and (owner_id = auth.uid() or
  (deleted_at is null and exists (select 1 from public.class_members m
    where m.class_id = classes.id and m.student_id = auth.uid()
      and m.status in ('pending', 'active')))));

-- Keep work for the instructor while revoking former members' cloud access.
drop policy submissions_select on public.submissions;
create policy submissions_select on public.submissions for select to authenticated
using (public.current_user_ok() and
 ((student_id = auth.uid() and public.is_class_member(public.submission_class(id)))
  or (status = 'turned_in' and public.owns_post(post_id))));
drop policy grades_select on public.submission_grades;
create policy grades_select on public.submission_grades for select to authenticated
using (public.current_user_ok() and
 (public.is_class_owner(public.submission_class(submission_id)) or
  (returned_at is not null and public.submission_student(submission_id) = auth.uid()
   and public.is_class_member(public.submission_class(submission_id)))));


create or replace function public.can_see_submission(p_sub uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from submissions s join posts p on p.id = s.post_id
    where s.id = p_sub
      and ((s.student_id = auth.uid() and is_class_member(p.class_id)) or (s.status = 'turned_in' and is_class_owner(p.class_id)))));
end;
$$;

create or replace function public.own_draft_submission(p_sub uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from submissions s
    where s.id = p_sub and s.student_id = auth.uid() and s.status = 'draft' and is_class_member(submission_class(s.id)) and class_is_open(submission_class(s.id))));
end;
$$;

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
           'server_now', now())
         || case when v_rel is not null then jsonb_build_object('score', s.total_score)
                 else '{}'::jsonb end;
end $$;

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
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id)) then
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

create or replace function public.save_answer(
  p_session uuid, p_question uuid,
  p_option uuid default null, p_bool boolean default null, p_text text default null
) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare s exam_sessions; qu questions;
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
  if s.status <> 'in_progress' or now() > s.deadline_at + interval '15 seconds' then
    raise exception 'This attempt is closed';
  end if;
  select * into qu from questions where id = p_question and quiz_id = s.quiz_id;
  if not found then raise exception 'Question not found'; end if;
  if qu.type = 'multiple_choice' and p_option is not null and not exists (
       select 1 from question_options where id = p_option and question_id = p_question) then
    raise exception 'Invalid option';
  end if;
  insert into exam_answers (session_id, question_id, option_id, bool_answer, text_answer, answered_at)
  values (p_session, p_question,
          case when qu.type = 'multiple_choice' then p_option end,
          case when qu.type = 'true_false' then p_bool end,
          case when qu.type in ('identification', 'essay') then left(p_text, 10000) end,
          now())
  on conflict (session_id, question_id) do update
    set option_id = excluded.option_id, bool_answer = excluded.bool_answer,
        text_answer = excluded.text_answer, answered_at = now(), updated_at = now();
  return now();
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
  select * into s from exam_sessions where id = p_session and student_id = auth.uid();
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id and is_class_member(q.class_id) and class_is_open(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  if p_left_at > s.deadline_at + interval '1 minute' then return; end if;
  insert into leave_events (id, session_id, student_id, left_at)
  values (p_event, p_session, auth.uid(), p_left_at)
  on conflict (id) do nothing;
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
  return jsonb_build_object('status', s.status, 'submitted_at', s.submitted_at);
end $$;

create function public.guard_class_content_write() returns trigger
language plpgsql security definer set search_path = public as $$
declare r jsonb; c uuid;
begin
  if current_setting('role', true) <> 'authenticated' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  r := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  case tg_table_name
    when 'posts', 'quizzes' then c := (r->>'class_id')::uuid;
    when 'post_attachments', 'submissions' then
      select class_id into c from posts where id = (r->>'post_id')::uuid;
    when 'submission_items', 'submission_grades' then
      c := submission_class((r->>'submission_id')::uuid);
    when 'questions', 'exam_sessions' then
      select class_id into c from quizzes where id = (r->>'quiz_id')::uuid;
    when 'question_options', 'answer_keys' then
      select q.class_id into c from questions x join quizzes q on q.id=x.quiz_id
        where x.id=(r->>'question_id')::uuid;
    when 'exam_answers', 'leave_events' then
      select q.class_id into c from exam_sessions x join quizzes q on q.id=x.quiz_id
        where x.id=(r->>'session_id')::uuid;
  end case;
  if not current_user_ok() or not class_is_open(c)
     or not (is_class_owner(c) or is_class_member(c)) then
    raise exception 'Class is read-only or inaccessible' using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke all on function public.guard_class_content_write() from public, anon, authenticated;


create trigger trg_class_content_write before insert or update or delete on public.posts
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.post_attachments
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.submissions
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.submission_items
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.submission_grades
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.quizzes
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.questions
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.question_options
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.answer_keys
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.exam_sessions
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.exam_answers
for each row execute function public.guard_class_content_write();

create trigger trg_class_content_write before insert or update or delete on public.leave_events
for each row execute function public.guard_class_content_write();

create or replace function public.decide_join(p_member uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare m class_members; c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into m from class_members where id = p_member;
  if not found then raise exception 'Request not found'; end if;
  select * into c from classes where id = m.class_id;
  if c.owner_id is distinct from auth.uid() or c.deleted_at is not null then
    raise exception 'Not allowed';
  end if;
  if not class_is_open(c.id) then raise exception 'Class is read-only' using errcode = '42501'; end if;
  if m.status <> 'pending' then raise exception 'This request is not pending'; end if;
  update class_members
     set status = case when p_approve then 'active'::member_status else 'declined'::member_status end,
         decided_at = now(), decided_by = auth.uid()
   where id = p_member;
  perform notify(m.student_id,
    (case when p_approve then 'join_approved' else 'join_declined' end)::notification_type,
    c.id,
    case when p_approve then 'Request approved' else 'Request declined' end,
    case when p_approve then 'You''ve been approved to join ' || c.section
         else 'Your request to join ' || c.section || ' was declined' end,
    'class', c.id);
end $$;

create or replace function public.approve_all_pending(p_class uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0; c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  select * into c from classes where id = p_class;
  if not class_is_open(p_class) then raise exception 'Class is read-only' using errcode = '42501'; end if;
  for r in
    with u as (
      update class_members set status = 'active', decided_at = now(), decided_by = auth.uid()
       where class_id = p_class and status = 'pending'
      returning student_id)
    select student_id from u
  loop
    perform notify(r.student_id, 'join_approved', p_class, 'Request approved',
                   'You''ve been approved to join ' || c.section, 'class', p_class);
    n := n + 1;
  end loop;
  return n;
end $$;

-- Storage paths follow the existing class/post/student folder contract.
-- Restrictive policies also constrain the existing permissive own-file policies.
create policy lifecycle_submission_read on storage.objects as restrictive
for select to authenticated using (bucket_id <> 'submissions' or
  (public.is_class_owner(((storage.foldername(name))[1])::uuid) or
   ((storage.foldername(name))[3] = auth.uid()::text and
    public.is_class_member(((storage.foldername(name))[1])::uuid))));
create policy lifecycle_content_insert on storage.objects as restrictive
for insert to authenticated with check (bucket_id not in ('banners','materials','submissions') or (public.class_is_open(((storage.foldername(name))[1])::uuid) and (public.is_class_owner(((storage.foldername(name))[1])::uuid) or public.is_class_member(((storage.foldername(name))[1])::uuid))));
create policy lifecycle_content_update on storage.objects as restrictive
for update to authenticated using (bucket_id not in ('banners','materials','submissions') or (public.class_is_open(((storage.foldername(name))[1])::uuid) and (public.is_class_owner(((storage.foldername(name))[1])::uuid) or public.is_class_member(((storage.foldername(name))[1])::uuid)))) with check (bucket_id not in ('banners','materials','submissions') or (public.class_is_open(((storage.foldername(name))[1])::uuid) and (public.is_class_owner(((storage.foldername(name))[1])::uuid) or public.is_class_member(((storage.foldername(name))[1])::uuid))));
create policy lifecycle_content_delete on storage.objects as restrictive
for delete to authenticated using (bucket_id not in ('banners','materials','submissions') or (public.class_is_open(((storage.foldername(name))[1])::uuid) and (public.is_class_owner(((storage.foldername(name))[1])::uuid) or public.is_class_member(((storage.foldername(name))[1])::uuid))));

commit;
