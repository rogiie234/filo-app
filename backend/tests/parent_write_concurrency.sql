-- DEV ONLY, maintained two-connection regression. NOT RUN; DO NOT execute the whole file.
-- Run labeled blocks separately as postgres in two independent connections, as in quiz_concurrency.sql.
-- Setup COMMITS dedicated fixtures. Always run CLEANUP after both connections finish.
-- Requires the two 20261115 migrations. No JWT secrets, extensions or new dependencies.
-- Storage checks change metadata only; actual blob/API verification remains owner-owned.
-- A sleeps 15 seconds; start B immediately in that window. A/B statement timeout must exceed 20s.

-- 1. SETUP: one connection, entire BEGIN..COMMIT block.
begin;
select set_config('request.jwt.claims','{}',true);
do $$ begin
  if exists(select 1 from public.profiles where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002'))
    or exists(select 1 from auth.users where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002'))
    or exists(select 1 from public.classes where id='a1510001-0000-4000-8000-000000000004')
    or exists(select 1 from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt') then
    raise exception 'Fixture collision: stop and inspect; do not overwrite';
  end if;
end $$;
insert into auth.users(id) values('a1510001-0000-4000-8000-000000000001'),('a1510001-0000-4000-8000-000000000002');
insert into auth.sessions(id,user_id) values('a1510001-0000-4000-8000-000000000003','a1510001-0000-4000-8000-000000000002');
insert into public.profiles(id,role,display_name) values
  ('a1510001-0000-4000-8000-000000000001','instructor','Parent-lock regression instructor'),
  ('a1510001-0000-4000-8000-000000000002','student','Parent-lock regression student');
insert into public.verified_sessions(session_id,user_id) values('a1510001-0000-4000-8000-000000000003','a1510001-0000-4000-8000-000000000002');
insert into public.classes(id,owner_id,course,section,school_year)
  values('a1510001-0000-4000-8000-000000000004','a1510001-0000-4000-8000-000000000001','Parent-lock regression','QA parent locks','2026');
insert into public.posts(id,class_id,author_id,kind,title,points,due_at,allow_files,max_files,accept_late)
  values('a1510001-0000-4000-8000-000000000005','a1510001-0000-4000-8000-000000000004','a1510001-0000-4000-8000-000000000001','assignment','Parent-lock fixture',1,now()+interval '1 day',true,5,true);
insert into public.class_members(class_id,student_id,status) values('a1510001-0000-4000-8000-000000000004','a1510001-0000-4000-8000-000000000002','active');
insert into public.submissions(id,post_id,student_id) values('a1510001-0000-4000-8000-000000000006','a1510001-0000-4000-8000-000000000005','a1510001-0000-4000-8000-000000000002');
insert into public.submission_items(submission_id,kind,storage_path) values('a1510001-0000-4000-8000-000000000006','file','a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt');
insert into storage.objects(bucket_id,name,metadata) values('submissions','a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt','{"revision":0}');
insert into public.quizzes(id,class_id,author_id,title,status,opens_at,closes_at)
  values('a1510001-0000-4000-8000-000000000007','a1510001-0000-4000-8000-000000000004','a1510001-0000-4000-8000-000000000001','Parent-lock fixture','published',now()-interval '1 hour',now()+interval '1 day');
insert into public.questions(id,quiz_id,type,prompt,points) values('a1510001-0000-4000-8000-000000000008','a1510001-0000-4000-8000-000000000007','true_false','Fixture answer is true',1);
insert into public.answer_keys(question_id,correct_boolean) values('a1510001-0000-4000-8000-000000000008',true);
insert into public.exam_sessions(id,quiz_id,student_id,deadline_at,question_order)
  values('a1510001-0000-4000-8000-000000000009','a1510001-0000-4000-8000-000000000007','a1510001-0000-4000-8000-000000000002',now()+interval '1 hour',array['a1510001-0000-4000-8000-000000000008'::uuid]);
-- Seed an existing answer: an INSERT's foreign-key lock must not masquerade as the writer's parent lock.
insert into public.exam_answers(session_id,question_id,bool_answer) values('a1510001-0000-4000-8000-000000000009','a1510001-0000-4000-8000-000000000008',false);
commit;

-- 2A. FINALIZATION FIRST: run this whole block in A, immediately start 2B in B.
begin;
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
-- Hold only parents during the pause; answer/object row locks would hide the missing-lock bug.
select id from public.exam_sessions where id='a1510001-0000-4000-8000-000000000009' for no key update;
select id from public.submissions where id='a1510001-0000-4000-8000-000000000006' for no key update;
select pg_sleep(15);
select public.finalize_session('a1510001-0000-4000-8000-000000000009','submitted');
set local role authenticated;
select (public.turn_in('a1510001-0000-4000-8000-000000000006')).id;
commit;

-- 2B. Run WHILE 2A sleeps. Every operation must block, not silently finish.
begin;
set local lock_timeout='1s';
set local storage.allow_delete_query='true';
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$ declare operation text; begin
  foreach operation in array array[
    $q$select public.save_answer('a1510001-0000-4000-8000-000000000009','a1510001-0000-4000-8000-000000000008',p_bool=>true)$q$,
    $q$update storage.objects set metadata='{"revision":99}' where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt'$q$,
    $q$delete from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt'$q$
  ] loop
    begin
      execute operation;
      raise exception 'FAIL: mutation bypassed the held parent lock: %',operation;
    exception when lock_not_available then
      raise notice 'PASS: mutation waits for parent lock';
    end;
  end loop;
end $$;
commit;

-- 3. After BOTH 2A/2B finish: committed state and post-finalization refusal.
begin;
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$ begin
  begin
    perform public.save_answer('a1510001-0000-4000-8000-000000000009','a1510001-0000-4000-8000-000000000008',p_bool=>true);
    raise exception 'FAIL: submitted answer changed';
  exception when raise_exception then
    if sqlerrm<>'This attempt is closed' then raise; end if;
  end;
  begin
    update storage.objects set metadata='{"revision":99}' where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt';
    raise exception 'FAIL: turned-in object changed';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  if not exists(select 1 from public.exam_sessions s join public.exam_answers a on a.session_id=s.id
    where s.id='a1510001-0000-4000-8000-000000000009' and s.status='submitted' and a.bool_answer=false and a.points_awarded=0 and s.auto_score=0)
    or not exists(select 1 from public.submissions where id='a1510001-0000-4000-8000-000000000006' and status='turned_in')
    or not exists(select 1 from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt' and metadata='{"revision":0}'::jsonb) then
    raise exception 'FAIL: finalization-first state changed';
  end if;
  raise notice 'PASS: finalization-first state and scores preserved';
end $$;
commit;

-- 4. RESET before reverse ordering; run once only after step 3 succeeds.
begin;
select set_config('request.jwt.claims','{}',true);
update public.exam_sessions set status='in_progress',submitted_at=null,deadline_at=now()+interval '1 hour' where id='a1510001-0000-4000-8000-000000000009';
update public.submissions set status='draft',submitted_at=null,unsubmit_until=null where id='a1510001-0000-4000-8000-000000000006';
commit;

-- 5A. WRITER FIRST: run in A, immediately start 5B in B.
begin;
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
select public.save_answer('a1510001-0000-4000-8000-000000000009','a1510001-0000-4000-8000-000000000008',p_bool=>true);
update storage.objects set metadata='{"revision":1}' where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt';
select pg_sleep(15);
commit;

-- 5B. Run WHILE 5A sleeps. Finalization must wait for both writers.
begin;
set local lock_timeout='1s';
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$ declare operation text; begin
  foreach operation in array array[
    $q$select public.submit_exam('a1510001-0000-4000-8000-000000000009')$q$,
    $q$select public.turn_in('a1510001-0000-4000-8000-000000000006')$q$
  ] loop
    begin
      execute operation;
      raise exception 'FAIL: finalization bypassed writer parent lock: %',operation;
    exception when lock_not_available then
      raise notice 'PASS: finalization waits for writer';
    end;
  end loop;
end $$;
commit;

-- 6. After BOTH 5A/5B finish: retry finalization and assert the committed writer values.
begin;
select set_config('request.jwt.claims','{"sub":"a1510001-0000-4000-8000-000000000002","session_id":"a1510001-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
select public.submit_exam('a1510001-0000-4000-8000-000000000009');
select (public.turn_in('a1510001-0000-4000-8000-000000000006')).id;
reset role;
do $$ begin
  if not exists(select 1 from public.exam_sessions s join public.exam_answers a on a.session_id=s.id
    where s.id='a1510001-0000-4000-8000-000000000009' and s.status='submitted' and a.bool_answer=true and a.points_awarded=1 and s.auto_score=1)
    or not exists(select 1 from public.submissions where id='a1510001-0000-4000-8000-000000000006' and status='turned_in')
    or not exists(select 1 from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt' and metadata='{"revision":1}'::jsonb) then
    raise exception 'FAIL: writer-first values were lost or graded incorrectly';
  end if;
  raise notice 'PASS: writer-first values and scores preserved';
end $$;
commit;

-- 7. CLEANUP after BOTH connections end; run even on failure (ROLLBACK aborted connections first).
-- This object is metadata-only, created above; never use this deletion for real blob uploads.
begin;
select set_config('request.jwt.claims','{}',true);
set local storage.allow_delete_query='true';
do $$ begin
  if not exists(select 1 from public.classes where id='a1510001-0000-4000-8000-000000000004' and owner_id='a1510001-0000-4000-8000-000000000001'
    and course='Parent-lock regression' and section='QA parent locks')
    or (select count(*) from public.profiles where (id='a1510001-0000-4000-8000-000000000001' and display_name='Parent-lock regression instructor')
      or (id='a1510001-0000-4000-8000-000000000002' and display_name='Parent-lock regression student'))<>2 then
    raise exception 'Fixture provenance mismatch: stop; no cleanup performed';
  end if;
  delete from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt';
  delete from public.classes where id='a1510001-0000-4000-8000-000000000004';
  delete from auth.users where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002');
  delete from public.profiles where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002');
  if exists(select 1 from public.classes where id='a1510001-0000-4000-8000-000000000004')
    or exists(select 1 from public.profiles where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002'))
    or exists(select 1 from auth.users where id in ('a1510001-0000-4000-8000-000000000001','a1510001-0000-4000-8000-000000000002'))
    or exists(select 1 from storage.objects where bucket_id='submissions' and name='a1510001-0000-4000-8000-000000000004/a1510001-0000-4000-8000-000000000005/a1510001-0000-4000-8000-000000000002/race.txt') then
    raise exception 'FAIL: fixture cleanup incomplete';
  end if;
  raise notice 'PASS: dedicated fixtures removed';
end $$;
commit;
