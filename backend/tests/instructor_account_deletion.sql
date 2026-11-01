-- DEV ONLY: postgres SQL Editor, WHOLE file after 20261102120000.
-- Rollback fixtures; Storage bytes/Auth Admin/concurrency are separate owner checks.
-- Any FAIL/uncaught error means failure. On interruption run ROLLBACK separately.
begin;
set local search_path=public;
select set_config('request.jwt.claims','{}',true);
create temporary table m13i_results(step integer generated always as identity,test text,result text,detail text) on commit drop;
create function pg_temp.m13i_id(k text) returns uuid language sql as $$
  select current_setting('m13i.'||k)::uuid
$$;
create function pg_temp.m13i_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.m13i_id('u'||i),
    'session_id',pg_temp.m13i_id('s'||i),'role','authenticated')::text,true);
end $$;

do $$
declare i integer; u uuid; s uuid; c uuid; p uuid; sub uuid; q uuid; qu uuid; e uuid;
begin
  for i in 1..6 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m13i.u'||i,u::text,true); perform set_config('m13i.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    insert into public.profiles(id,role,display_name,email,school,avatar_path,google_photo_url,privacy_accepted_at,privacy_version)
      values(u,case when i=4 then 'student'::public.user_role else 'instructor'::public.user_role end,
        'M13 instructor fixture','fixture@example.invalid','School',u||'/photo.png','https://example.invalid/photo',now(),'fixture');
    if i<>5 then insert into public.verified_sessions(session_id,user_id) values(s,u); end if;
  end loop;
  for i in 1..6 loop
    c:=gen_random_uuid(); perform set_config('m13i.c'||i,c::text,true);
    insert into public.classes(id,owner_id,course,section,school_year,archived_at,deleted_at)
      values(c,pg_temp.m13i_id(case when i<=3 then 'u1' when i<=5 then 'u2' else 'u6' end),
        'M13 instructor fixture','Test','2026',case when i=2 then now() end,
        case when i in (3,4) then now()-interval '1 day' when i=5 then now()-interval '20 days' end);
  end loop;
  -- Child rows in a recovery-window class must cascade; unrelated class rows stay.
  for i in 4..6 loop
    c:=pg_temp.m13i_id('c'||i); p:=gen_random_uuid(); sub:=gen_random_uuid();
    q:=gen_random_uuid(); qu:=gen_random_uuid(); e:=gen_random_uuid();
    perform set_config('m13i.post'||i,p::text,true); perform set_config('m13i.sub'||i,sub::text,true);
    perform set_config('m13i.q'||i,q::text,true); perform set_config('m13i.exam'||i,e::text,true);
    insert into public.class_members(class_id,student_id,status) values(c,pg_temp.m13i_id('u4'),'active');
    insert into public.posts(id,class_id,author_id,kind,title,points,due_at)
      select p,c,owner_id,'assignment','M13 fixture',10,now()+interval '1 day' from public.classes where id=c;
    insert into public.submissions(id,post_id,student_id,status,submitted_at) values(sub,p,pg_temp.m13i_id('u4'),'turned_in',now());
    insert into public.submission_grades(submission_id,score,graded_by,graded_at,returned_at)
      values(sub,8,pg_temp.m13i_id(case when i=6 then 'u3' else 'u2' end),now(),now());
    insert into public.quizzes(id,class_id,author_id,title)
      select q,c,owner_id,'M13 fixture' from public.classes where id=c;
    insert into public.questions(id,quiz_id,type,prompt) values(qu,q,'true_false','Synthetic fixture');
    insert into public.answer_keys(question_id,correct_boolean) values(qu,true);
    insert into public.exam_sessions(id,quiz_id,student_id,status,deadline_at,question_order)
      values(e,q,pg_temp.m13i_id('u4'),'submitted',now()+interval '1 hour',array[qu]);
    insert into public.exam_answers(session_id,question_id,bool_answer,points_awarded) values(e,qu,true,1);
  end loop;
end $$;
create function pg_temp.m13i_assert(ok boolean,label text) returns void language plpgsql as $$
begin
  insert into m13i_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end);
end $$;
create function pg_temp.m13i_check(q text,label text,as_role text default 'service_role',
  expected text default 'true') returns void language plpgsql as $$
declare ok boolean; code text:='00000'; msg text;
begin
  begin
    execute format('set local role %I',as_role);
    if expected in ('true','denied') then execute q into ok; else execute q; end if;
    reset role;
    if expected not in ('true','denied','00000') then
      raise exception 'Unexpected success' using errcode='ZM130';
    end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text;
    reset role;
  end;
  insert into m13i_results(test,result,detail) values(label,
    case when (expected='true' and code='00000' and ok is true)
      or (expected='denied' and (code='42501' or (code='00000' and ok is true)))
      or (expected not in ('true','denied') and expected=code) then 'PASS' else 'FAIL' end,
    code||coalesce(': '||msg,': boolean='||coalesce(ok::text,'NULL')));
