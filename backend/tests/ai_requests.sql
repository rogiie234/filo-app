-- M10-BE-02. DEV ONLY: run WHOLE file as postgres after 20261027100000.
-- Fixtures and cleanup command roll back. On abort run ROLLBACK before retry.
-- This is not HTTP/provider/concurrency/scheduler execution evidence.
begin;
create temporary table m10_results(step integer generated always as identity,
  test text, result text, detail text) on commit drop;
create function pg_temp.m10_check(ok boolean, label text) returns void language sql as $$
  insert into m10_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end);
$$;
create function pg_temp.m10_run(q text, actor text, expected text, label text) returns void language plpgsql as $$
declare code text := '00000'; msg text;
begin
  begin
    execute format('set local role %I',actor); execute q; reset role;
    if expected <> '00000' then raise exception 'Unexpected success' using errcode='ZQ001'; end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text; reset role;
    if code='ZQ001' then code:='00000'; end if;
  end;
  insert into m10_results(test,result,detail) values(label,
    case when code=expected then 'PASS' else 'FAIL' end,code||coalesce(': '||msg,''));
end $$;
create function pg_temp.m10_snapshot(qid uuid) returns jsonb language sql as $$
select jsonb_build_object('quiz',(select to_jsonb(q) from quizzes q where id=qid),
 'questions',(select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]') from questions x where quiz_id=qid),
 'options',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from question_options o
   join questions x on x.id=o.question_id where x.quiz_id=qid),
 'keys',(select coalesce(jsonb_agg(to_jsonb(k) order by k.question_id),'[]') from answer_keys k
   join questions x on x.id=k.question_id where x.quiz_id=qid));
$$;
do $$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); a uuid; b uuid; n integer;
  role_name text; cmd text; old_id uuid:=gen_random_uuid(); recent_id uuid:=gen_random_uuid();
begin
  perform pg_temp.m10_check((select array_agg(column_name::text order by ordinal_position)=
    array['id','user_id','kind','status','error_code','created_at','finished_at']
    from information_schema.columns where table_schema='public' and table_name='ai_usage_log'),
    'log contains only ID and approved metadata');
  perform pg_temp.m10_check((select relrowsecurity from pg_class where oid='public.ai_usage_log'::regclass),'log RLS enabled');
  -- Restrictive session gates cannot grant access without a permissive policy.
  perform pg_temp.m10_check(not exists(select 1 from pg_policy
    where polrelid='public.ai_usage_log'::regclass and polpermissive),'log has no permissive access policies');
  foreach role_name in array array['anon','authenticated'] loop
    perform pg_temp.m10_check(not has_function_privilege(role_name,'public.begin_ai_request(uuid,ai_kind)','EXECUTE')
      and not has_function_privilege(role_name,'public.finish_ai_request(uuid,ai_status,text)','EXECUTE'),role_name||' cannot execute AI RPCs');
    perform pg_temp.m10_check(not has_table_privilege(role_name,'public.ai_usage_log','SELECT')
      and not has_table_privilege(role_name,'public.ai_usage_log','INSERT')
      and not has_table_privilege(role_name,'public.ai_usage_log','UPDATE')
      and not has_table_privilege(role_name,'public.ai_usage_log','DELETE'),role_name||' has no log DML grants');
  end loop;
  set local role service_role; a:=public.begin_ai_request(u,'generate_quiz'); reset role;
  perform pg_temp.m10_check(a is not null,'service first request returns ID');
  select count(*) into n from ai_usage_log where user_id=u;
  set local role service_role; b:=public.begin_ai_request(u,'generate_quiz'); reset role;
  perform pg_temp.m10_check(b is null and (select count(*)=n from ai_usage_log where user_id=u),'recent unfinished request refused without new row');
  set local role service_role; b:=public.begin_ai_request(other_user,'generate_quiz'); reset role;
  perform pg_temp.m10_check(b is not null,'another user is independent');
  update ai_usage_log set created_at=now()-interval '2 minutes 1 second' where id=a;
  set local role service_role;
  b:=public.begin_ai_request(u,'generate_quiz'); perform public.finish_ai_request(b,'success');
  reset role;
  perform pg_temp.m10_check(b is not null,'stale request does not block');
  perform pg_temp.m10_check((select status='success' and error_code is null and finished_at between created_at and now() from ai_usage_log where id=b),'success finish fields');
  set local role service_role;
  a:=public.begin_ai_request(u,'generate_quiz'); perform public.finish_ai_request(a,'failed','AI_TIMEOUT');
  reset role;
  perform pg_temp.m10_check(a is not null,'finished request releases slot immediately');
  perform pg_temp.m10_check((select status='failed' and error_code='AI_TIMEOUT' and finished_at between created_at and now() from ai_usage_log where id=a),'failed finish fields');
  set local role service_role; perform public.finish_ai_request(a,'failed','AI_TIMEOUT'); reset role;
  perform pg_temp.m10_check((select count(*)=1 and bool_and(status='failed' and error_code='AI_TIMEOUT' and finished_at between created_at and now()) from ai_usage_log where id=a),'finish retry preserves one terminal row');
  insert into ai_usage_log(id,user_id,kind,created_at) values
    (old_id,u,'generate_quiz',now()-interval '30 days 1 second'),(recent_id,u,'generate_quiz',now()-interval '30 days');
  select command into cmd from cron.job where jobname='filo-purge-ai-log' and active;
  perform pg_temp.m10_check(cmd is not null and (select count(*)=1 from cron.job where jobname='filo-purge-ai-log' and active),'one active cleanup job exists');
  perform pg_temp.m10_check((select schedule='15 3 * * *' from cron.job where jobname='filo-purge-ai-log'),'cleanup daily schedule');
  if cmd is not null then execute cmd; end if;
  perform pg_temp.m10_check(not exists(select 1 from ai_usage_log where id=old_id)
    and exists(select 1 from ai_usage_log where id=recent_id),'cleanup command removes older than 30 days, retains boundary');
