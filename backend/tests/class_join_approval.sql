-- Run the WHOLE file in DEV SQL Editor as postgres; never in production.
-- Requires migrations through 20261016110000_fix_class_result_alias.sql.
-- No credentials or real accounts required. All database fixtures roll back.
-- Fail-fast: any exception means FAIL, even if earlier rows say PASS.
begin;
create temporary table join_results (step integer generated always as identity, test text, result text) on commit drop;
create function pg_temp.check_join(ok boolean, label text) returns void
language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  insert into join_results(test, result) values(label, 'PASS');
end $$;
create function pg_temp.join_actor(i integer) returns void
language plpgsql as $$ begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', current_setting('join_test.user' || i),
    'session_id', current_setting('join_test.session' || i),
    'role', 'authenticated')::text, true);
end $$;
-- This helper runs only after RESET ROLE: inspect complete persisted effects.
create function pg_temp.join_snapshot(expected_status text, requests integer,
  approvals integer, declines integer, removals integer) returns void
language plpgsql as $$
declare c uuid := current_setting('join_test.class')::uuid;
        u uuid := current_setting('join_test.user2')::uuid;
        owner_id uuid := current_setting('join_test.user1')::uuid;
begin
  perform pg_temp.check_join((select count(*) from public.class_members
    where class_id=c and student_id=u)=case when expected_status is null then 0 else 1 end,
    'one retained membership row (or none before join)');
  if expected_status is not null then
    perform pg_temp.check_join((select status::text from public.class_members
      where class_id=c and student_id=u)=expected_status, 'membership ' || expected_status);
  end if;
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c)=
    requests+approvals+declines+removals, 'exact total notifications; no unexpected recipient/type');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and recipient_id=owner_id and type='join_request' and target_type='class_members'
    and target_id=c and title='New join request' and body='Join fixture 2 wants to join QA')=requests,
    'instructor join_request rows and payload');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and recipient_id=u and type='join_approved' and target_type='class' and target_id=c
    and title='Request approved' and body='You''ve been approved to join QA')=approvals,
    'student approval rows and payload');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and recipient_id=u and type='join_declined' and target_type='class' and target_id=c
    and title='Request declined' and body='Your request to join QA was declined')=declines,
    'student decline rows and payload');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and recipient_id=u and type='removed_from_class' and target_type='class' and target_id=c
    and title='Removed from class' and body='You were removed from QA')=removals,
    'student removal rows and payload');
end $$;
do $$
declare u uuid; sid uuid; c uuid := gen_random_uuid(); i integer;
  member_id uuid; code text; result text; n integer;
