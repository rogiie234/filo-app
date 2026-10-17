-- DEV ONLY. Run the WHOLE file as postgres in the dev SQL Editor after all
-- project migrations. No real accounts, storage objects or credentials needed.
-- All fixtures and helpers roll back. FAIL rows are failures, not acceptance.
-- If execution aborts, issue ROLLBACK before retrying the whole file.
-- No sleeps: now() is transaction-stable; admin fixture timestamps model time.
-- This checks database behavior, not HTTP, upload bytes, concurrency or screens.
begin;
create temporary table submission_results (
  step integer generated always as identity, test text, result text, detail text
) on commit drop;
create function pg_temp.check_submission(q text, label text) returns void
language plpgsql as $$
declare ok boolean; detail text;
begin
  begin
    set local role authenticated;
    execute q into ok;
    reset role;
  exception when others then
    get stacked diagnostics detail = message_text;
    reset role;
  end;
  insert into submission_results(test,result,detail)
    values(label,case when ok is true then 'PASS' else 'FAIL' end,detail);
end $$;
create function pg_temp.submission_sql(q text, expected text, label text,
  expected_message text default null) returns void language plpgsql as $$
declare code text := '00000'; detail text;
begin
  begin
    set local role authenticated;
    execute q;
    reset role;
  exception when others then
    get stacked diagnostics code = returned_sqlstate, detail = message_text;
    reset role;
  end;
  insert into submission_results(test,result,detail) values(label,
    case when code=expected and (expected_message is null or detail=expected_message)
      then 'PASS' else 'FAIL' end,code||coalesce(': '||detail,''));
end $$;
create function pg_temp.submission_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',current_setting('submission_test.u'||i),
    'session_id',current_setting('submission_test.s'||i),'role','authenticated')::text,true);
end $$;
do $$
declare c uuid := gen_random_uuid(); p uuid := gen_random_uuid();
  u uuid; session_id uuid; s uuid; peer uuid; item uuid; q uuid := gen_random_uuid();
  exam uuid := gen_random_uuid(); i integer; k text; ins text;
