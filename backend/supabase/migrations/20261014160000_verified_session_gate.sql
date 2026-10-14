-- Device bootstrap is the sole authenticated data function allowed before OTP.
create or replace function public.check_device_session(p_device_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_claim text := auth.jwt() ->> 'session_id';
  v_session_id uuid;
  v_now timestamptz := clock_timestamp();
begin
  if v_user_id is null or v_claim is null or v_claim !~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'Valid authentication session required' using errcode = '42501';
  end if;
  v_session_id := v_claim::uuid;
  if not exists (select 1 from auth.sessions
    where id = v_session_id and user_id = v_user_id) then
    raise exception 'Invalid login session' using errcode = '42501';
  end if;
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid device hash' using errcode = '22023';
  end if;
  update public.trusted_devices set last_seen_at = v_now
    where user_id = v_user_id and device_hash = p_device_hash;
  if not found then
    return jsonb_build_object('needs_otp', true, 'verified', false);
  end if;
  insert into public.verified_sessions(session_id, user_id, device_hash, verified_at)
    values(v_session_id, v_user_id, p_device_hash, v_now)
    on conflict(session_id) do update set
      device_hash = excluded.device_hash, verified_at = excluded.verified_at
    where public.verified_sessions.user_id = excluded.user_id;
  if not found then raise exception 'Session ownership mismatch'; end if;
  return jsonb_build_object('needs_otp', false, 'verified', true);
end;
$$;
revoke all on function public.check_device_session(text) from public, anon;
grant execute on function public.check_device_session(text) to authenticated, service_role;

-- Missing/malformed claims fail closed; revoked Auth sessions cannot read data.
create or replace function public.is_session_verified()
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare v_claim text := auth.jwt() ->> 'session_id';
begin
  if auth.uid() is null or v_claim is null or v_claim !~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return exists (
    select 1 from public.verified_sessions v
    join auth.sessions s on s.id = v.session_id and s.user_id = v.user_id
    where v.user_id = auth.uid() and v.session_id = v_claim::uuid
  );
end;
$$;

-- Restrictive policies AND with existing policies, preventing permissive bypass.
do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security', r.tablename);
    execute format('create policy require_verified_session on public.%I as restrictive for all to authenticated using (public.current_user_ok()) with check (public.current_user_ok())', r.tablename);
  end loop;
end;
$$;

-- Storage metadata and private file access obey the same gate.
create policy require_verified_session on storage.objects
  as restrictive for all to authenticated
  using (public.current_user_ok()) with check (public.current_user_ok());

-- Explicit guards on client-callable SECURITY DEFINER functions.
create or replace function public.my_role() returns user_role
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select role from profiles where id = auth.uid());
end;
$$;

create or replace function public.is_class_owner(p_class uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from classes c
    where c.id = p_class and c.owner_id = auth.uid() and c.deleted_at is null));
end;
$$;

create or replace function public.is_class_member(p_class uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from class_members m join classes c on c.id = m.class_id
    where m.class_id = p_class and m.student_id = auth.uid()
      and m.status = 'active' and c.deleted_at is null));
end;
$$;

create or replace function public.has_class_link(p_class uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from classes c
      where c.id = p_class and c.owner_id = auth.uid() and c.deleted_at is null)
    or exists (select 1 from class_members m join classes c on c.id = m.class_id
      where m.class_id = p_class and m.student_id = auth.uid()
        and m.status in ('pending', 'active') and c.deleted_at is null));
end;
$$;

create or replace function public.class_is_open(p_class uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from classes c
    where c.id = p_class and c.deleted_at is null and c.archived_at is null));
end;
$$;

create or replace function public.shares_class_with(p_user uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select p_user = auth.uid()
  -- I am the instructor and the person has any membership row in my class
  or exists (select 1 from class_members m join classes c on c.id = m.class_id
      where m.student_id = p_user and c.owner_id = auth.uid())
  -- the person is the instructor of a class where I am pending or active
  or exists (select 1 from classes c join class_members m on m.class_id = c.id
      where c.owner_id = p_user and m.student_id = auth.uid()
        and m.status in ('pending', 'active'))
  -- classmates
  or exists (select 1 from class_members a join class_members b on a.class_id = b.class_id
      where a.student_id = auth.uid() and a.status = 'active'
        and b.student_id = p_user and b.status = 'active'));
end;
$$;

create or replace function public.is_quiz_owner(p_quiz uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from quizzes q where q.id = p_quiz and is_class_owner(q.class_id)));
end;
$$;

create or replace function public.is_question_owner(p_question uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from questions qu join quizzes q on q.id = qu.quiz_id
    where qu.id = p_question and is_class_owner(q.class_id)));
end;
$$;

create or replace function public.owns_post(p_post uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from posts p where p.id = p_post and is_class_owner(p.class_id)));
end;
$$;

create or replace function public.can_see_post(p_post uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from posts p
    where p.id = p_post and (is_class_owner(p.class_id) or is_class_member(p.class_id))));
end;
$$;

create or replace function public.submission_student(p_sub uuid) returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select student_id from submissions where id = p_sub);
end;
$$;