begin
  perform set_config('join_test.class', c::text, true);
  for i in 1..3 loop
    u := gen_random_uuid(); sid := gen_random_uuid();
    perform set_config('join_test.user'||i, u::text, true);
    perform set_config('join_test.session'||i, sid::text, true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(sid,u);
    insert into public.profiles(id,role,display_name) values(u,
      case when i=1 then 'instructor'::public.user_role else 'student'::public.user_role end,
      'Join fixture '||i);
    insert into public.verified_sessions(session_id,user_id) values(sid,u);
  end loop;
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,current_setting('join_test.user1')::uuid,'Join SQL fixture','QA','2026-2027')
    returning join_code into code;
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join('!invalid-'||c::text)::text;
  reset role;
  perform pg_temp.check_join(result='not_found','01 wrong code');
  perform pg_temp.join_snapshot(null,0,0,0,0);
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='requested','02 valid join');
  perform pg_temp.join_snapshot('pending',1,0,0,0);
  select id into member_id from public.class_members where class_id=c and student_id=current_setting('join_test.user2')::uuid;
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='already_pending','03 join twice');
  perform pg_temp.join_snapshot('pending',1,0,0,0);
  perform pg_temp.join_actor(1);
  set local role authenticated;
  perform public.decide_join(member_id,true);
  reset role;
  perform pg_temp.join_snapshot('active',1,1,0,0);
  perform pg_temp.check_join((select decided_by=current_setting('join_test.user1')::uuid and decided_at is not null from public.class_members where id=member_id),'04 approve metadata');
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='already_member','05 join as member');
  perform pg_temp.join_snapshot('active',1,1,0,0);
  perform pg_temp.join_actor(1);
  set local role authenticated;
  perform public.remove_member(c,current_setting('join_test.user2')::uuid);
  reset role;
  perform pg_temp.join_snapshot('removed',1,1,0,1);
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='requested','06 removed student rejoins pending');
  perform pg_temp.join_snapshot('pending',2,1,0,1);
  perform pg_temp.join_actor(1);
  set local role authenticated;
  perform public.decide_join(member_id,false);
  reset role;
  perform pg_temp.join_snapshot('declined',2,1,1,1);
  perform pg_temp.join_actor(2);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='requested','07 declined student asks again');
  perform pg_temp.join_snapshot('pending',3,1,1,1);
  perform pg_temp.check_join((select id=member_id and decided_at is null and decided_by is null and left_at is null from public.class_members where class_id=c and student_id=current_setting('join_test.user2')::uuid),'rejoin retains ID and clears decision/leave metadata');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  perform public.archive_class(c);
  reset role;
  perform pg_temp.join_actor(3);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='archived','08 join archived class');
  perform pg_temp.join_snapshot('pending',3,1,1,1);
  perform pg_temp.check_join(not exists(select 1 from public.class_members where class_id=c and student_id=current_setting('join_test.user3')::uuid),'archived join creates no membership');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  perform public.restore_class(c);
  reset role;
  perform pg_temp.join_actor(3);
  set local role authenticated;
  result := public.request_join(code)::text;
  reset role;
  perform pg_temp.check_join(result='requested','second pending student for bulk approval');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  n := public.approve_all_pending(c);
  reset role;
  perform pg_temp.check_join(n=2,'09 approve all returns two');
  perform pg_temp.check_join((select count(*) from public.class_members where class_id=c)=2
    and (select count(*) from public.class_members where class_id=c and status='active'
      and decided_by=current_setting('join_test.user1')::uuid and decided_at is not null)=2,
    'approve all activates exactly both pending students');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c)=9,
    'bulk exact notification total');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and recipient_id=current_setting('join_test.user1')::uuid and type='join_request'
    and target_type='class_members' and target_id=c)=4,'bulk preserves four owner request rows');
  perform pg_temp.check_join((select count(*) from public.notifications where class_id=c
    and type='join_approved' and target_type='class' and target_id=c
    and title='Request approved' and body='You''ve been approved to join QA'
    and recipient_id=current_setting('join_test.user2')::uuid)=2
    and (select count(*) from public.notifications where class_id=c
    and type='join_approved' and target_type='class' and target_id=c
    and title='Request approved' and body='You''ve been approved to join QA'
    and recipient_id=current_setting('join_test.user3')::uuid)=1,
    'bulk delivers one approval per pending student');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  n := public.approve_all_pending(c);
  reset role;
  perform pg_temp.check_join(n=0 and (select count(*) from public.notifications where class_id=c)=9,'empty approve all returns zero and sends no duplicates');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c;
  reset role;
  perform pg_temp.check_join(n=4,'actor 1 inbox RLS expected count');
  perform pg_temp.join_actor(1);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c and recipient_id<>auth.uid();
  reset role;
  perform pg_temp.check_join(n=0,'actor 1 cannot read other inboxes');
  perform pg_temp.join_actor(2);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c;
  reset role;
  perform pg_temp.check_join(n=4,'actor 2 inbox RLS expected count');
  perform pg_temp.join_actor(2);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c and recipient_id<>auth.uid();
  reset role;
  perform pg_temp.check_join(n=0,'actor 2 cannot read other inboxes');
  perform pg_temp.join_actor(3);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c;
  reset role;
  perform pg_temp.check_join(n=1,'actor 3 inbox RLS expected count');
  perform pg_temp.join_actor(3);
  set local role authenticated;
  select count(*) into n from public.notifications where class_id=c and recipient_id<>auth.uid();
  reset role;
  perform pg_temp.check_join(n=0,'actor 3 cannot read other inboxes');