begin
  for i in 1..4 loop
    u:=gen_random_uuid(); session_id:=gen_random_uuid();
    perform set_config('submission_test.u'||i,u::text,true);
    perform set_config('submission_test.s'||i,session_id::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(session_id,u);
    insert into public.profiles(id,role,display_name) values(u,
      case when i in (1,4) then 'instructor'::public.user_role else 'student'::public.user_role end,
      'Submission fixture '||i);
    insert into public.verified_sessions(session_id,user_id) values(session_id,u);
  end loop;
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,current_setting('submission_test.u1')::uuid,'Submission fixture','QA','2026-2027');
  for i in 2..3 loop
    insert into public.class_members(class_id,student_id,status)
      values(c,current_setting('submission_test.u'||i)::uuid,'active');
  end loop;
  insert into public.posts(id,class_id,author_id,kind,title,points,due_at,allow_files,max_files,accept_late)
    values(p,c,current_setting('submission_test.u1')::uuid,'assignment','Submission fixture',100,
      now()+interval '1 day',true,5,true);
  perform pg_temp.submission_actor(2);
  perform pg_temp.submission_sql(format('select public.start_submission(%L)',p),'00000','start creates draft');
  select id into strict s from public.submissions where post_id=p and student_id=current_setting('submission_test.u2')::uuid;
  perform pg_temp.check_submission(format('select status=''draft'' and student_id=auth.uid() from public.submissions where id=%L',s),'new draft belongs to caller');
  perform pg_temp.check_submission(format('select (public.start_submission(%L)).id=%L::uuid',p,s),'start returns same draft on retry');
  perform pg_temp.submission_sql(format('select public.turn_in(%L)',s),'P0001','empty turn-in refused','Add at least one item before turning in');
  -- Another student has no draft yet: exercise refusal without the resume path.
  perform pg_temp.submission_actor(3);
  update public.classes set archived_at=now() where id=c;
  perform pg_temp.submission_sql(format('select public.start_submission(%L)',p),'P0001','archived start refused','This class is archived');
  update public.classes set archived_at=null where id=c;
  update public.posts set due_at=now()-interval '1 minute',accept_late=false where id=p;
  perform pg_temp.submission_sql(format('select public.start_submission(%L)',p),'P0001','closed late start refused','Submissions are closed for this assignment');
  update public.posts set due_at=now()+interval '1 day',accept_late=true where id=p;
  perform pg_temp.submission_sql(format('select public.start_submission(%L)',p),'00000','second student creates own draft');
  select id into strict peer from public.submissions where post_id=p and student_id=current_setting('submission_test.u3')::uuid;
  perform pg_temp.submission_actor(2);
  foreach k in array array['file','link','text'] loop
    ins:=format('insert into public.submission_items(submission_id,kind,%I) values(%L,%L,%L)',
      case k when 'file' then 'storage_path' when 'link' then 'url' else 'text_content' end,
      s,k,case k when 'file' then c||'/'||s||'/fixture.pdf' when 'link' then 'https://example.com' else 'Fixture answer' end);
    for i in 1..(case when k='text' then 1 else 5 end) loop
      perform pg_temp.submission_sql(ins,'00000',k||' allowed slot '||i);
    end loop;
    perform pg_temp.submission_sql(ins,'P0001',k||' extra slot refused',
      case k when 'file' then 'File limit reached' when 'link' then 'Link limit reached' else 'Only one text entry is allowed' end);
  end loop;
  -- Free one file slot first, so allow_files is independently exercised.
  select id into item from public.submission_items where submission_id=s and kind='file' limit 1;
  perform pg_temp.submission_sql(format('update public.submission_items set deleted_at=now() where id=%L',item),'00000','draft item soft delete');
  update public.posts set allow_files=false where id=p;
  perform pg_temp.submission_sql(format('insert into public.submission_items(submission_id,kind,storage_path) values(%L,''file'',''fixture.pdf'')',s),'P0001','uploads off refuses file','File uploads are turned off for this assignment');
  update public.posts set allow_files=true where id=p;
  perform pg_temp.check_submission(format('select count(*)=1 from public.submissions where post_id=%L',p),'student sees only own draft');
  perform pg_temp.check_submission(format('select count(*)=11 from public.submission_items where submission_id=%L',s),'student sees own items including tombstone');
  perform pg_temp.submission_actor(3);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submissions where id=%L',s),'checklist 1: peer draft hidden');
  perform pg_temp.check_submission(format('select count(*)=0 from public.submission_items where submission_id=%L',s),'peer draft items hidden');
  perform pg_temp.submission_actor(1);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submissions where post_id=%L',p),'instructor sees no drafts');
  perform pg_temp.check_submission(format('select count(*)=0 from public.submission_items where submission_id in (%L,%L)',s,peer),'instructor sees no draft items');
  perform pg_temp.submission_actor(2);
  perform pg_temp.submission_sql(format('select public.turn_in(%L,''Private note'')',s),'00000','turn in before deadline');
  perform pg_temp.check_submission(format('select status=''turned_in'' and not is_late and submitted_at=now() and unsubmit_until=now()+interval ''10 minutes'' and private_comment=''Private note'' from public.submissions where id=%L',s),'on-time fields and ten-minute window');
  foreach k in array array['file','link','text'] loop
    perform pg_temp.submission_sql(format('insert into public.submission_items(submission_id,kind,%I) values(%L,%L,%L)',case k when 'file' then 'storage_path' when 'link' then 'url' else 'text_content' end,s,k,'fixture'),'P0001','checklist 6: turned-in '||k||' insert refused','This submission is locked');
  end loop;
  perform pg_temp.check_submission(format('with changed as (update public.submission_items set deleted_at=now() where submission_id=%L returning id) select count(*)=0 from changed',s),'turned-in item updates refused');
  perform pg_temp.submission_actor(1);
  perform pg_temp.check_submission(format('select count(*)=1 from public.submissions where post_id=%L',p),'instructor sees turned-in only, other draft hidden');
  perform pg_temp.check_submission(format('select count(*)=11 from public.submission_items where submission_id=%L',s),'instructor sees turned-in items');
  perform pg_temp.submission_actor(4);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submissions where post_id=%L',p),'unrelated instructor sees no work');
  perform pg_temp.submission_actor(3);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submissions where id=%L',s),'peer turned-in submission hidden');
  perform pg_temp.check_submission(format('select count(*)=0 from public.submission_items where submission_id=%L',s),'peer turned-in items hidden');
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'P0001','peer cannot unsubmit','Submission not found');
  -- Grade insertion and timestamp changes below are deliberate postgres fixtures.
  insert into public.submission_grades(submission_id,score,graded_at,graded_by)
    values(s,85,now(),current_setting('submission_test.u1')::uuid);
  perform pg_temp.submission_actor(2);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submission_grades where submission_id=%L',s),'checklist 3: unreturned grade hidden');
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'00000','within window unsubmit allowed with unreturned grade');
  perform pg_temp.check_submission(format('select status=''draft'' and submitted_at is null and not is_late and unsubmit_until is null from public.submissions where id=%L',s),'unsubmit resets lifecycle fields');
  perform pg_temp.submission_sql(format('select public.turn_in(%L)',s),'00000','turn-in retry after unsubmit');
  update public.submission_grades set returned_at=now() where submission_id=s;
  perform pg_temp.check_submission(format('select score=85 and returned_at is not null from public.submission_grades where submission_id=%L',s),'returned grade visible to owner');
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'P0001','returned grade blocks unsubmit','A grade was already returned');
  perform pg_temp.submission_actor(3);
  perform pg_temp.check_submission(format('select count(*)=0 from public.submission_grades where submission_id=%L',s),'checklist 1: peer returned grade hidden');
  perform pg_temp.submission_actor(2);
  update public.submission_grades set returned_at=null where submission_id=s;
  update public.submissions set unsubmit_until=now()-interval '1 second' where id=s;
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'P0001','expired window refuses unsubmit','The unsubmit window has passed');
  -- Restore draft as admin, then turn in near the deadline through the real RPC.
  update public.submissions set status='draft',submitted_at=null,unsubmit_until=null where id=s;
  update public.posts set due_at=now()+interval '2 minutes' where id=p;
  perform pg_temp.submission_sql(format('select public.turn_in(%L)',s),'00000','near-deadline turn-in');
  perform pg_temp.check_submission(format('select not is_late and unsubmit_until=now()+interval ''2 minutes'' from public.submissions where id=%L',s),'window capped at deadline');
  update public.posts set due_at=now()-interval '1 second' where id=p;
  update public.submissions set unsubmit_until=now()-interval '1 second' where id=s;
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'P0001','past deadline unsubmit refused','The unsubmit window has passed');
  update public.submissions set status='draft',submitted_at=null,unsubmit_until=null where id=s;
  update public.posts set accept_late=false where id=p;
  perform pg_temp.submission_sql(format('select public.turn_in(%L)',s),'P0001','late turn-in refused when closed','Submissions are closed for this assignment');
  update public.posts set accept_late=true where id=p;
  perform pg_temp.submission_sql(format('select public.turn_in(%L)',s),'00000','late turn-in allowed');
  -- SQL contract represents no late window as unsubmit_until=submitted_at.
  perform pg_temp.check_submission(format('select is_late and status=''turned_in'' and submitted_at=now() and unsubmit_until=submitted_at from public.submissions where id=%L',s),'late fields have zero-length window');
  -- Deliberately immediate: detects the now() > (rather than >=) boundary bug.
  perform pg_temp.submission_sql(format('select public.unsubmit(%L)',s),'P0001','late work cannot unsubmit even in same transaction','The unsubmit window has passed');
  -- Full checklist 1 also includes peer exam-session isolation.
  insert into public.quizzes(id,class_id,author_id,title) values(q,c,current_setting('submission_test.u1')::uuid,'Exam visibility fixture');
  insert into public.exam_sessions(id,quiz_id,student_id,deadline_at,status,auto_score,grading_complete)
    values(exam,q,current_setting('submission_test.u2')::uuid,now()+interval '1 hour','submitted',7,true);
  perform pg_temp.submission_actor(3);
  perform pg_temp.check_submission(format('select count(*)=0 from public.exam_sessions where id=%L',exam),'checklist 1: peer exam session hidden');
  perform pg_temp.submission_actor(2);
  perform pg_temp.submission_sql(format('select public.get_result(%L)',exam),'P0001','checklist 3: unreleased exam result refused','Results are not available yet');
  update public.quizzes set results_released_at=now() where id=q;
  perform pg_temp.submission_sql(format('select public.get_result(%L)',exam),'00000','released exam result accessible control');
end $$;
-- SQL Editor shows the last SELECT: include failures in the summary below.
select * from submission_results order by step;
select count(*) filter (where result='PASS') as passed,
       count(*) filter (where result='FAIL') as failed,
       case when bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
       coalesce(jsonb_agg(jsonb_build_object('step',step,'test',test,'detail',detail) order by step)
         filter (where result='FAIL'),'[]'::jsonb) as failures
from submission_results;
rollback;
