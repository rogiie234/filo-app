-- DEV ONLY. Run the WHOLE file as postgres in the dev SQL Editor after all
-- project migrations. No real accounts, storage objects or credentials needed.
-- All fixtures and helpers roll back. FAIL rows are failures, not acceptance.
-- If execution aborts, issue ROLLBACK before retrying the whole file.
-- No sleeps: now() is transaction-stable; admin fixture timestamps model time.
-- This checks database behavior, not HTTP, upload bytes, concurrency or screens.
begin;
create temporary table grading_results (
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
  insert into grading_results(test,result,detail)
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
  insert into grading_results(test,result,detail) values(label,
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
declare c uuid:=gen_random_uuid(); other_c uuid:=gen_random_uuid();
 p uuid:=gen_random_uuid(); other_p uuid:=gen_random_uuid();
 s uuid:=gen_random_uuid(); peer uuid:=gen_random_uuid(); draft uuid:=gen_random_uuid(); foreign_s uuid:=gen_random_uuid(); unsaved uuid:=gen_random_uuid();
 u uuid; sid uuid; i integer;
begin
 for i in 1..5 loop
  u:=gen_random_uuid(); sid:=gen_random_uuid();
  perform set_config('submission_test.u'||i,u::text,true);
  perform set_config('submission_test.s'||i,sid::text,true);
  insert into auth.users(id) values(u);
  insert into auth.sessions(id,user_id) values(sid,u);
  insert into profiles(id,role,display_name) values(u,case when i in (1,4) then 'instructor'::user_role else 'student'::user_role end,'Grade fixture '||i);
  insert into verified_sessions(session_id,user_id) values(sid,u);
 end loop;
 insert into classes(id,owner_id,course,section,school_year) values
 (c,current_setting('submission_test.u1')::uuid,'Grade fixture','QA','2026'),
 (other_c,current_setting('submission_test.u4')::uuid,'Foreign fixture','QA','2026');
 for i in 2..5 loop
  if i<>4 then insert into class_members(class_id,student_id,status) values(c,current_setting('submission_test.u'||i)::uuid,'active'); end if;
 end loop;
 insert into posts(id,class_id,author_id,kind,title,points,due_at) values
 (p,c,current_setting('submission_test.u1')::uuid,'assignment','Grade fixture',100,now()-interval '1 day'),
 (other_p,other_c,current_setting('submission_test.u4')::uuid,'assignment','Foreign fixture',100,now()-interval '1 day');
 insert into submissions(id,post_id,student_id,status,submitted_at) values
 (s,p,current_setting('submission_test.u2')::uuid,'turned_in',now()),
 (peer,p,current_setting('submission_test.u3')::uuid,'turned_in',now()),
 (draft,p,current_setting('submission_test.u5')::uuid,'draft',null),
 (foreign_s,other_p,current_setting('submission_test.u2')::uuid,'turned_in',now());
 perform pg_temp.submission_actor(1);
 perform pg_temp.submission_sql(format('select save_grade(%L,80)',s),'00000','valid score');
 perform pg_temp.submission_sql(format('select save_grade(%L,-1)',s),'P0001','negative refused');
 perform pg_temp.submission_sql(format('select save_grade(%L,101)',s),'P0001','above points refused');
 perform pg_temp.submission_sql(format('select save_grade(%L,null)',s),'P0001','null refused');
 perform pg_temp.submission_sql(format('select save_grade(%L,0)',draft),'P0001','draft refused');
 perform pg_temp.submission_sql(format('select save_grade(%L,81)',s),'00000','save again');
 perform pg_temp.check_submission(format('select count(*)=1 and min(score)=81 from submission_grades where submission_id=%L',s),'same grade updated');
 perform pg_temp.submission_actor(2);
 perform pg_temp.submission_sql(format('select save_grade(%L,1)',s),'P0001','student save refused');
 perform pg_temp.check_submission(format('select count(*)=0 from submission_grades where submission_id=%L',s),'checklist 3 hidden before return');
 perform pg_temp.submission_sql(format('insert into submission_grades(submission_id,score) values(%L,1)',peer),'42501','direct grade insert refused');
 perform pg_temp.submission_sql(format('update submission_grades set score=1 where submission_id=%L',s),'42501','direct grade update refused');
 perform pg_temp.submission_actor(4);
 perform pg_temp.submission_sql(format('select save_grade(%L,1)',s),'P0001','checklist 4 foreign instructor save refused');
 perform pg_temp.check_submission(format('select count(*)=0 from submission_grades where submission_id=%L',s),'foreign instructor cannot read grade');
 perform pg_temp.submission_sql(format('select save_grade(%L,70)',foreign_s),'00000','foreign owner fixture save');
 perform pg_temp.submission_actor(1);
 perform pg_temp.check_submission(format('select count(*)=2 from submissions where post_id=%L',p),'instructor sees turned-in only');
 perform pg_temp.check_submission(format('select return_grades(array[%L,%L,%L,%L]::uuid[])=1',s,peer,draft,foreign_s),'return only owned saved eligible grades');
 perform pg_temp.check_submission(format('select return_grades(array[%L,%L]::uuid[])=0',s,foreign_s),'repeat and foreign ids ignored');
 perform pg_temp.submission_actor(2);
 perform pg_temp.check_submission(format('select score=81 and returned_at is not null from submission_grades where submission_id=%L',s),'visible after return');
 perform pg_temp.check_submission(format('select count(*)=1 from notifications where type=''grade_returned'' and target_id=%L',p),'one inbox row');
 perform pg_temp.submission_actor(1);
 perform pg_temp.submission_sql(format('select save_grade(%L,90)',s),'00000','edit returned score');
 perform pg_temp.submission_sql(format('select save_grade(%L,60)',peer),'00000','save peer');
 perform pg_temp.check_submission(format('select return_all_graded(%L)=1',p),'bulk returns saved unreturned only');
 perform pg_temp.check_submission(format('select return_all_graded(%L)=0',p),'bulk retry returns zero');
 perform pg_temp.check_submission(format('select return_all_graded(%L)=0',other_p),'foreign assignment ignored');
 perform pg_temp.submission_actor(2);
 perform pg_temp.check_submission(format('select score=90 from submission_grades where submission_id=%L',s),'changed score immediately visible');
 perform pg_temp.check_submission(format('select count(*)=1 from notifications where type=''grade_returned'' and target_id=%L',p),'edit sends no duplicate');
 perform pg_temp.check_submission(format('select count(*)=0 from submission_grades where submission_id=%L',peer),'checklist 1 peer returned grade hidden');
 perform pg_temp.submission_actor(3);
 perform pg_temp.check_submission(format('select count(*)=1 from notifications where type=''grade_returned'' and target_id=%L',p),'peer receives one inbox row');
 -- Model unsubmit after Save: draft grade must not leak through Return.
 update submissions set status='draft',submitted_at=null where id=peer;
 update submission_grades set returned_at=null where submission_id=peer;
 perform pg_temp.submission_actor(1);
 perform pg_temp.check_submission(format('select return_all_graded(%L)=0',p),'saved grade on reverted draft excluded');
 perform pg_temp.submission_actor(3);
 perform pg_temp.check_submission(format('select count(*)=0 from submission_grades where submission_id=%L',peer),'reverted draft grade remains hidden');

 -- Approved missing-work contract: owner, callers, membership, deadlines and locks.
 perform pg_temp.submission_actor(1);
 insert into submission_items(submission_id,kind,text_content) values(draft,'text','Private unfinished draft');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,0)',p,current_setting('submission_test.u5')),'00000','owner scores missing draft zero');
 perform pg_temp.check_submission(format('select status=''turned_in'' and submitted_at is null and unsubmit_until is null from submissions where id=%L',draft),'instructor-scored lifecycle');
 perform pg_temp.check_submission(format('select count(*)=0 from submission_items where submission_id=%L',draft),'instructor-scored row has no items');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,0)',p,current_setting('submission_test.u2')),'P0001','already turned-in refused');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,0)',p,gen_random_uuid()),'P0001','nonmember refused');
 perform pg_temp.submission_actor(4);
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,0)',p,current_setting('submission_test.u3')),'P0001','foreign instructor missing score refused');
 perform pg_temp.submission_actor(3);
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,0)',p,current_setting('submission_test.u3')),'P0001','student missing score refused');
 perform pg_temp.submission_actor(5);
 perform pg_temp.check_submission(format('select count(*)=0 from submission_grades where submission_id=%L',draft),'missing score hidden before Return');
 perform pg_temp.submission_sql(format('insert into submission_items(submission_id,kind,text_content) values(%L,''text'',''late answer'')',draft),'P0001','missing row item insert refused');
 perform pg_temp.submission_sql(format('select turn_in(%L)',draft),'P0001','missing row turn-in refused');
 perform pg_temp.submission_sql(format('select unsubmit(%L)',draft),'P0001','missing row unsubmit refused');
 perform pg_temp.submission_actor(1);
 perform pg_temp.check_submission(format('select return_all_graded(%L)=1',p),'missing work returned and counted');
 perform pg_temp.submission_actor(5);
 perform pg_temp.check_submission(format('select score=0 and returned_at is not null from submission_grades where submission_id=%L',draft),'student sees returned missing zero');
 perform pg_temp.submission_actor(1);
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,-1)',p,current_setting('submission_test.u3')),'P0001','missing negative refused');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,101)',p,current_setting('submission_test.u3')),'P0001','missing over max refused');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,null)',p,current_setting('submission_test.u3')),'P0001','missing null refused');
 update posts set due_at=now()+interval '1 day' where id=p;
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,5)',p,current_setting('submission_test.u3')),'P0001','not past due refused');
 update posts set due_at=now()-interval '1 day' where id=p;
 update class_members set status='left' where class_id=c and student_id=current_setting('submission_test.u3')::uuid;
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,5)',p,current_setting('submission_test.u3')),'00000','former member partial score');
 insert into posts(id,class_id,author_id,kind,title,points,due_at)
 values(unsaved,c,current_setting('submission_test.u1')::uuid,'assignment','No draft fixture',100,now()-interval '1 day');
 perform pg_temp.submission_sql(format('select grade_missing(%L,%L,25)',unsaved,current_setting('submission_test.u2')),'00000','missing without draft creates row');
 perform pg_temp.check_submission(format('select count(*)=1 from submissions s join submission_grades g on g.submission_id=s.id where s.post_id=%L and s.status=''turned_in'' and s.submitted_at is null and g.score=25',unsaved),'created missing row graded');
end $$;
select * from grading_results order by step;
select count(*) filter(where result='PASS') as passed,count(*) filter(where result='FAIL') as failed,
 coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]'::jsonb) as failures from grading_results;
rollback;