end $$;

-- Fail early if the target database still has the pre-lifecycle RPC definition.
select pg_temp.check_join(
  to_regprocedure('public.guard_class_content_write()') is not null
  and position('class_is_open' in pg_get_functiondef('public.get_exam(uuid)'::regprocedure)) > 0,
  'lifecycle migration present: write guard and archived get_exam check');

-- Lifecycle/security extension. All helpers are invoker functions: never bypass RLS.
create function pg_temp.lifecycle_sql(sql_text text, label text, expected_state text default null)
returns void language plpgsql as $$
declare failed boolean := false; state text; detail text;
begin
  set local role authenticated;
  begin
    execute sql_text;
  exception when others then
    get stacked diagnostics state = returned_sqlstate, detail = message_text;
    failed := true;
  end;
  reset role;
  if expected_state is null and failed then
    raise exception 'FAIL: % [%] %', label, state, detail;
  end if;
  if expected_state is not null and (not failed or state is distinct from expected_state) then
    raise exception 'FAIL: %; expected SQLSTATE %, got %: %',
      label, expected_state, coalesce(state, 'SUCCESS'), coalesce(detail, 'call completed without error');
  end if;
  perform pg_temp.check_join(true, label);
end $$;
create function pg_temp.lifecycle_count(query_text text, expected bigint, label text)
returns void language plpgsql as $$
declare n bigint;
begin
  set local role authenticated;
  execute query_text into n;
  reset role;
  perform pg_temp.check_join(n=expected,label);
end $$;
create function pg_temp.lifecycle_visibility(expected integer, label text)
returns void language plpgsql as $$
declare c uuid := current_setting('join_test.class')::uuid; t text;
begin
  perform pg_temp.lifecycle_count(format('select count(*) from storage.objects where bucket_id=''materials'' and name like %L',c::text||'/%'),case when expected=0 then 0 else 1 end,label||': material storage metadata');
  perform pg_temp.lifecycle_count(format('select count(*) from storage.objects where bucket_id=''submissions'' and name like %L',c::text||'/%'),expected,label||': submission storage metadata');
  foreach t in array array['classes','posts','post_attachments','submissions','submission_items','submission_grades','quizzes'] loop
    perform pg_temp.lifecycle_count(case t
      when 'classes' then format('select count(*) from public.classes where id=%L',c)
      when 'posts' then format('select count(*) from public.posts where class_id=%L',c)
      when 'quizzes' then format('select count(*) from public.quizzes where class_id=%L',c)
      when 'post_attachments' then format('select count(*) from public.post_attachments where post_id=%L',current_setting('life.post'))
      when 'submissions' then format('select count(*) from public.submissions where post_id=%L',current_setting('life.post'))
      when 'submission_items' then format('select count(*) from public.submission_items where submission_id in (%L,%L)',current_setting('life.sub2'),current_setting('life.sub3'))
      else format('select count(*) from public.submission_grades where submission_id in (%L,%L)',current_setting('life.sub2'),current_setting('life.sub3')) end,
      case when expected=0 then 0 when t in ('submissions','submission_items','submission_grades') and expected=2 then 2 else 1 end,
      label||': '||t);
  end loop;
end $$;
do $$
declare c uuid := current_setting('join_test.class')::uuid;
  owner_id uuid := current_setting('join_test.user1')::uuid;
  u uuid; sid uuid; post_id uuid := gen_random_uuid(); q uuid := gen_random_uuid();
  sub_id uuid; exam_id uuid; c2 uuid := gen_random_uuid(); i integer; code text; mid uuid;
  command text; bad text;
