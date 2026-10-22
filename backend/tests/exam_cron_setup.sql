-- M8-BE-02 unattended proof, SETUP. DEV fiobwfzmqcffbpixzvbq only, postgres.
-- This COMMITTED fixture is intentionally visible to cron. Do not call app/RPCs
-- for these users. After setup close the app; inspect after at least 2 minutes.
begin;
set local search_path=public;
select set_config('request.jwt.claims','{}',true);
do $$
declare job_count integer; owner_id uuid:='8b020000-0000-4000-8000-000000000001';
  student_id uuid:='8b020000-0000-4000-8000-000000000002';
  class_id uuid:='8b020000-0000-4000-8000-000000000003';
  quiz_id uuid:='8b020000-0000-4000-8000-000000000004';
  question_id uuid:='8b020000-0000-4000-8000-000000000005';
  attempt_id uuid:='8b020000-0000-4000-8000-000000000006';
begin
  if not exists(select 1 from pg_extension where extname='pg_cron') then
    raise exception 'pg_cron is unavailable: do not claim unattended acceptance; use the documented fallback checks';
  end if;
  select count(*) into job_count from cron.job where jobname='filo-finalize-exams'
    and database=current_database() and active and schedule='* * * * *'
    and btrim(command,' ;')='select public.finalize_expired_sessions()';
  if job_count<>1 then raise exception 'Expected one active one-minute exam job; inspect before setup'; end if;
  if exists(select 1 from auth.users where id in (owner_id,student_id))
    or exists(select 1 from classes where id=class_id)
    or exists(select 1 from quizzes where id=quiz_id)
    or exists(select 1 from questions where id=question_id)
    or exists(select 1 from exam_sessions where id=attempt_id) then
    raise exception 'Reserved proof IDs already exist. Inspect and clean the previous proof, never overwrite it';
  end if;
  insert into auth.users(id) values(owner_id),(student_id);
  insert into profiles(id,role,display_name) values
    (owner_id,'instructor','M8-BE-02 CRON PROOF ONLY'),(student_id,'student','M8-BE-02 CRON PROOF ONLY');
  insert into classes(id,owner_id,course,section,school_year)
    values(class_id,owner_id,'M8-BE-02 CRON PROOF ONLY','M8B-CRON','2026-2027');
  insert into class_members(class_id,student_id,status) values(class_id,student_id,'active');
  insert into quizzes(id,class_id,author_id,title,opens_at,closes_at)
    values(quiz_id,class_id,owner_id,'M8-BE-02 CRON PROOF ONLY',now()-interval '1 minute',now()+interval '1 hour');
  insert into questions(id,quiz_id,position,type,prompt,points)
    values(question_id,quiz_id,1,'identification','Cron proof: Green Leaf',7);
  insert into answer_keys(question_id,accepted_answers) values(question_id,array['Green Leaf']);
  update quizzes set status='published',published_at=now(),locked_at=now() where id=quiz_id;
  insert into exam_sessions(id,quiz_id,student_id,deadline_at,question_order)
    values(attempt_id,quiz_id,student_id,now()+interval '30 seconds',array[question_id]);
  insert into exam_answers(session_id,question_id,text_answer)
    values(attempt_id,question_id,E' \tGrEeN   LEAF\n ');
end $$;
select id as proof_session, status, started_at, deadline_at,
  deadline_at+interval '15 seconds' as eligible_after,
  deadline_at+interval '2 minutes' as inspect_after
from public.exam_sessions where id='8b020000-0000-4000-8000-000000000006';
commit;
