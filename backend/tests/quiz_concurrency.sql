-- DEV ONLY: MANUAL MULTI-SESSION REGRESSION. DO NOT RUN THIS WHOLE FILE.
-- Run only each numbered selection as instructed. Setup COMMITS dedicated fixtures;
-- unlike quizzes.sql/question_bank.sql these remain until section 7 cleanup.
-- Two SQL Editor tabs must execute concurrently. No real users/JWT secrets required.
-- A uses a 15-second open transaction; start B during that interval.
-- No PASS evidence is claimed by preparing this file. Capture both tabs' outputs.

-- 1. SETUP: select this entire BEGIN..COMMIT block once as postgres, in either tab.
begin;
select set_config('request.jwt.claims','{}',true);
do $$
begin
  if exists(select 1 from auth.users where id in ('a7be0001-0000-4000-8000-000000000001','a7be0001-0000-4000-8000-000000000003'))
     or exists(select 1 from profiles where id in ('a7be0001-0000-4000-8000-000000000001','a7be0001-0000-4000-8000-000000000003'))
     or exists(select 1 from classes where id='a7be0001-0000-4000-8000-000000000005') then
    raise exception 'M7 fixture collision: inspect/clean previous setup before retry; do not overwrite';
  end if;
  insert into auth.users(id) values('a7be0001-0000-4000-8000-000000000001'),('a7be0001-0000-4000-8000-000000000003');
  insert into auth.sessions(id,user_id) values('a7be0001-0000-4000-8000-000000000002','a7be0001-0000-4000-8000-000000000001'),('a7be0001-0000-4000-8000-000000000004','a7be0001-0000-4000-8000-000000000003');
  insert into verified_sessions(session_id,user_id) values('a7be0001-0000-4000-8000-000000000002','a7be0001-0000-4000-8000-000000000001'),('a7be0001-0000-4000-8000-000000000004','a7be0001-0000-4000-8000-000000000003');
  insert into profiles(id,role,display_name) values('a7be0001-0000-4000-8000-000000000001','instructor','M7 concurrency instructor'),
    ('a7be0001-0000-4000-8000-000000000003','student','M7 concurrency student');
  insert into classes(id,owner_id,course,section,school_year)
    values('a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 concurrency fixture','M7 concurrency','2026-2027');
  insert into class_members(class_id,student_id,status) values('a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000003','active');
  insert into quizzes(id,class_id,author_id,title,status,opens_at,closes_at) values('a7be0001-0000-4000-8000-000000000011','a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 race 1','draft',now()-interval '1 hour',now()+interval '1 day');
  insert into questions(quiz_id,type,prompt) values('a7be0001-0000-4000-8000-000000000011','essay','Original');
  insert into quizzes(id,class_id,author_id,title,status,opens_at,closes_at) values('a7be0001-0000-4000-8000-000000000012','a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 race 2','published',now()-interval '1 hour',now()+interval '1 day');
  insert into questions(quiz_id,type,prompt) values('a7be0001-0000-4000-8000-000000000012','essay','Original');
  insert into quizzes(id,class_id,author_id,title,status,opens_at,closes_at) values('a7be0001-0000-4000-8000-000000000013','a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 race 3','published',now()-interval '1 hour',now()+interval '1 day');
  insert into questions(quiz_id,type,prompt) values('a7be0001-0000-4000-8000-000000000013','essay','Original');
  insert into quizzes(id,class_id,author_id,title,status,opens_at,closes_at) values('a7be0001-0000-4000-8000-000000000014','a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 race 4','published',now()-interval '1 hour',now()+interval '1 day');
  insert into questions(quiz_id,type,prompt) values('a7be0001-0000-4000-8000-000000000014','essay','Original');
  insert into quizzes(id,class_id,author_id,title,status,opens_at,closes_at) values('a7be0001-0000-4000-8000-000000000015','a7be0001-0000-4000-8000-000000000005','a7be0001-0000-4000-8000-000000000001','M7 race 5','published',now()-interval '1 hour',now()+interval '1 day');
  insert into questions(quiz_id,type,prompt) values('a7be0001-0000-4000-8000-000000000015','essay','Original');
end $$;
commit;

-- 2. Concurrent publication. Run A in tab A, immediately run B in tab B while A sleeps.
-- A: BEGIN through COMMIT together.
begin;
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select (publish_quiz('a7be0001-0000-4000-8000-000000000011')).id;
select pg_sleep(15);
commit;
-- B: BEGIN through COMMIT together. Expected: waits, succeeds with the same quiz ID; one inbox row total
begin;
set local lock_timeout='30s';
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select (publish_quiz('a7be0001-0000-4000-8000-000000000011')).id;
commit;
-- After an expected B error, run ROLLBACK separately in tab B.