end $$;
-- Exercise anonymous and real verified student/instructor identities.
do $$
declare owner_id uuid:=gen_random_uuid(); student_id uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid();
  student_session uuid:=gen_random_uuid(); class_id uuid:=gen_random_uuid(); quiz_id uuid:=gen_random_uuid();
  qid uuid; r jsonb; payload jsonb:='{"type":"essay","prompt":"M10 fixture","points":1,"position":0}';
  flag jsonb; before_state jsonb; operation text; actor integer; role_name text; t text; type_payload jsonb;
begin
  insert into auth.users(id) values(owner_id),(student_id);
  insert into auth.sessions(id,user_id) values(sid,owner_id),(student_session,student_id);
  insert into profiles(id,role,display_name) values(owner_id,'instructor','M10 fixture'),(student_id,'student','M10 fixture');
  insert into verified_sessions(session_id,user_id) values(sid,owner_id),(student_session,student_id);
  insert into classes(id,owner_id,course,section,school_year) values(class_id,owner_id,'M10 fixture','M10','2026-2027');
  insert into quizzes(id,class_id,author_id,title) values(quiz_id,class_id,owner_id,'M10 fixture');
  for actor in 0..2 loop
    role_name:=case when actor=0 then 'anon' else 'authenticated' end;
    perform set_config('request.jwt.claims',case when actor=0 then '{}' else jsonb_build_object(
      'sub',case when actor=1 then student_id else owner_id end,
      'session_id',case when actor=1 then student_session else sid end,'role','authenticated')::text end,true);
    foreach operation in array array[
      'select * from public.ai_usage_log',
      format('insert into public.ai_usage_log(user_id,kind) values(%L,''generate_quiz'')',owner_id),
      'update public.ai_usage_log set status=''failed''', 'delete from public.ai_usage_log',
      format('select public.begin_ai_request(%L,''generate_quiz'')',owner_id),
      format('select public.finish_ai_request(%L,''success'',null)',gen_random_uuid())] loop
      perform pg_temp.m10_run(operation,role_name,'42501',
        (array['anonymous','verified student','verified instructor'])[actor+1]||' denied: '||split_part(operation,' ',1));
    end loop;
    if actor=1 then
      perform pg_temp.m10_run(format('select save_question(%L,%L::jsonb)',quiz_id,payload),'authenticated','42501','student cannot save');
    end if;
  end loop;
  set local role authenticated; r:=save_question(quiz_id,payload); reset role;
  qid:=(r->>'question_id')::uuid;
  perform pg_temp.m10_check((select not ai_generated from questions where id=qid),'legacy create defaults false');
  set local role authenticated; perform save_question(quiz_id,payload||jsonb_build_object('id',qid)); reset role;
  perform pg_temp.m10_check((select not ai_generated from questions where id=qid),'legacy edit preserves false');
  for t in select unnest(array['multiple_choice','true_false','identification','essay']) loop
    type_payload:=payload||jsonb_build_object('type',t);
    if t='multiple_choice' then type_payload:=type_payload||'{"options":["A","B"],"correct_option_index":0}';
    elsif t='true_false' then type_payload:=type_payload||'{"correct_boolean":false}';
    elsif t='identification' then type_payload:=type_payload||'{"accepted_answers":["A"]}'; end if;
    set local role authenticated; r:=save_question(quiz_id,type_payload); reset role;
    perform pg_temp.m10_check((select not ai_generated from questions where id=(r->>'question_id')::uuid),'legacy create defaults false: '||t);
    for flag in select value from jsonb_array_elements('[false,true]') loop
      set local role authenticated; r:=save_question(quiz_id,type_payload||jsonb_build_object('ai_generated',flag)); reset role;
      perform pg_temp.m10_check((select ai_generated=(flag #>> '{}')::boolean from questions where id=(r->>'question_id')::uuid),'explicit flag create '||flag::text||': '||t);
    end loop;
  end loop;
  set local role authenticated; perform save_question(quiz_id,payload||jsonb_build_object('id',qid,'ai_generated',true)); reset role;
  perform pg_temp.m10_check((select ai_generated from questions where id=qid),'manual question can gain provenance');
  for flag in select value from jsonb_array_elements('[false,true]') loop
    set local role authenticated; perform save_question(quiz_id,payload||jsonb_build_object('id',qid,'ai_generated',flag)); reset role;
    perform pg_temp.m10_check((select ai_generated from questions where id=qid),'true provenance retained on edit '||flag::text);
  end loop;
  set local role authenticated; perform save_question(quiz_id,payload||jsonb_build_object('id',qid)); reset role;
  perform pg_temp.m10_check((select ai_generated from questions where id=qid),'legacy edit preserves true');
  for flag in select value from jsonb_array_elements('[null,"true",0,1,[],{}]') loop
    before_state:=pg_temp.m10_snapshot(quiz_id);
    perform pg_temp.m10_run(format('select save_question(%L,%L::jsonb)',quiz_id,payload||jsonb_build_object('ai_generated',flag)),
      'authenticated','22023','reject nonboolean new '||flag::text);
    perform pg_temp.m10_run(format('select save_question(%L,%L::jsonb)',quiz_id,payload||jsonb_build_object('id',qid,'ai_generated',flag)),
      'authenticated','22023','reject nonboolean edit '||flag::text);
    perform pg_temp.m10_check(pg_temp.m10_snapshot(quiz_id)=before_state,'invalid flag leaves complete snapshot unchanged');
  end loop;
  -- Keep one manual row for a late failure that would otherwise change its flag.
  set local role authenticated; r:=save_question(quiz_id,payload); reset role;
  perform set_config('m10.quiz',quiz_id::text,true);
  perform set_config('m10.question',r->>'question_id',true);
end $$;
create function pg_temp.m10_fail_key() returns trigger language plpgsql as $$
begin raise exception 'M10 injected key failure'; end $$;
create trigger m10_inject_key_failure before insert on public.answer_keys
for each row execute function pg_temp.m10_fail_key();
do $$
declare q uuid:=current_setting('m10.quiz')::uuid; qid uuid:=current_setting('m10.question')::uuid;
  before_state jsonb:=pg_temp.m10_snapshot(q); payload jsonb:=
  '{"type":"multiple_choice","prompt":"M10 late failure","points":3,"position":0,"options":["A","B"],"correct_option_index":0,"ai_generated":true}';
begin
  perform pg_temp.m10_run(format('select save_question(%L,%L::jsonb)',q,payload),'authenticated','P0001','late create failure surfaces');
  perform pg_temp.m10_check(pg_temp.m10_snapshot(q)=before_state,'late create rolls back flag/question/options/totals');
  perform pg_temp.m10_run(format('select save_question(%L,%L::jsonb)',q,payload||jsonb_build_object('id',qid)),'authenticated','P0001','late edit failure surfaces');
  perform pg_temp.m10_check(pg_temp.m10_snapshot(q)=before_state,'late edit restores flag/options/key/totals');
end $$;
drop trigger m10_inject_key_failure on public.answer_keys;
select * from m10_results order by step;
select count(*) filter(where result='PASS') as passed, count(*) filter(where result='FAIL') as failed,
 case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
 coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m10_results;
rollback;
