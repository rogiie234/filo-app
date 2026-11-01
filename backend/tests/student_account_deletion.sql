-- DEV ONLY, postgres SQL Editor. Run WHOLE file after 20261102120000.
-- Synthetic SQL fixtures prove database behavior, NOT Storage bytes or Auth Admin API.
-- No real accounts are deleted. Everything rolls back. Any FAIL/uncaught error fails.
-- On interruption run ROLLBACK separately before retrying.
begin;
set local search_path=public;
select set_config('request.jwt.claims','{}',true);
create temporary table m13d_results(step integer generated always as identity,
  test text,result text,detail text) on commit drop;
create temporary table m13d_before(kind text,id uuid,value jsonb) on commit drop;

create function pg_temp.m13d_id(k text) returns uuid language sql as $$
  select current_setting('m13d.'||k)::uuid
$$;
create function pg_temp.m13d_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.m13d_id('u'||i),
    'session_id',pg_temp.m13d_id('s'||i),'role','authenticated')::text,true);
end $$;
create function pg_temp.m13d_assert(ok boolean,label text) returns void language plpgsql as $$
begin
  insert into m13d_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end);
end $$;
create function pg_temp.m13d_check(q text,label text,as_role text default 'service_role',
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
  insert into m13d_results(test,result,detail) values(label,
    case when (expected='true' and code='00000' and ok is true)
      or (expected='denied' and (code='42501' or (code='00000' and ok is true)))
      or (expected not in ('true','denied') and expected=code) then 'PASS' else 'FAIL' end,
    code||coalesce(': '||msg,': boolean='||coalesce(ok::text,'NULL')));
end $$;

do $$
declare i integer; u uuid; s uuid; c uuid:=gen_random_uuid(); p uuid:=gen_random_uuid();
  q uuid:=gen_random_uuid(); qu uuid:=gen_random_uuid(); sub uuid; es uuid;
begin
  for i in 1..5 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m13d.u'||i,u::text,true);
    perform set_config('m13d.s'||i,s::text,true);
    insert into auth.users(id,email) values(u,'m13d-'||u||'@example.invalid');
    insert into auth.sessions(id,user_id) values(s,u);
    insert into public.profiles(id,role,display_name,email,school,google_photo_url,
      avatar_path,privacy_accepted_at,privacy_version) values(u,
      case when i=1 then 'instructor'::public.user_role else 'student'::public.user_role end,
      'M13 deletion fixture','m13d-'||u||'@example.invalid','School',
      'https://example.invalid/photo',u||'/current.png',now(),'m13-test');
    if i<>4 then insert into public.verified_sessions(session_id,user_id) values(s,u); end if;
    insert into public.trusted_devices(user_id,device_hash) values(u,repeat('a',64));
    insert into public.device_tokens(user_id,fcm_token) values(u,'m13d-'||u);
    insert into public.notification_settings(user_id,type) values(u,'announcement');
    insert into public.otp_codes(user_id,device_hash,code_hash,expires_at,session_id)
      values(u,repeat('a',64),'fixture-not-a-code',now()+interval '5 minutes',s);
    insert into public.notifications(recipient_id,type,title) values(u,'announcement','M13 fixture');
  end loop;
  perform set_config('m13d.class',c::text,true);
  perform set_config('m13d.post',p::text,true);
  perform set_config('m13d.quiz',q::text,true);
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,pg_temp.m13d_id('u1'),'M13 fixture','Deletion','2026');
  insert into public.class_members(class_id,student_id,status)
    values(c,pg_temp.m13d_id('u2'),'active'),(c,pg_temp.m13d_id('u3'),'active'),
      (c,pg_temp.m13d_id('u4'),'pending');
  insert into public.posts(id,class_id,author_id,kind,title,points,due_at)
    values(p,c,pg_temp.m13d_id('u1'),'assignment','M13 retained assignment',10,now()+interval '1 day');
  insert into public.quizzes(id,class_id,author_id,title,type)
    values(q,c,pg_temp.m13d_id('u1'),'M13 retained exam','exam');
  insert into public.questions(id,quiz_id,position,type,prompt,points)
    values(qu,q,0,'true_false','M13 synthetic question',1);
  insert into public.answer_keys(question_id,correct_boolean) values(qu,true);
  for i in 2..3 loop
    sub:=gen_random_uuid(); es:=gen_random_uuid();
    perform set_config('m13d.sub'||i,sub::text,true);
    perform set_config('m13d.exam'||i,es::text,true);
    insert into public.submissions(id,post_id,student_id) values(sub,p,pg_temp.m13d_id('u'||i));
    insert into public.submission_items(submission_id,kind,text_content) values(sub,'text','M13 retained work');
    update public.submissions set status='turned_in',submitted_at=now() where id=sub;
    insert into public.submission_grades(submission_id,score,feedback,graded_by,graded_at,returned_at)
      values(sub,8,'M13 retained feedback',pg_temp.m13d_id('u1'),now(),now());
    insert into public.exam_sessions(id,quiz_id,student_id,status,deadline_at,submitted_at,
      question_order,auto_score,grading_complete)
      values(es,q,pg_temp.m13d_id('u'||i),'submitted',now()+interval '1 hour',now(),array[qu],1,true);
    insert into public.exam_answers(session_id,question_id,bool_answer,is_correct,points_awarded)
      values(es,qu,true,true,1);
  end loop;
  -- Retained submission metadata belongs to Auth initially; only ownership may change.
  insert into storage.objects(bucket_id,name,owner,owner_id,metadata) values('submissions',
    c||'/'||p||'/'||pg_temp.m13d_id('u2')||'/retained.png',pg_temp.m13d_id('u2'),
    pg_temp.m13d_id('u2')::text,'{"mimetype":"image/png","size":32}');
  perform set_config('m13d.retained_path',c||'/'||p||'/'||pg_temp.m13d_id('u2')||'/retained.png',true);