begin
  -- A second instructor owns a separate class. Student 2 belongs only to class 1.
  u := gen_random_uuid(); sid := gen_random_uuid();
  perform set_config('join_test.user4',u::text,true);
  perform set_config('join_test.session4',sid::text,true);
  insert into auth.users(id) values(u);
  insert into auth.sessions(id,user_id) values(sid,u);
  insert into public.profiles(id,role,display_name) values(u,'instructor','Lifecycle other owner');
  insert into public.verified_sessions(session_id,user_id) values(sid,u);
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c2,u,'Other owner fixture','OTHER','2026-2027');
  perform set_config('life.post',post_id::text,true);
  perform set_config('life.quiz',q::text,true);
  insert into public.posts(id,class_id,author_id,kind,title,points,due_at)
    values(post_id,c,owner_id,'assignment','Lifecycle retained work',10,now()+interval '1 day');
  insert into public.post_attachments(post_id,kind,name,url)
    values(post_id,'link','Retained link','https://example.com/lifecycle');
  insert into public.quizzes(id,class_id,author_id,title,status,results_released_at)
    values(q,c,owner_id,'Lifecycle quiz','published',now());
  for i in 2..3 loop
    u := current_setting('join_test.user'||i)::uuid;
    sub_id := gen_random_uuid(); exam_id := gen_random_uuid();
    perform set_config('life.sub'||i,sub_id::text,true);
    perform set_config('life.exam'||i,exam_id::text,true);
    insert into public.submissions(id,post_id,student_id) values(sub_id,post_id,u);
    insert into public.submission_items(submission_id,kind,text_content)
      values(sub_id,'text','Retained student work '||i);
    update public.submissions set status='turned_in',submitted_at=now() where id=sub_id;
    insert into public.submission_grades(submission_id,score,returned_at) values(sub_id,8,now());
    insert into public.exam_sessions(id,quiz_id,student_id,deadline_at)
      values(exam_id,q,u,now()+interval '1 hour');
  end loop;
  insert into storage.objects(bucket_id,name) values
    ('materials',c::text||'/'||post_id::text||'/lifecycle-fixture.txt'),
    ('submissions',c::text||'/'||post_id::text||'/'||current_setting('join_test.user2')||'/fixture.txt'),
    ('submissions',c::text||'/'||post_id::text||'/'||current_setting('join_test.user3')||'/fixture.txt');
  select join_code into code from public.classes where id=c;
  select id into mid from public.class_members where class_id=c and student_id=current_setting('join_test.user2')::uuid;
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_visibility(1,'active student positive control');
  perform pg_temp.lifecycle_count(format('select count(*) from public.classes where id=%L',c2),0,'student cannot read another class');
  perform pg_temp.lifecycle_count(format('select count(*) from public.submissions where id=%L',current_setting('life.sub3')),0,'checklist 1: another student submission hidden');
  perform pg_temp.lifecycle_count(format('select count(*) from public.submission_items where submission_id=%L',current_setting('life.sub3')),0,'checklist 1: another student items hidden');
  perform pg_temp.lifecycle_count(format('select count(*) from public.submission_grades where submission_id=%L',current_setting('life.sub3')),0,'checklist 1: another student grade hidden');
  perform pg_temp.lifecycle_count(format('select count(*) from public.exam_sessions where id=%L',current_setting('life.exam3')),0,'checklist 1: another exam session hidden');
  perform pg_temp.lifecycle_sql(format('select public.get_exam(%L)',current_setting('life.exam3')),'checklist 1: another exam RPC refused','P0001');
  perform pg_temp.lifecycle_sql(format('select public.get_result(%L)',current_setting('life.exam3')),'checklist 1: another result RPC refused','P0001');
  perform pg_temp.lifecycle_sql(format('select public.get_result(%L)',current_setting('life.exam2')),'own released result positive control');

  perform pg_temp.join_actor(4);
  perform pg_temp.lifecycle_visibility(0,'checklist 4: other instructor cannot read class content');
  foreach command in array array[
    format('select public.archive_class(%L)',c),format('select public.restore_class(%L)',c),
    format('select public.delete_class(%L,%L)',c,'QA'),format('select public.restore_deleted_class(%L)',c),
    format('select public.remove_member(%L,%L)',c,current_setting('join_test.user2')),
    format('select public.decide_join(%L,true)',mid),format('select public.approve_all_pending(%L)',c)] loop
    perform pg_temp.lifecycle_sql(command,'checklist 4: cross-owner RPC refused: '||command,'P0001');
  end loop;
  perform pg_temp.lifecycle_count(format('with changed as (update public.classes set course=''intrusion'' where id=%L returning id) select count(*) from changed',c),0,'checklist 4: direct class update changes zero rows');
  perform pg_temp.lifecycle_count(format('with changed as (update public.posts set title=''intrusion'' where id=%L returning id) select count(*) from changed',post_id),0,'checklist 4: direct post update changes zero rows');

  perform pg_temp.join_actor(1);
  perform pg_temp.lifecycle_sql(format('select public.archive_class(%L)',c),'archive succeeds');
  perform pg_temp.check_join((select archived_at is not null and deleted_at is null and join_code=code from public.classes where id=c),'archive metadata and permanent code');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_visibility(1,'archived student read-only materials and returned grades');
  perform pg_temp.lifecycle_sql(format('select public.start_submission(%L)',post_id),'archived submission refused','P0001');
  perform pg_temp.lifecycle_sql(format('select public.start_exam(%L)',q),'archived exam start refused','P0001');
  perform pg_temp.lifecycle_sql(format('select public.get_exam(%L)',current_setting('life.exam2')),'archived exam resume refused','42501');
  perform pg_temp.join_actor(1);
  perform pg_temp.lifecycle_sql(format('insert into public.posts(class_id,author_id,kind,title) values(%L,%L,''announcement'',''blocked'')',c,owner_id),'archive blocks posting','42501');
  perform pg_temp.lifecycle_sql(format('update public.quizzes set title=''blocked'' where id=%L',q),'archive blocks direct quiz edits','42501');
  perform pg_temp.lifecycle_sql(format('insert into public.post_attachments(post_id,kind,name,url) values(%L,''link'',''blocked'',''https://example.com'')',post_id),'archive blocks attachment edits','42501');
  perform pg_temp.lifecycle_sql(format('select public.decide_join(%L,true)',mid),'archive refuses approval','42501');
  perform pg_temp.lifecycle_sql(format('select public.approve_all_pending(%L)',c),'archive refuses bulk approval','42501');
  perform pg_temp.lifecycle_sql(format('select public.restore_class(%L)',c),'restore archive succeeds');
  perform pg_temp.check_join((select archived_at is null and join_code=code from public.classes where id=c),'archive restored; code unchanged');

  foreach bad in array array['wrong','qa',' QA','QA ',''] loop
    perform pg_temp.lifecycle_sql(format('select public.delete_class(%L,%L)',c,bad),'wrong section rejected: ['||bad||']','P0001');
    perform pg_temp.check_join((select deleted_at is null from public.classes where id=c),'wrong section leaves class intact');
  end loop;
  perform pg_temp.lifecycle_sql(format('select public.delete_class(%L,null)',c),'null section rejected','P0001');
  perform pg_temp.lifecycle_sql(format('select public.delete_class(%L,%L)',c,'QA'),'correct section deletes');
  perform pg_temp.lifecycle_count(format('select count(*) from public.classes where id=%L and deleted_at is not null',c),1,'deleted class visible to owner for recovery');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_visibility(0,'deleted class hidden from active student');
  perform pg_temp.lifecycle_sql(format('select public.get_result(%L)',current_setting('life.exam2')),'deleted class result RPC refused','42501');
  -- Pending members must also lose class metadata visibility.
  update public.class_members set status='pending' where id=mid;
  perform pg_temp.lifecycle_count(format('select count(*) from public.classes where id=%L',c),0,'deleted class hidden from pending student');
  update public.class_members set status='active' where id=mid;
  perform pg_temp.join_actor(4);
  perform pg_temp.lifecycle_sql(format('select public.restore_deleted_class(%L)',c),'other instructor cannot recover deleted class','P0001');
  perform pg_temp.join_actor(1);
  update public.classes set deleted_at=now()-interval '14 days'+interval '1 second' where id=c;
  perform pg_temp.lifecycle_sql(format('select public.restore_deleted_class(%L)',c),'recovery just inside 14 days succeeds');
  perform pg_temp.check_join((select deleted_at is null and join_code=code from public.classes where id=c),'recovery preserves permanent code');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_visibility(1,'restored class content accessible again');
  perform pg_temp.join_actor(1);
  foreach bad in array array['14 days','14 days 1 second','15 days'] loop
    update public.classes set deleted_at=now()-bad::interval where id=c;
    perform pg_temp.lifecycle_sql(format('select public.restore_deleted_class(%L)',c),'recovery at/after deadline refused: '||bad,'P0001');
    perform pg_temp.check_join((select deleted_at is not null from public.classes where id=c),'failed recovery keeps deletion');
  end loop;
  -- Restore fixture administratively to isolate remove/leave from deletion.
  update public.classes set deleted_at=null where id=c;
  perform pg_temp.lifecycle_sql(format('select public.remove_member(%L,%L)',c,current_setting('join_test.user2')),'owner removes student');
  perform pg_temp.check_join((select status='removed' and decided_by=owner_id from public.class_members where id=mid),'removed membership retained with decision');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_visibility(0,'checklist 8: removed student cloud access revoked');
  perform pg_temp.lifecycle_sql(format('select public.get_exam(%L)',current_setting('life.exam2')),'removed student exam RPC refused','42501');
  perform pg_temp.lifecycle_sql(format('select public.get_my_session(%L)',q),'removed student session RPC refused','42501');
  perform pg_temp.lifecycle_sql(format('select public.get_result(%L)',current_setting('life.exam2')),'removed student result RPC refused','42501');
  perform pg_temp.join_actor(1);
  perform pg_temp.lifecycle_visibility(2,'owner retains both students work after removal');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_sql(format('select public.request_join(%L)',code),'removed student can request again');
  perform pg_temp.lifecycle_count(format('select count(*) from public.posts where class_id=%L',c),0,'pending rejoin cannot read posts');
  perform pg_temp.check_join((select id=mid and status='pending' from public.class_members where class_id=c and student_id=current_setting('join_test.user2')::uuid),'rejoin retains row and needs approval');
  perform pg_temp.join_actor(1);
  perform pg_temp.lifecycle_sql(format('select public.decide_join(%L,true)',mid),'owner reapproves removed student');
  perform pg_temp.lifecycle_sql(format('select public.archive_class(%L)',c),'archive before student leave');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_sql(format('select public.leave_class(%L)',c),'student can leave archived class');
  perform pg_temp.check_join((select id=mid and status='left' and left_at is not null from public.class_members where id=mid),'leave retains membership row and timestamp');
  perform pg_temp.lifecycle_visibility(0,'left student cloud access revoked');
  perform pg_temp.lifecycle_sql(format('select public.get_result(%L)',current_setting('life.exam2')),'left student result RPC refused','42501');
  perform pg_temp.join_actor(1);
  perform pg_temp.lifecycle_sql(format('select public.restore_class(%L)',c),'restore archive after leave');
  perform pg_temp.lifecycle_visibility(2,'owner retains work and grades after leave');
  perform pg_temp.join_actor(2);
  perform pg_temp.lifecycle_sql(format('select public.request_join(%L)',code),'left student requests again');
  perform pg_temp.check_join((select id=mid and status='pending' and left_at is null from public.class_members where id=mid),'left student reuses membership and requires approval');
  perform pg_temp.lifecycle_count(format('select count(*) from public.posts where class_id=%L',c),0,'left rejoin is still blocked pending approval');
end $$;

select step,test,result from join_results order by step;
rollback;
