-- M8-BE-01: reject oversized text instead of silently losing the tail.
-- Signature, caller checks, grace window and upsert behavior are unchanged.
begin;

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
  if qu.type in ('identification', 'essay') and char_length(p_text) > 10000 then
    raise exception 'Answer must be at most 10000 characters' using errcode = '22001';
  end if;
  insert into exam_answers (session_id, question_id, option_id, bool_answer, text_answer, answered_at)
  values (p_session, p_question,
          case when qu.type = 'multiple_choice' then p_option end,
          case when qu.type = 'true_false' then p_bool end,
          case when qu.type in ('identification', 'essay') then p_text end,
          now())
  on conflict (session_id, question_id) do update
    set option_id = excluded.option_id, bool_answer = excluded.bool_answer,
        text_answer = excluded.text_answer, answered_at = now(), updated_at = now();
  return now();
end $$;

commit;
