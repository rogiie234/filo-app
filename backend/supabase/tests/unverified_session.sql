-- Run ALL of this file in the DEV SQL Editor, after the gate migration.
-- Fixture inserts, OTP verification, and device trust are all rolled back.
begin;
create temporary table otp_gate_results(test text, result text) on commit drop;
grant select, insert on otp_gate_results to authenticated;

do $$
declare
  u uuid; s uuid; c uuid := gen_random_uuid(); p uuid := gen_random_uuid();
  sub uuid := gen_random_uuid(); q uuid := gen_random_uuid();
  question uuid := gen_random_uuid(); opt uuid := gen_random_uuid();
  exam uuid := gen_random_uuid(); challenge uuid := gen_random_uuid();
  hash text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  r record; n bigint;
begin
  select user_id, id into u, s from auth.sessions limit 1;
  if s is null then raise exception 'Sign in with a DEV test account first'; end if;
  insert into public.profiles(id, role, display_name)
    values(u, 'instructor', 'OTP gate fixture') on conflict(id) do nothing;
  insert into public.classes(id, owner_id, course, section, school_year)
    values(c, u, 'OTP gate fixture', 'Test', '2026');
  insert into public.class_members(class_id, student_id, status) values(c, u, 'active');
  insert into public.posts(id, class_id, author_id, kind, title, points, due_at)
    values(p, c, u, 'assignment', 'OTP test', 10, now() + interval '1 day');
  insert into public.post_attachments(post_id, kind, name, url)
    values(p, 'link', 'Fixture', 'https://example.com');
  insert into public.submissions(id, post_id, student_id) values(sub, p, u);
  insert into public.submission_items(submission_id, kind, text_content)
    values(sub, 'text', 'OTP fixture');
  insert into public.submission_grades(submission_id, score, graded_by)
    values(sub, 1, u);
  insert into public.quizzes(id, class_id, author_id, title) values(q, c, u, 'OTP test');
  insert into public.questions(id, quiz_id, type, prompt)
    values(question, q, 'multiple_choice', 'OTP fixture?');
  insert into public.question_options(id, question_id, text) values(opt, question, 'Yes');
  insert into public.answer_keys(question_id, correct_option_id) values(question, opt);
  insert into public.exam_sessions(id, quiz_id, student_id, deadline_at)
    values(exam, q, u, now() + interval '1 hour');
  insert into public.exam_answers(session_id, question_id, option_id)
    values(exam, question, opt);
  insert into public.leave_events(id, session_id, student_id, left_at)
    values(gen_random_uuid(), exam, u, now());
  insert into public.second_chances(quiz_id, student_id, previous_session_id, reason, granted_by)
    values(q, u, exam, 'OTP fixture reason', u);
  insert into public.bank_questions(owner_id, type, prompt) values(u, 'true_false', 'OTP fixture?');
  insert into public.device_tokens(user_id, fcm_token) values(u, gen_random_uuid()::text);
  insert into public.notification_settings(user_id, class_id, type) values(u, c, 'announcement');
  insert into public.notifications(recipient_id, type, title) values(u, 'announcement', 'OTP fixture');
  insert into public.ai_usage_log(user_id, kind) values(u, 'chat');
  insert into public.otp_codes(id, user_id, session_id, device_hash, code_hash, expires_at, delivery_status)
    values(challenge, u, s, hash, repeat('a', 64), now() + interval '10 minutes', 'sent');
  insert into public.trusted_devices(user_id, device_hash) values(u, repeat('f', 64))
    on conflict(user_id, device_hash) do nothing;
  -- This session is unverified; leave another server-only row for read testing.
  insert into public.verified_sessions(session_id, user_id) values(gen_random_uuid(), u);
  delete from public.verified_sessions where session_id = s;
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', u, 'role', 'authenticated', 'session_id', s)::text, true);
  perform set_config('otp_test.hash', hash, true);
  perform set_config('otp_test.challenge', challenge::text, true);
  perform set_config('otp_test.class', c::text, true);
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('select count(*) from public.%I', r.tablename) into n;
    if n = 0 then raise exception 'Missing fixture for %', r.tablename; end if;
  end loop;
end;
$$;