end $$;

insert into m13d_before select 'submissions',id,to_jsonb(s) from public.submissions s
  where student_id in(pg_temp.m13d_id('u2'),pg_temp.m13d_id('u3'));
insert into m13d_before select 'items',id,to_jsonb(s) from public.submission_items s
  where submission_id in(pg_temp.m13d_id('sub2'),pg_temp.m13d_id('sub3'));
insert into m13d_before select 'grades',submission_id,to_jsonb(s) from public.submission_grades s
  where submission_id in(pg_temp.m13d_id('sub2'),pg_temp.m13d_id('sub3'));
insert into m13d_before select 'exams',id,to_jsonb(s) from public.exam_sessions s
  where student_id in(pg_temp.m13d_id('u2'),pg_temp.m13d_id('u3'));
insert into m13d_before select 'answers',id,to_jsonb(s) from public.exam_answers s
  where session_id in(pg_temp.m13d_id('exam2'),pg_temp.m13d_id('exam3'));
insert into m13d_before select 'outsider',id,to_jsonb(p) from public.profiles p where id=pg_temp.m13d_id('u3');

do $$
declare sig text; lease uuid; old_lease uuid; t text; page_size integer; isolated boolean; blocked boolean:=false;
begin
  foreach sig in array array['begin_account_deletion(uuid,uuid)','claim_account_deletion(uuid)',
    'list_account_avatars(uuid,uuid)','prepare_account_auth_deletion(uuid,uuid)',
    'finish_account_deletion(uuid,uuid)','release_account_deletion(uuid,uuid,text)'] loop
    perform pg_temp.m13d_assert(not has_function_privilege('authenticated','public.'||sig,'EXECUTE')
      and not has_function_privilege('anon','public.'||sig,'EXECUTE'),'server-only helper '||sig);
  end loop;
  perform pg_temp.m13d_assert(not has_table_privilege('authenticated','public.account_deletions','SELECT')
    and not has_table_privilege('authenticated','public.account_deletions','INSERT'),'deletion ledger hidden');
  perform pg_temp.m13d_actor(3);
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''s2''))',
    'outsider cannot nominate victim','authenticated','42501');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''s3''))',
    'server rejects mismatched session','service_role','42501');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u4''),pg_temp.m13d_id(''s4''))',
    'unverified student refused','service_role','42501');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u1''),pg_temp.m13d_id(''s1''))',
    'instructor with live classes refused','service_role','P1303');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),gen_random_uuid())',
    'unknown/revoked session refused','service_role','42501');
  perform pg_temp.m13d_assert(not exists(select 1 from public.account_deletions), 'denials made no deletion job');

  perform pg_temp.m13d_actor(2);
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''s2''))',
    'accept student deletion','service_role','00000');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''s2''))',
    'accepted deletion resumes same request','service_role','00000');
  perform pg_temp.m13d_assert((select count(*)=1 from public.account_deletions where user_id=pg_temp.m13d_id('u2')),'one permanent request');
  perform pg_temp.m13d_assert((select display_name='Deleted User' and deleted_at is not null
    and email is null and school is null and avatar_path is null and google_photo_url is null
    and privacy_accepted_at is null and privacy_version is null
    from public.profiles where id=pg_temp.m13d_id('u2')),'profile anonymized');
  perform pg_temp.m13d_assert((select bool_and(status='left' and left_at is not null)
    from public.class_members where student_id=pg_temp.m13d_id('u2')),'memberships left');
  foreach t in array array['device_tokens','trusted_devices','otp_codes','notification_settings'] loop
    perform pg_temp.m13d_check(format('select count(*)=0 from public.%I where user_id=%L',t,pg_temp.m13d_id('u2')),t||' cleared');
    perform pg_temp.m13d_check(format('select count(*)=1 from public.%I where user_id=%L',t,pg_temp.m13d_id('u3')),t||' unrelated account intact');
  end loop;
  perform pg_temp.m13d_check('select count(*)=0 from public.notifications where recipient_id=pg_temp.m13d_id(''u2'')','inbox cleared');
  perform pg_temp.m13d_check('select not public.current_user_ok()','pending deletion blocks app access','authenticated');
  perform pg_temp.m13d_check('select count(*)=0 from public.profiles','deleted account reads no profiles','authenticated','denied');
  perform pg_temp.m13d_check($q$with x as (update public.profiles set display_name='Restored'
    where id=auth.uid() returning id) select count(*)=0 from x$q$,'no self restoration','authenticated','denied');
  perform pg_temp.m13d_check('update public.profiles set deleted_at=null where id=pg_temp.m13d_id(''u2'')',
    'even server cannot undo accepted deletion','service_role','42501');
  perform pg_temp.m13d_check('update public.class_members set status=''active'' where student_id=pg_temp.m13d_id(''u2'')',
    'cannot reactivate old membership','service_role','42501');
  perform pg_temp.m13d_check('insert into public.device_tokens(user_id,fcm_token) values(pg_temp.m13d_id(''u2''),''m13d-forbidden'')',
    'cannot recreate device registration','service_role','42501');
  perform pg_temp.m13d_check('insert into public.notifications(recipient_id,type,title) values(pg_temp.m13d_id(''u2''),''announcement'',''ignored'')',
    'late notification producer remains usable','service_role','00000');
  perform pg_temp.m13d_check('select count(*)=0 from public.notifications where recipient_id=pg_temp.m13d_id(''u2'')','late notifications suppressed');

  lease:=public.claim_account_deletion(pg_temp.m13d_id('u2'));
  perform set_config('m13d.lease',lease::text,true);
  perform pg_temp.m13d_assert(lease is not null,'worker claims pending job');
  perform pg_temp.m13d_assert(public.claim_account_deletion(pg_temp.m13d_id('u2')) is null,'concurrent worker cannot claim');
  -- Roll back metadata-only probe fixtures without issuing direct Storage DELETE.
  begin
    insert into storage.objects(bucket_id,name,owner,owner_id)
      select 'avatars',pg_temp.m13d_id('u2')||'/nested/'||gs.n||'.png',pg_temp.m13d_id('u2'),pg_temp.m13d_id('u2')::text
      from generate_series(1,501) gs(n);
    insert into storage.objects(bucket_id,name,owner,owner_id)
      values('avatars',pg_temp.m13d_id('u3')||'/other.png',pg_temp.m13d_id('u3'),pg_temp.m13d_id('u3')::text);
    select count(*),bool_and(starts_with(name,pg_temp.m13d_id('u2')::text||'/'))
      into page_size,isolated from public.list_account_avatars(pg_temp.m13d_id('u2'),lease);
    begin
      perform public.prepare_account_auth_deletion(pg_temp.m13d_id('u2'),lease);
    exception when sqlstate 'P0001' then blocked:=true;
    end;
    raise exception 'Rollback metadata probe' using errcode='ZM131';
  exception when sqlstate 'ZM131' then null;
  end;
  perform pg_temp.m13d_assert(page_size=500,'avatar enumeration bounded at 500 including nested uploads');
  perform pg_temp.m13d_assert(isolated,'avatar enumeration excludes other owners');
  perform pg_temp.m13d_assert(blocked,'avatars prevent Auth preparation');
  perform pg_temp.m13d_check('select public.finish_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''lease''))',
    'cannot finish before Auth removal','service_role','P0001');
  perform pg_temp.m13d_check('select public.prepare_account_auth_deletion(pg_temp.m13d_id(''u2''),gen_random_uuid())',
    'stale/wrong lease cannot prepare','service_role','42501');
  perform pg_temp.m13d_check('select public.prepare_account_auth_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''lease''))',
    'detach retained file ownership','service_role','00000');
  perform pg_temp.m13d_assert((select owner is null and owner_id is null and metadata='{"mimetype":"image/png","size":32}'::jsonb
    from storage.objects where bucket_id='submissions' and name=current_setting('m13d.retained_path')),'retained storage metadata/path survives');
  perform public.release_account_deletion(pg_temp.m13d_id('u2'),lease,'auth');
  perform pg_temp.m13d_assert((select last_error='auth' and completed_at is null from public.account_deletions
    where user_id=pg_temp.m13d_id('u2')),'Auth failure remains pending');
  lease:=public.claim_account_deletion(pg_temp.m13d_id('u2'));
  old_lease:=lease;
  update public.account_deletions set lease_until=clock_timestamp()-interval '1 second'
    where user_id=pg_temp.m13d_id('u2');
  lease:=public.claim_account_deletion(pg_temp.m13d_id('u2'));
  perform pg_temp.m13d_assert(lease is not null and lease<>old_lease,'expired worker lease can be recovered');
  perform pg_temp.m13d_assert(not exists(select 1 from public.account_deletions where lease_id=old_lease),'stale lease replaced');
  perform set_config('m13d.lease',lease::text,true);
  -- SQL simulation only: real Auth Admin removal is checked by Edge/runtime tests.
  delete from auth.users where id=pg_temp.m13d_id('u2');
  perform pg_temp.m13d_check('select public.finish_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''lease''))',
    'complete after external cleanup confirmation','service_role','00000');
  perform pg_temp.m13d_assert(not exists(select 1 from auth.users where id=pg_temp.m13d_id('u2')),'simulated login removed');
  perform pg_temp.m13d_assert(not exists(select 1 from auth.sessions where user_id=pg_temp.m13d_id('u2')),'Auth sessions cascade removed');
  perform pg_temp.m13d_assert(not exists(select 1 from public.verified_sessions where user_id=pg_temp.m13d_id('u2')),'OTP session proofs removed');
  perform pg_temp.m13d_assert((select completed_at is not null from public.account_deletions where user_id=pg_temp.m13d_id('u2')),'job complete');
  perform pg_temp.m13d_assert(public.claim_account_deletion(pg_temp.m13d_id('u2')) is null,'completed deletion cannot repeat');
  perform pg_temp.m13d_check('select public.begin_account_deletion(pg_temp.m13d_id(''u2''),pg_temp.m13d_id(''s2''))',
    'old session cannot restart deletion','service_role','42501');