end $$;


do $$
declare i integer; sig text; before_profile jsonb; state text; detail text; lease uuid; n integer; isolated boolean; blocked boolean:=false;
begin
  foreach sig in array array['next_account_deletion_class(uuid,uuid)',
    'list_account_deletion_class_files(uuid,uuid,uuid)','purge_account_deletion_class(uuid,uuid,uuid)'] loop
    perform pg_temp.m13i_assert(not has_function_privilege('authenticated','public.'||sig,'EXECUTE')
      and not has_function_privilege('anon','public.'||sig,'EXECUTE'),'server-only class helper '||sig);
  end loop;
  for i in 1..6 loop
    perform pg_temp.m13i_actor(i);
    if i=5 then
      perform pg_temp.m13i_check('select public.owned_class_count()','unverified count refused','authenticated','42501');
    else
      perform pg_temp.m13i_check(format('select public.owned_class_count()=%s',case when i=1 then 2 when i=6 then 1 else 0 end),
        'caller-only count actor '||i,'authenticated');
    end if;
  end loop;
  perform set_config('request.jwt.claims','{}',true);
  perform pg_temp.m13i_check('select public.owned_class_count()','missing session count refused','authenticated','42501');
  perform pg_temp.m13i_check('select public.owned_class_count()','anon count refused','anon','42501');
  perform pg_temp.m13i_assert(to_regprocedure('public.owned_class_count(uuid)') is null,'count has no target-account argument');
  perform pg_temp.m13i_assert(to_regprocedure('public.begin_student_account_deletion(uuid,uuid)') is null,'old private student helper renamed');
  perform pg_temp.m13i_assert(not has_function_privilege('authenticated','public.begin_account_deletion(uuid,uuid)','EXECUTE'),'acceptance remains server only');
  perform pg_temp.m13i_actor(6);
  perform pg_temp.m13i_check('select public.begin_account_deletion(pg_temp.m13i_id(''u1''),pg_temp.m13i_id(''s1''))','outsider cannot call victim deletion','authenticated','42501');
  perform pg_temp.m13i_check('select public.begin_account_deletion(pg_temp.m13i_id(''u2''),pg_temp.m13i_id(''s6''))','wrong session refused','service_role','42501');
  perform pg_temp.m13i_check('select public.begin_account_deletion(pg_temp.m13i_id(''u5''),pg_temp.m13i_id(''s5''))','unverified instructor refused','service_role','42501');
  select to_jsonb(p) into before_profile from public.profiles p where id=pg_temp.m13i_id('u1');
  insert into storage.objects(bucket_id,name,owner,owner_id) values('avatars',pg_temp.m13i_id('u1')||'/photo.png',pg_temp.m13i_id('u1'),pg_temp.m13i_id('u1')::text);
  begin
    perform public.begin_account_deletion(pg_temp.m13i_id('u1'),pg_temp.m13i_id('s1'));
    raise exception 'Unexpected acceptance' using errcode='ZM133';
  exception when others then get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform pg_temp.m13i_assert(state='P1303' and detail::jsonb='{"count":2}'::jsonb,'block error includes exact live plus archived count');
  perform pg_temp.m13i_assert((select to_jsonb(p)=before_profile from public.profiles p where id=pg_temp.m13i_id('u1')),'blocked profile unchanged');
  perform pg_temp.m13i_assert(exists(select 1 from auth.users where id=pg_temp.m13i_id('u1')),'blocked login unchanged');
  perform pg_temp.m13i_assert(not exists(select 1 from public.account_deletions where user_id=pg_temp.m13i_id('u1')),'blocked deletion creates no job');
  perform pg_temp.m13i_assert(exists(select 1 from storage.objects where bucket_id='avatars' and name=pg_temp.m13i_id('u1')||'/photo.png'),'blocked photo unchanged');
  perform pg_temp.m13i_actor(1);
  update public.classes set deleted_at=now() where id=pg_temp.m13i_id('c1');
  perform pg_temp.m13i_check('select public.owned_class_count()=1','archived class still blocks alone','authenticated');
  update public.classes set deleted_at=null where id=pg_temp.m13i_id('c1');
  perform set_config('request.jwt.claims','{}',true);
  perform pg_temp.m13i_check('select not public.finish_deleted_class_purge(pg_temp.m13i_id(''c4''))','ordinary purge preserves recovery window');
  perform pg_temp.m13i_check('select public.list_account_deletion_class_files(pg_temp.m13i_id(''u2''),gen_random_uuid(),pg_temp.m13i_id(''c4''))','early purge requires job and lease','service_role','42501');
  perform pg_temp.m13i_check('select public.begin_account_deletion(pg_temp.m13i_id(''u2''),pg_temp.m13i_id(''s2''))','recovery-window instructor accepted','service_role','00000');
  lease:=public.claim_account_deletion(pg_temp.m13i_id('u2')); perform set_config('m13i.lease',lease::text,true);
  perform pg_temp.m13i_assert(lease is not null,'worker claims instructor job');
  perform pg_temp.m13i_assert(public.next_account_deletion_class(pg_temp.m13i_id('u2'),lease) in (pg_temp.m13i_id('c4'),pg_temp.m13i_id('c5')),'selects only owned deleted classes');
  perform pg_temp.m13i_check('update public.classes set deleted_at=null where id=pg_temp.m13i_id(''c4'')','restoration blocked after acceptance','service_role','42501');
  perform pg_temp.m13i_check('insert into public.classes(owner_id,course,section,school_year) values(pg_temp.m13i_id(''u2''),''M13'',''new'',''2026'')','creation blocked after acceptance','service_role','42501');
  perform pg_temp.m13i_check('update public.classes set owner_id=pg_temp.m13i_id(''u6'') where id=pg_temp.m13i_id(''c4'')','cannot move deleting owners class away','service_role','42501');
  perform pg_temp.m13i_check('update public.classes set owner_id=pg_temp.m13i_id(''u2'') where id=pg_temp.m13i_id(''c6'')','cannot assign class to deleting owner','service_role','42501');
  perform pg_temp.m13i_check('select public.prepare_account_auth_deletion(pg_temp.m13i_id(''u2''),pg_temp.m13i_id(''lease''))','Auth waits for owned classes','service_role','P0001');
  begin
    insert into storage.objects(bucket_id,name)
      select case gs.n%3 when 0 then 'banners' when 1 then 'materials' else 'submissions' end,
        pg_temp.m13i_id('c4')||'/nested/'||gs.n||'.bin' from generate_series(1,501) gs(n);
    insert into storage.objects(bucket_id,name) values('materials',pg_temp.m13i_id('c6')||'/unrelated.bin');
    select count(*),bool_and(starts_with(name,pg_temp.m13i_id('c4')::text||'/')) into n,isolated
      from public.list_account_deletion_class_files(pg_temp.m13i_id('u2'),lease,pg_temp.m13i_id('c4'));
    begin perform public.purge_account_deletion_class(pg_temp.m13i_id('u2'),lease,pg_temp.m13i_id('c4'));
    exception when sqlstate 'P0001' then blocked:=true; end;
    raise exception 'Rollback metadata probe' using errcode='ZM134';
  exception when sqlstate 'ZM134' then null;
  end;
  perform pg_temp.m13i_assert(n=500 and isolated,'class files paginated and isolated across buckets');
  perform pg_temp.m13i_assert(blocked,'remaining files block class purge');
  perform pg_temp.m13i_check('select public.purge_account_deletion_class(pg_temp.m13i_id(''u2''),pg_temp.m13i_id(''lease''),pg_temp.m13i_id(''c6''))','unrelated live class cannot purge','service_role','42501');
  perform pg_temp.m13i_check('select public.list_account_deletion_class_files(pg_temp.m13i_id(''u2''),gen_random_uuid(),pg_temp.m13i_id(''c4''))','wrong lease cannot enumerate','service_role','42501');
  perform public.release_account_deletion(pg_temp.m13i_id('u2'),lease,'storage');
  perform pg_temp.m13i_assert((select completed_at is null and last_error='storage' from public.account_deletions where user_id=pg_temp.m13i_id('u2')),'Storage failure stays pending');
  lease:=public.claim_account_deletion(pg_temp.m13i_id('u2')); perform set_config('m13i.lease',lease::text,true);
  perform pg_temp.m13i_assert(lease is not null,'cleanup can resume');
  perform public.purge_account_deletion_class(pg_temp.m13i_id('u2'),lease,pg_temp.m13i_id('c4'));
  perform public.purge_account_deletion_class(pg_temp.m13i_id('u2'),lease,pg_temp.m13i_id('c5'));
  perform pg_temp.m13i_assert(not exists(select 1 from public.classes where owner_id=pg_temp.m13i_id('u2')),'all recent and older owned classes purged');
  perform pg_temp.m13i_assert(not exists(select 1 from public.posts where id in(pg_temp.m13i_id('post4'),pg_temp.m13i_id('post5'))),'posts cascade');
  perform pg_temp.m13i_assert(not exists(select 1 from public.submissions where id in(pg_temp.m13i_id('sub4'),pg_temp.m13i_id('sub5'))),'submissions cascade');
  perform pg_temp.m13i_assert(not exists(select 1 from public.submission_grades where submission_id in(pg_temp.m13i_id('sub4'),pg_temp.m13i_id('sub5'))),'grades cascade');
  perform pg_temp.m13i_assert(not exists(select 1 from public.exam_sessions where id in(pg_temp.m13i_id('exam4'),pg_temp.m13i_id('exam5'))),'exam sessions cascade');
  perform pg_temp.m13i_assert(exists(select 1 from public.submission_grades where submission_id=pg_temp.m13i_id('sub6') and score=8),'unrelated work retained');
  perform public.prepare_account_auth_deletion(pg_temp.m13i_id('u2'),lease);
  delete from auth.users where id=pg_temp.m13i_id('u2'); -- SQL simulation only.
  perform public.finish_account_deletion(pg_temp.m13i_id('u2'),lease);
  perform pg_temp.m13i_assert(public.claim_account_deletion(pg_temp.m13i_id('u2')) is null,'completed deletion cannot repeat');
  insert into public.class_members(class_id,student_id,status) values(pg_temp.m13i_id('c6'),pg_temp.m13i_id('u3'),'left');
  insert into public.device_tokens(user_id,fcm_token) values(pg_temp.m13i_id('u3'),'m13i-fixture-'||pg_temp.m13i_id('u3'));
  insert into public.trusted_devices(user_id,device_hash) values(pg_temp.m13i_id('u3'),repeat('b',64));
  insert into public.notification_settings(user_id,type) values(pg_temp.m13i_id('u3'),'announcement');
  insert into public.notifications(recipient_id,type,title) values(pg_temp.m13i_id('u3'),'announcement','M13 fixture');
  perform public.begin_account_deletion(pg_temp.m13i_id('u3'),pg_temp.m13i_id('s3'));
  lease:=public.claim_account_deletion(pg_temp.m13i_id('u3'));
  perform pg_temp.m13i_assert(public.next_account_deletion_class(pg_temp.m13i_id('u3'),lease) is null,'no-class instructor needs no purge');
  perform public.prepare_account_auth_deletion(pg_temp.m13i_id('u3'),lease);
  delete from auth.users where id=pg_temp.m13i_id('u3');
  perform public.finish_account_deletion(pg_temp.m13i_id('u3'),lease);
  perform pg_temp.m13i_assert((select display_name='Deleted User' and email is null and school is null and avatar_path is null
    and google_photo_url is null and privacy_accepted_at is null and privacy_version is null and deleted_at is not null
    from public.profiles where id=pg_temp.m13i_id('u3')),'no-class instructor anonymized');
  perform pg_temp.m13i_assert(not exists(select 1 from public.device_tokens where user_id=pg_temp.m13i_id('u3'))
    and not exists(select 1 from public.trusted_devices where user_id=pg_temp.m13i_id('u3'))
    and not exists(select 1 from public.notification_settings where user_id=pg_temp.m13i_id('u3'))
    and not exists(select 1 from public.notifications where recipient_id=pg_temp.m13i_id('u3')),'devices settings inbox removed');
  perform pg_temp.m13i_actor(6);
  perform pg_temp.m13i_check('select count(*)=1 from public.submission_grades g join public.profiles p on p.id=g.graded_by where g.submission_id=pg_temp.m13i_id(''sub6'') and g.score=8 and p.display_name=''Deleted User''',
    'surviving grade retains Deleted User grader','authenticated');
  perform pg_temp.m13i_assert(not exists(select 1 from public.classes c left join public.profiles p on p.id=c.owner_id
    where c.id in (pg_temp.m13i_id('c1'),pg_temp.m13i_id('c2'),pg_temp.m13i_id('c3'),pg_temp.m13i_id('c6'))
    and (p.id is null or p.deleted_at is not null)),'no fixture class has missing or deleted owner');
  perform pg_temp.m13i_assert(exists(select 1 from auth.users where id=pg_temp.m13i_id('u4')),'unrelated student login retained');
end $$;
select * from m13i_results order by step;
select count(*) filter(where result='PASS') passed,count(*) filter(where result='FAIL') failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end overall,
  coalesce(jsonb_agg(jsonb_build_object('test',test,'detail',detail)) filter(where result='FAIL'),'[]') failures
from m13i_results;
rollback;