create or replace function public.submission_class(p_sub uuid) returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select p.class_id from submissions s join posts p on p.id = s.post_id where s.id = p_sub);
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
    where s.id = p_sub and s.student_id = auth.uid() and s.status = 'draft'));
end;
$$;

create or replace function public.can_see_submission(p_sub uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select exists (select 1 from submissions s join posts p on p.id = s.post_id
    where s.id = p_sub
      and (s.student_id = auth.uid() or (s.status = 'turned_in' and is_class_owner(p.class_id)))));
end;
$$;

create or replace function public.session_quiz(p_session uuid) returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select quiz_id from exam_sessions where id = p_session);
end;
$$;

create or replace function public.request_join(p_code text) returns join_result
language plpgsql security definer set search_path = public as $$
declare c classes; m class_members; v_name text;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not current_user_ok() then raise exception 'Not signed in'; end if;
  if my_role() is distinct from 'student' then raise exception 'Only students can join classes'; end if;
  select * into c from classes where join_code = upper(btrim(p_code)) and deleted_at is null;
  if not found then return 'not_found'; end if;
  if c.archived_at is not null then return 'archived'; end if;
  select * into m from class_members where class_id = c.id and student_id = auth.uid();
  if found then
    if m.status = 'active' then return 'already_member'; end if;
    if m.status = 'pending' then return 'already_pending'; end if;
    update class_members
       set status = 'pending', requested_at = now(), decided_at = null, decided_by = null, left_at = null
     where id = m.id;
  else
    insert into class_members (class_id, student_id) values (c.id, auth.uid());
  end if;
  select display_name into v_name from profiles where id = auth.uid();
  perform notify(c.owner_id, 'join_request', c.id, 'New join request',
                 v_name || ' wants to join ' || c.section, 'class_members', c.id);
  return 'requested';
end $$;

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