end $$;

-- Compare every saved educational row with its independent pre-deletion snapshot.
do $$
declare b record; actual jsonb; tbl text;
begin
  for b in select * from m13d_before loop
    tbl:=case b.kind when 'items' then 'submission_items' when 'grades' then 'submission_grades'
      when 'exams' then 'exam_sessions' when 'answers' then 'exam_answers'
      when 'outsider' then 'profiles' else 'submissions' end;
    execute format('select to_jsonb(t) from public.%I t where %I=$1',tbl,
      case when b.kind='grades' then 'submission_id' else 'id' end) into actual using b.id;
    perform pg_temp.m13d_assert(actual=b.value,'unchanged '||b.kind||' fixture');
  end loop;
end $$;

select pg_temp.m13d_actor(1);
select pg_temp.m13d_check($q$select count(*)=1 from public.class_members m
  join public.profiles p on p.id=m.student_id join public.submissions s on s.student_id=p.id
  join public.submission_grades g on g.submission_id=s.id
  where m.class_id=pg_temp.m13d_id('class') and m.status='left' and p.display_name='Deleted User'
    and s.id=pg_temp.m13d_id('sub2') and s.status='turned_in' and g.score=8$q$,
  'instructor gradebook retains Deleted User and grade','authenticated');
select pg_temp.m13d_check($q$select count(*)=1 from public.exam_sessions e
  join public.profiles p on p.id=e.student_id join public.exam_answers a on a.session_id=e.id
  where e.id=pg_temp.m13d_id('exam2') and p.display_name='Deleted User' and e.total_score=1
    and a.bool_answer and a.points_awarded=1$q$,'instructor exam records retain Deleted User','authenticated');

