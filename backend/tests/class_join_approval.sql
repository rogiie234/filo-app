-- Run the WHOLE file in DEV SQL Editor as postgres; never in production.
-- Requires migrations through 20261014160000_verified_session_gate.sql.
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
select step,test,result from join_results order by step;
rollback;