create or replace function public.remove_member(p_class uuid, p_student uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  select * into c from classes where id = p_class;
  update class_members set status = 'removed', decided_at = now(), decided_by = auth.uid()
   where class_id = p_class and student_id = p_student and status = 'active';
  if found then
    perform notify(p_student, 'removed_from_class', p_class, 'Removed from class',
                   'You were removed from ' || c.section, 'class', p_class);
  end if;
end $$;

create or replace function public.leave_class(p_class uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not current_user_ok() then raise exception 'Not signed in'; end if;
  update class_members set status = 'left', left_at = now()
   where class_id = p_class and student_id = auth.uid() and status in ('pending', 'active');
end $$;

create or replace function public.archive_class(p_class uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  update classes set archived_at = now() where id = p_class;
end $$;

create or replace function public.restore_class(p_class uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  update classes set archived_at = null where id = p_class;
end $$;

create or replace function public.delete_class(p_class uuid, p_section text) returns void
language plpgsql security definer set search_path = public as $$
declare c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not is_class_owner(p_class) then raise exception 'Not allowed'; end if;
  select * into c from classes where id = p_class;
  if lower(btrim(c.section)) <> lower(btrim(coalesce(p_section, ''))) then
    raise exception 'The section name does not match';
  end if;
  update classes set deleted_at = now() where id = p_class;
end $$;

create or replace function public.restore_deleted_class(p_class uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not current_user_ok() then raise exception 'Not signed in'; end if;
  update classes set deleted_at = null
   where id = p_class and owner_id = auth.uid()
     and deleted_at is not null and deleted_at > now() - interval '14 days';
  if not found then raise exception 'This class can no longer be restored'; end if;
end $$;

create or replace function public.owned_class_count() returns integer
language plpgsql stable security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  return (select count(*)::int from classes where owner_id = auth.uid() and deleted_at is null);
end;
$$;

create or replace function public.start_submission(p_post uuid) returns submissions
language plpgsql security definer set search_path = public as $$
declare p posts; s submissions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  if not current_user_ok() then raise exception 'Not signed in'; end if;
  select * into p from posts where id = p_post and kind = 'assignment' and deleted_at is null;
  if not found or not is_class_member(p.class_id) then raise exception 'Assignment not found'; end if;
  if not class_is_open(p.class_id) then raise exception 'This class is archived'; end if;
  select * into s from submissions where post_id = p_post and student_id = auth.uid();
  if found then return s; end if;
  if p.due_at < now() and not p.accept_late then
    raise exception 'Submissions are closed for this assignment';
  end if;
  insert into submissions (post_id, student_id) values (p_post, auth.uid()) returning * into s;
  return s;
end $$;

create or replace function public.turn_in(p_submission uuid, p_comment text default null) returns submissions
language plpgsql security definer set search_path = public as $$
declare s submissions; p posts; v_late boolean; v_items integer;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission and student_id = auth.uid();
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'draft' then raise exception 'Already turned in'; end if;
  select * into p from posts where id = s.post_id;
  if not is_class_member(p.class_id) then raise exception 'Not allowed'; end if;
  if not class_is_open(p.class_id) then raise exception 'This class is archived'; end if;
  select count(*) into v_items from submission_items
   where submission_id = s.id and deleted_at is null;
  if v_items = 0 then raise exception 'Add at least one item before turning in'; end if;
  v_late := now() > p.due_at;
  if v_late and not p.accept_late then
    raise exception 'Submissions are closed for this assignment';
  end if;
  update submissions
     set status = 'turned_in', submitted_at = now(), is_late = v_late,
         private_comment = left(p_comment, 1000),
         unsubmit_until = case when v_late then now()
                               else least(now() + interval '10 minutes', p.due_at) end
   where id = s.id returning * into s;
  return s;
end $$;

create or replace function public.unsubmit(p_submission uuid) returns submissions
language plpgsql security definer set search_path = public as $$
declare s submissions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission and student_id = auth.uid();
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'turned_in' then raise exception 'This work is not turned in'; end if;
  if now() > s.unsubmit_until then raise exception 'The unsubmit window has passed'; end if;
  if exists (select 1 from submission_grades g
              where g.submission_id = s.id and g.returned_at is not null) then
    raise exception 'A grade was already returned';
  end if;
  update submissions
     set status = 'draft', submitted_at = null, is_late = false, unsubmit_until = null
   where id = s.id returning * into s;
  return s;
end $$;

create or replace function public.save_grade(p_submission uuid, p_score integer, p_feedback text default null)
returns submission_grades
language plpgsql security definer set search_path = public as $$
declare s submissions; p posts; g submission_grades;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission;
  if not found then raise exception 'Submission not found'; end if;
  select * into p from posts where id = s.post_id;
  if not is_class_owner(p.class_id) then raise exception 'Not allowed'; end if;
  if s.status <> 'turned_in' then raise exception 'Nothing to grade yet'; end if;
  if p_score < 0 or p_score > p.points then
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
  for r in
    with u as (
      update submission_grades g set returned_at = now()
        from submissions s join posts p on p.id = s.post_id
       where g.submission_id = s.id
         and g.submission_id = any(p_ids)
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

create or replace function public.publish_quiz(p_quiz uuid) returns quizzes
language plpgsql security definer set search_path = public as $$
declare q quizzes; v_bad integer; c classes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into q from quizzes where id = p_quiz;
  if not found or not is_class_owner(q.class_id) then raise exception 'Not allowed'; end if;
  if q.status = 'published' then return q; end if;
  if not class_is_open(q.class_id) then raise exception 'This class is archived'; end if;
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
  select * into q from quizzes where id = p_quiz and status = 'published' and deleted_at is null;
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
  if s.status = 'in_progress' then
    perform finalize_session(p_session,
      (case when now() > s.deadline_at then 'auto_submitted' else 'submitted' end)::session_status);
    perform maybe_release_results(s.quiz_id);
  end if;
  select * into s from exam_sessions where id = p_session;
  return jsonb_build_object('status', s.status, 'submitted_at', s.submitted_at);
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
  select * into s from exam_sessions where id = a.session_id;
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

create or replace function public.release_results(p_quiz uuid) returns void
language plpgsql security definer set search_path = public as $$
declare q quizzes;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into q from quizzes where id = p_quiz;
  if not found or not is_class_owner(q.class_id) then raise exception 'Not allowed'; end if;
  if q.results_released_at is not null then return; end if;
  if q.opens_at is null or q.opens_at > now() then raise exception 'This quiz has not opened yet'; end if;
  if exists (select 1 from exam_sessions where quiz_id = p_quiz and status = 'in_progress') then
    raise exception 'Some students are still taking this quiz';
  end if;
  if exists (select 1 from exam_sessions
              where quiz_id = p_quiz and status in ('submitted', 'auto_submitted')
                and not grading_complete) then
    raise exception 'Grade all essay answers first';
  end if;
  update quizzes set closes_at = least(closes_at, now()) where id = p_quiz;
  perform maybe_release_results(p_quiz);
end $$;

create or replace function public.grant_second_chance(
  p_quiz uuid, p_student uuid, p_reason text, p_proof text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare q quizzes; s exam_sessions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into q from quizzes where id = p_quiz;
  if not found or not is_class_owner(q.class_id) then raise exception 'Not allowed'; end if;
  if q.results_released_at is not null then
    raise exception 'Results are already released. Create a new quiz instead.';
  end if;
  if q.closes_at <= now() then
    raise exception 'Extend the closing time first so the student can retake it';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    raise exception 'Please give a reason of at least 10 characters';
  end if;
  select * into s from exam_sessions
   where quiz_id = p_quiz and student_id = p_student and status <> 'voided'
   order by attempt_no desc limit 1;
  if not found then raise exception 'This student has no attempt to reset'; end if;
  update exam_sessions set status = 'voided' where id = s.id;
  insert into second_chances (quiz_id, student_id, previous_session_id, reason, proof_note, granted_by)
  values (p_quiz, p_student, s.id, btrim(p_reason), left(p_proof, 1000), auth.uid());
  perform notify(p_student, 'second_chance', q.class_id, 'Another attempt granted',
                 'Your instructor allowed you another attempt at ' || q.title, 'quiz', q.id);
end $$;

create or replace function public.generate_join_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from classes where join_code = code);
  end loop;
  return code;
end $$;