-- Same email, different Auth UUID: Google OAuth itself is an owner runtime check.
do $$
declare u uuid:=gen_random_uuid(); s uuid:=gen_random_uuid();
begin
  insert into auth.users(id,email) values(u,'m13d-'||pg_temp.m13d_id('u2')||'@example.invalid');
  insert into auth.sessions(id,user_id) values(s,u);
  insert into public.verified_sessions(session_id,user_id) values(s,u);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',s,'role','authenticated')::text,true);
  perform pg_temp.m13d_check('select public.current_user_ok()','new same-email identity can onboard','authenticated');
  perform pg_temp.m13d_check('select count(*)=0 from public.profiles where id=auth.uid()','fresh identity requires role selection','authenticated');
  perform pg_temp.m13d_check($q$with x as (insert into public.profiles(id,role,display_name,email,privacy_accepted_at)
    values(auth.uid(),'instructor','M13 fresh identity','fresh@example.invalid',now()) returning id)
    select count(*)=1 from x$q$,'new identity can select a different initial role','authenticated');
  perform pg_temp.m13d_check('select count(*)=0 from public.class_members where student_id=auth.uid()','no inherited memberships','authenticated');
  perform pg_temp.m13d_check('select count(*)=0 from public.submissions where student_id=auth.uid()','no inherited work ownership','authenticated');
  perform pg_temp.m13d_assert(not exists(select 1 from public.account_deletions where user_id=u),'no inherited deletion state');
end $$;

select * from m13d_results order by step;
select count(*) filter(where result='PASS') passed,count(*) filter(where result='FAIL') failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end overall,
  coalesce(jsonb_agg(jsonb_build_object('test',test,'detail',detail)) filter(where result='FAIL'),'[]') failures
from m13d_results;
rollback;