set local role authenticated;
do $$
declare r record; n bigint; args text; response jsonb;
begin
  if public.is_session_verified() then raise exception 'Session unexpectedly verified'; end if;
  for r in select tablename from pg_tables where schemaname = 'public' loop
    begin
      execute format('select count(*) from public.%I', r.tablename) into n;
      if n <> 0 then raise exception 'DATA LEAK: % returned % rows', r.tablename, n; end if;
      insert into otp_gate_results values('table: ' || r.tablename, 'PASS: zero rows');
    exception when insufficient_privilege then
      insert into otp_gate_results values('table: ' || r.tablename, 'PASS: denied');
    end;
  end loop;
  -- Exercise every callable definer function with typed NULL arguments.
  -- Only the session-status/OTP-bootstrap functions are exempt.
  for r in select p.oid, p.proname, p.proargtypes from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.prosecdef and p.prokind = 'f'
      and has_function_privilege(current_user, p.oid, 'execute')
      and p.proname not in ('is_session_verified', 'current_user_ok', 'check_device_session')
  loop
    select string_agg('NULL::' || format_type(t, null), ', ' order by ord)
      into args from unnest(r.proargtypes::oid[]) with ordinality as a(t, ord);
    begin
      execute format('select public.%I(%s)', r.proname, coalesce(args, ''));
      raise exception 'RPC BYPASS: % did not reject the unverified session', r.proname;
    exception when insufficient_privilege then
      insert into otp_gate_results values('function: ' || r.proname, 'PASS: denied');
    end;
  end loop;
  response := public.check_device_session(current_setting('otp_test.hash'));
  if response <> '{"needs_otp":true,"verified":false}'::jsonb
     or public.is_session_verified() then raise exception 'New device bypass'; end if;
  insert into otp_gate_results values('new device', 'PASS: requires OTP');
end;
$$;

reset role;
do $$
declare response jsonb;
begin
  response := public.verify_device_otp(
    current_setting('otp_test.challenge')::uuid, auth.uid(),
    (auth.jwt()->>'session_id')::uuid, current_setting('otp_test.hash'), repeat('b', 64));
  if response->>'error' is distinct from 'OTP_WRONG' or public.is_session_verified() then
    raise exception 'Wrong OTP verified session'; end if;
  response := public.verify_device_otp(
    current_setting('otp_test.challenge')::uuid, auth.uid(),
    (auth.jwt()->>'session_id')::uuid, current_setting('otp_test.hash'), repeat('a', 64));
  if response->>'verified' is distinct from 'true' then raise exception 'Correct OTP failed'; end if;
  if not exists(select 1 from public.trusted_devices
    where user_id = auth.uid() and device_hash = current_setting('otp_test.hash'))
    or not public.is_session_verified() then raise exception 'OTP records missing'; end if;
  insert into otp_gate_results values('correct OTP', 'PASS: device and session registered');
  response := public.verify_device_otp(
    current_setting('otp_test.challenge')::uuid, auth.uid(),
    (auth.jwt()->>'session_id')::uuid, current_setting('otp_test.hash'), repeat('a', 64));
  if response->>'error' is distinct from 'OTP_USED' then
    raise exception 'Consumed OTP was reusable'; end if;
  insert into otp_gate_results values('OTP replay', 'PASS: consumed code rejected');
end;
$$;
set local role authenticated;
do $$
declare n bigint;
begin
  select count(*) into n from public.classes where id = current_setting('otp_test.class')::uuid;
  if n <> 1 then raise exception 'Verified owner cannot read class'; end if;
  insert into otp_gate_results values('verified read', 'PASS: own class visible');
end;
$$;
reset role;
delete from public.verified_sessions where session_id = (auth.jwt()->>'session_id')::uuid;
set local role authenticated;
do $$
declare response jsonb;
begin
  response := public.check_device_session(current_setting('otp_test.hash'));
  if response <> '{"needs_otp":false,"verified":true}'::jsonb
    or not public.is_session_verified() then raise exception 'Trusted device failed'; end if;
  insert into otp_gate_results values('trusted device', 'PASS: session verified without OTP');
end;
$$;
select * from otp_gate_results order by test;
rollback;