-- 3. Start wins against save. Run A in tab A, immediately run B in tab B while A sleeps.
-- A: BEGIN through COMMIT together.
begin;
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000003","session_id":"a7be0001-0000-4000-8000-000000000004","role":"authenticated"}',true);
set local role authenticated;
select (start_exam('a7be0001-0000-4000-8000-000000000012')).id;
select pg_sleep(15);
commit;
-- B: BEGIN through COMMIT together. Expected: waits then SQLSTATE 22023; no Late edit question
begin;
set local lock_timeout='30s';
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select save_question('a7be0001-0000-4000-8000-000000000012','{"type":"essay","prompt":"Late edit","points":1,"position":1}');
commit;
-- After an expected B error, run ROLLBACK separately in tab B.

-- 4. Save wins against start. Run A in tab A, immediately run B in tab B while A sleeps.
-- A: BEGIN through COMMIT together.
begin;
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select save_question('a7be0001-0000-4000-8000-000000000013','{"type":"essay","prompt":"Committed edit","points":1,"position":1}');
select pg_sleep(15);
commit;
-- B: BEGIN through COMMIT together. Expected: waits then returned questions include Original and Committed edit
begin;
set local lock_timeout='30s';
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000003","session_id":"a7be0001-0000-4000-8000-000000000004","role":"authenticated"}',true);
set local role authenticated;
select get_exam((start_exam('a7be0001-0000-4000-8000-000000000013')).id);
commit;
-- After an expected B error, run ROLLBACK separately in tab B.

-- 5. Deletion wins against start. Run A in tab A, immediately run B in tab B while A sleeps.
-- A: BEGIN through COMMIT together.
begin;
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
update quizzes set deleted_at=now() where id='a7be0001-0000-4000-8000-000000000014';
select pg_sleep(15);
commit;
-- B: BEGIN through COMMIT together. Expected: waits then Quiz not found; no attempt created
begin;
set local lock_timeout='30s';
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000003","session_id":"a7be0001-0000-4000-8000-000000000004","role":"authenticated"}',true);
set local role authenticated;
select start_exam('a7be0001-0000-4000-8000-000000000014');
commit;
-- After an expected B error, run ROLLBACK separately in tab B.

-- 6. Start wins against deletion. Run A in tab A, immediately run B in tab B while A sleeps.
-- A: BEGIN through COMMIT together.
begin;
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000003","session_id":"a7be0001-0000-4000-8000-000000000004","role":"authenticated"}',true);
set local role authenticated;
select (start_exam('a7be0001-0000-4000-8000-000000000015')).id;
select pg_sleep(15);
commit;
-- B: BEGIN through COMMIT together. Expected: waits then SQLSTATE 22023; quiz and attempt remain
begin;
set local lock_timeout='30s';
select set_config('request.jwt.claims','{"sub":"a7be0001-0000-4000-8000-000000000001","session_id":"a7be0001-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
update quizzes set deleted_at=now() where id='a7be0001-0000-4000-8000-000000000015';
commit;
-- After an expected B error, run ROLLBACK separately in tab B.

-- 7. INSPECT then CLEANUP: run inspection SELECTs as postgres after both tabs finish.
select id,status,locked_at,deleted_at from quizzes where class_id='a7be0001-0000-4000-8000-000000000005' order by id;
select count(*) as must_be_one from notifications where target_id='a7be0001-0000-4000-8000-000000000011' and recipient_id='a7be0001-0000-4000-8000-000000000003';
select count(*) as must_be_zero from questions where quiz_id='a7be0001-0000-4000-8000-000000000012' and prompt='Late edit';
select count(*) as must_be_zero from exam_sessions where quiz_id='a7be0001-0000-4000-8000-000000000014';
select count(*) as must_be_one from exam_sessions where quiz_id='a7be0001-0000-4000-8000-000000000015';
-- Cleanup selection: BEGIN..COMMIT only, as postgres. Never use these IDs for real data.
begin;
select set_config('request.jwt.claims','{}',true);
do $$
begin
 if not exists(select 1 from classes where id='a7be0001-0000-4000-8000-000000000005' and owner_id='a7be0001-0000-4000-8000-000000000001'
    and course='M7 concurrency fixture' and section='M7 concurrency') then
   raise exception 'Fixture provenance mismatch: stop and inspect; no cleanup performed';
 end if;
 delete from classes where id='a7be0001-0000-4000-8000-000000000005';
 delete from auth.users where id in ('a7be0001-0000-4000-8000-000000000001','a7be0001-0000-4000-8000-000000000003');
 delete from profiles where id in ('a7be0001-0000-4000-8000-000000000001','a7be0001-0000-4000-8000-000000000003');
end $$;
commit;
