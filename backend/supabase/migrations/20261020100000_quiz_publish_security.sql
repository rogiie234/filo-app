-- M7-BE-01: serialize publication/first start and close edit-lock bypasses.
-- Applied migrations are immutable. DEV execution/acceptance is owner-owned.
begin;

-- Internal helper: lock both old and new parents in stable order. No client grant.
create or replace function public.lock_quiz_content(p_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare q quizzes;
begin
  for q in select * from quizzes where id = any(p_ids) order by id for update loop
    if auth.uid() is not null then
      if not current_user_ok() or not is_class_owner(q.class_id)
         or q.deleted_at is not null or not class_is_open(q.class_id) then
        raise exception 'Quiz is inaccessible or read-only' using errcode = '42501';
      end if;
      if q.locked_at is not null then
        raise exception 'This quiz has already been started by a student' using errcode = '22023';
      end if;
    end if;
  end loop;
end $$;
revoke all on function public.lock_quiz_content(uuid[]) from public, anon, authenticated;

create or replace function public.guard_question_edits() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then perform lock_quiz_content(array[new.quiz_id]);
  elsif tg_op = 'DELETE' then perform lock_quiz_content(array[old.quiz_id]);
  else perform lock_quiz_content(array[old.quiz_id, new.quiz_id]);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create or replace function public.guard_option_key_edits() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_ids uuid[]; v_old uuid; v_new uuid;
begin
  if tg_op <> 'INSERT' then v_old := old.question_id; end if;
  if tg_op <> 'DELETE' then v_new := new.question_id; end if;
  -- Resolve and lock both parent quizzes, including the source on reassignment.
  -- Pin the question rows before resolving parents so a concurrent question move
  -- cannot make this guard check an obsolete quiz. Conflicting lock orders may
  -- abort one transaction with 40P01; PostgreSQL rolls that transaction back.
  select array_agg(distinct x.quiz_id) into v_ids from (
    select quiz_id from questions where id in (v_old,v_new) order by id for update
  ) x;
  perform lock_quiz_content(v_ids);
  if tg_op = 'UPDATE' and new.question_id is distinct from old.question_id then
    raise exception 'Options and keys cannot be moved between questions' using errcode = '22023';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create or replace function public.refresh_quiz_totals() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_ids uuid[];
begin
  if tg_op = 'INSERT' then v_ids := array[new.quiz_id];
  elsif tg_op = 'DELETE' then v_ids := array[old.quiz_id];
  else v_ids := array[old.quiz_id,new.quiz_id]; end if;
  update quizzes q set
    total_points = coalesce((select sum(x.points) from questions x where x.quiz_id=q.id),0),
    has_essay = exists(select 1 from questions x where x.quiz_id=q.id and x.type='essay')
    where q.id = any(v_ids);
  return null;
end $$;

create or replace function public.guard_quiz_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and old.locked_at is not null and (
       new.type is distinct from old.type
    or new.instructions is distinct from old.instructions
    or new.time_limit_minutes is distinct from old.time_limit_minutes
    or new.opens_at is distinct from old.opens_at
    or new.shuffle_questions is distinct from old.shuffle_questions
    or new.shuffle_options is distinct from old.shuffle_options
    or new.show_correct_answers is distinct from old.show_correct_answers
    or new.passing_percent is distinct from old.passing_percent) then
    raise exception 'This quiz has already been started. Only the title and closing time can change.' using errcode = '22023';
  end if;
  return new;
end $$;

create or replace function public.publish_quiz(p_quiz uuid) returns quizzes
language plpgsql security definer set search_path = public as $$
declare q quizzes; v_bad integer; c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into q from quizzes where id = p_quiz and deleted_at is null for update;
  if not found or not is_class_owner(q.class_id) then raise exception 'Not allowed'; end if;
  if not class_is_open(q.class_id) then raise exception 'This class is archived'; end if;
  if q.status = 'published' then return q; end if;
  if q.opens_at is null or q.closes_at is null then
    raise exception 'Set the opening and closing time';
  end if;
  if q.closes_at <= q.opens_at or q.closes_at <= now() then
    raise exception 'The closing time must be in the future and after the opening time';
  end if;
  if not exists (select 1 from questions where quiz_id = p_quiz) then
    raise exception 'Add at least one question';
  end if;
  select count(*) into v_bad
    from questions qu left join answer_keys k on k.question_id = qu.id
   where qu.quiz_id = p_quiz and qu.type <> 'essay' and (
         k.question_id is null
      or (qu.type = 'multiple_choice' and (
            k.correct_option_id is null
         or not exists (select 1 from question_options o
                         where o.id = k.correct_option_id and o.question_id = qu.id)
         or (select count(*) from question_options o2 where o2.question_id = qu.id) < 2
         or (select count(*) from question_options o3 where o3.question_id = qu.id) > 10))
      or (qu.type = 'true_false' and k.correct_boolean is null)
      or (qu.type = 'identification' and coalesce(array_length(k.accepted_answers, 1), 0) = 0));
  if v_bad > 0 then raise exception '% question(s) are missing a valid answer key', v_bad; end if;
  update quizzes set status = 'published', published_at = now()
   where id = p_quiz returning * into q;
  select * into c from classes where id = q.class_id;
  insert into notifications (recipient_id, class_id, type, title, body, target_type, target_id)
  select m.student_id, q.class_id, 'quiz_published', 'New ' || q.type::text,
         'New ' || q.type::text || ' in ' || c.course || ': ' || q.title || ', opens '
           || to_char(q.opens_at at time zone 'Asia/Manila', 'Mon DD, HH12:MI AM'),
         'quiz', q.id
    from class_members m where m.class_id = q.class_id and m.status = 'active';
  return q;
end $$;

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
  update quizzes set locked_at = coalesce(locked_at, now()) where id = p_quiz;
  return s;
end $$;

commit;
