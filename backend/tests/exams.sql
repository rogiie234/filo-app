-- M8-BE-01. DEV ONLY: fiobwfzmqcffbpixzvbq, SQL Editor, postgres role.
-- Run the WHOLE file after repository migrations through 20261022100000.
-- Any FAIL or uncaught error means failure. On abort, ROLLBACK before rerunning.
-- No real users, secrets, sleeps, trigger disabling or persisted fixtures.
begin;
set local search_path = public;
create temporary table m8_results (
  step integer generated always as identity, test text, result text, detail text
) on commit drop;

create function pg_temp.m8_assert(ok boolean, label text) returns void
language plpgsql as $$ begin
  insert into m8_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end);
end $$;

create function pg_temp.m8_actor(i integer) returns void language plpgsql as $$ begin
  perform set_config('request.jwt.claims',case when i=0 then '{}' else
    jsonb_build_object('sub',current_setting('m8.u'||i),
      'session_id',current_setting('m8.s'||i),'role','authenticated')::text end,true);
end $$;

-- Returns JSON so positive RPC results can be inspected without privileged calls.
-- Expected failures match both SQLSTATE and message; unexpected successes roll back.
create function pg_temp.m8_call(q text, label text, expected text default '00000',
  expected_message text default null) returns jsonb language plpgsql as $$
declare value jsonb; code text:='00000'; msg text; context text;
begin
  begin
    set local role authenticated;
    execute q into value;
    reset role;
    if expected <> '00000' then raise exception 'Unexpected success' using errcode='ZM801'; end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text,context=pg_exception_context;
    reset role;
    if code='ZM801' then code:='00000'; end if;
  end;
  insert into m8_results(test,result,detail) values(label,
    case when code=expected and (expected_message is null or msg=expected_message)
      then 'PASS' else 'FAIL' end,code||coalesce(': '||msg,'')||coalesce(E'\n'||context,''));
  return value;
end $$;

create function pg_temp.m8_privacy(phase text) returns void language plpgsql as $$
declare t text; n bigint; code text; msg text;
begin
  foreach t in array array['questions','question_options','answer_keys','exam_sessions','exam_answers','leave_events'] loop
    execute format('select count(*) from public.%I',t) into n;
    perform pg_temp.m8_assert(n>0,phase||': populated positive control '||t);
    n:=null; code:='00000'; msg:=null;
    begin
      set local role authenticated;
      execute format('select count(*) from public.%I',t) into n;
      reset role;
    exception when others then
      get stacked diagnostics code=returned_sqlstate,msg=message_text;
      reset role;
    end;
    insert into m8_results(test,result,detail) values(phase||': student direct read '||t,
      case when (code='00000' and n=0) or code='42501' then 'PASS' else 'FAIL' end,
      code||coalesce(': '||msg,': rows='||n));
  end loop;
end $$;

do $$
declare signature text; definition text;
begin
  foreach signature in array array['start_exam(uuid)','get_exam(uuid)',
    'save_answer(uuid,uuid,uuid,boolean,text)','get_my_session(uuid)','get_result(uuid)',
    'submit_exam(uuid)','guard_class_content_write()','lock_quiz_content(uuid[])'] loop
    if to_regprocedure('public.'||signature) is null then
      raise exception 'Missing prerequisite public.%: apply repository migrations first',signature;
    end if;
  end loop;
  definition:=pg_get_functiondef('public.save_answer(uuid,uuid,uuid,boolean,text)'::regprocedure);
  if position('Answer must be at most 10000 characters' in definition)=0 then
    raise exception 'Apply 20261022100000_exam_answer_text_limit.sql first';
  end if;
  if position('for update' in lower(pg_get_functiondef('public.start_exam(uuid)'::regprocedure)))=0 then
    raise exception 'Apply the M7 quiz publication/start migration first';
  end if;
end $$;

do $$
declare u uuid; sid uuid; c uuid:=gen_random_uuid(); q uuid; qu uuid; o uuid;
  i integer; j integer; k integer; typ question_type;
begin
  perform pg_temp.m8_actor(0);
  for i in 1..6 loop
    u:=gen_random_uuid(); sid:=gen_random_uuid();
    perform set_config('m8.u'||i,u::text,true);
    perform set_config('m8.s'||i,sid::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(sid,u);
    insert into profiles(id,role,display_name) values(u,
      case when i=1 then 'instructor'::user_role else 'student'::user_role end,'M8 fixture '||i);
    insert into verified_sessions(session_id,user_id) values(sid,u);
  end loop;
  insert into classes(id,owner_id,course,section,school_year)
    values(c,current_setting('m8.u1')::uuid,'M8 fixture','M8','2026-2027');
  perform set_config('m8.class',c::text,true);
  for i in 2..5 loop
    insert into class_members(class_id,student_id,status) values(c,current_setting('m8.u'||i)::uuid,
      case i when 4 then 'pending'::member_status when 5 then 'removed'::member_status else 'active'::member_status end);
  end loop;
  -- Main, foreign, upcoming, closed, exact-close, draft, archived and near-close quizzes.
  for i in 1..8 loop
    q:=gen_random_uuid(); perform set_config('m8.q'||i,q::text,true);
    insert into quizzes(id,class_id,author_id,title,opens_at,closes_at,time_limit_minutes)
      values(q,c,current_setting('m8.u1')::uuid,'M8 fixture '||i,
        case when i=3 then now()+interval '1 hour' else now()-interval '1 hour' end,
        case i when 4 then now()-interval '1 second' when 5 then now()
          when 8 then now()+interval '5 seconds' else now()+interval '2 hours' end,30);
    for j in 1..5 loop
      typ:=case j when 1 then 'multiple_choice'::question_type when 2 then 'true_false'
        when 3 then 'identification' when 4 then 'essay' else 'multiple_choice' end;
      qu:=gen_random_uuid(); perform set_config('m8.qu'||i||'_'||j,qu::text,true);
      insert into questions(id,quiz_id,position,type,prompt,explanation)
        values(qu,q,j,typ,'M8 public prompt '||j,'M8_PRIVATE_EXPLANATION');
      if typ='multiple_choice' then
        for k in 1..3 loop
          o:=gen_random_uuid(); perform set_config('m8.o'||i||'_'||j||'_'||k,o::text,true);
          insert into question_options(id,question_id,position,text) values(o,qu,k,'M8 public option '||k);
        end loop;
        insert into answer_keys(question_id,correct_option_id)
          values(qu,current_setting('m8.o'||i||'_'||j||'_1')::uuid);
      elsif typ='true_false' then
        insert into answer_keys(question_id,correct_boolean) values(qu,true);
      elsif typ='identification' then
        insert into answer_keys(question_id,accepted_answers) values(qu,array['M8_PRIVATE_KEY']);
      end if;
    end loop;
    if i<>6 then update quizzes set status='published',published_at=now() where id=q; end if;
  end loop;
  -- Another student's populated attempt exists before our actor starts.
  sid:=gen_random_uuid(); perform set_config('m8.other_attempt',sid::text,true);
  insert into exam_sessions(id,quiz_id,student_id,deadline_at,question_order,auto_score)
    values(sid,current_setting('m8.q1')::uuid,current_setting('m8.u3')::uuid,
      now()+interval '30 minutes',array[current_setting('m8.qu1_3')::uuid],1);
  insert into exam_answers(session_id,question_id,text_answer)
    values(sid,current_setting('m8.qu1_3')::uuid,'M8_OTHER_STUDENT_ANSWER');
  insert into leave_events(id,session_id,student_id,left_at)
    values(gen_random_uuid(),sid,current_setting('m8.u3')::uuid,now());
end $$;

do $$
declare q uuid:=current_setting('m8.q1')::uuid; sid uuid; r jsonb; again jsonb;
  stored exam_sessions; i integer; j integer; qu uuid; oid uuid; value text;
  before_answer jsonb; delta integer;
begin
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_privacy('before start');
  perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q3')),
    'start before opening','P0001','This quiz has not opened yet');
  for i in 4..5 loop
    perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q'||i)),
      case i when 4 then 'start after closing' else 'start exactly at closing' end,'P0001','This quiz has closed');
  end loop;
  for i in 4..6 loop
    perform pg_temp.m8_actor(i);
    perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',q),
      case i when 4 then 'pending student' when 5 then 'removed student' else 'non-member' end,
      'P0001','Quiz not found');
  end loop;
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q6')),
    'draft quiz refused','P0001','Quiz not found');
  perform pg_temp.m8_actor(0);
  update classes set archived_at=now() where id=current_setting('m8.class')::uuid;
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q7')),
    'archived class refused','P0001','This class is archived');
  perform pg_temp.m8_actor(0);
  update classes set archived_at=null where id=current_setting('m8.class')::uuid;
  perform pg_temp.m8_assert((select count(*)=1 from exam_sessions where quiz_id in
    (select id from quizzes where class_id=current_setting('m8.class')::uuid)),
    'all refused starts create no attempts');
  perform pg_temp.m8_assert(not exists(select 1 from quizzes
    where class_id=current_setting('m8.class')::uuid and locked_at is not null),
    'all refused starts leave quizzes unlocked');
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',q),'normal start');
  sid:=(r->>'id')::uuid;
  if sid is null then
    raise exception 'Normal start failed: %', (select jsonb_agg(to_jsonb(x)) from m8_results x where result='FAIL');
  end if;
  perform set_config('m8.attempt',sid::text,true);
  select * into stored from exam_sessions where id=sid;
  perform pg_temp.m8_assert(stored.deadline_at=now()+interval '30 minutes','normal deadline uses time limit');
  perform pg_temp.m8_assert((select locked_at=now() from quizzes where id=q),'first start locks quiz');
  perform pg_temp.m8_assert(cardinality(stored.question_order)=5 and
    (select count(distinct x)=5 from unnest(stored.question_order) x) and
    (select bool_and(x=any(stored.question_order)) from (select id x from questions where quiz_id=q) a),
    'saved question order is exact permutation');
  for j in select n from generate_series(1,5) n where n in (1,5) loop
    qu:=current_setting('m8.qu1_'||j)::uuid;
    perform pg_temp.m8_assert(jsonb_array_length(stored.option_orders->qu::text)=3 and
      (select count(distinct x)=3 and bool_and(exists(select 1 from question_options o
        where o.id=x::uuid and o.question_id=qu))
        from jsonb_array_elements_text(stored.option_orders->qu::text) a(x)),
      'saved option order is exact permutation MC '||j);
  end loop;
  again:=pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',q),'repeat start');
  perform pg_temp.m8_assert(r=again and (select count(*)=1 from exam_sessions
    where quiz_id=q and student_id=current_setting('m8.u2')::uuid),
    'repeat start preserves attempt deadline and orders');
  r:=pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q8')),'near closing start');
  perform pg_temp.m8_assert((r->>'deadline_at')::timestamptz=now()+interval '5 seconds',
    'near closing deadline capped at close');
  perform pg_temp.m8_privacy('during exam');

  for j in 1..4 loop
    qu:=current_setting('m8.qu1_'||j)::uuid;
    for i in 1..2 loop
      value:=case j when 1 then format('p_option => %L::uuid',current_setting('m8.o1_1_'||i))
        when 2 then 'p_bool => '||case i when 1 then 'true' else 'false' end
        else format('p_text => %L','M8 own answer '||j||' version '||i) end;
      perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,%s))',sid,qu,value),
        'type '||j||case i when 1 then ' valid answer' else ' overwrite' end);
    end loop;
    perform pg_temp.m8_assert((select count(*)=1 and bool_and(case j
      when 1 then option_id=current_setting('m8.o1_1_2')::uuid
      when 2 then bool_answer=false else text_answer='M8 own answer '||j||' version 2' end)
      from exam_answers where session_id=sid and question_id=qu),'type '||j||' last answer wins');
  end loop;
  for j in 1..2 loop
    qu:=current_setting('m8.qu1_1')::uuid;
    select to_jsonb(a) into before_answer from exam_answers a where session_id=sid and question_id=qu;
    oid:=case j when 1 then current_setting('m8.o1_5_1')::uuid else current_setting('m8.o2_1_1')::uuid end;
    perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_option => %L))',sid,qu,oid),
      'foreign question option '||j,'P0001','Invalid option');
    perform pg_temp.m8_assert((select to_jsonb(a)=before_answer from exam_answers a
      where session_id=sid and question_id=qu),'invalid option preserves answer '||j);
  end loop;
  perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_text => ''foreign''))',
    sid,current_setting('m8.qu2_3')),'foreign quiz question refused','P0001','Question not found');
  perform pg_temp.m8_assert(not exists(select 1 from exam_answers where session_id=sid
    and question_id=current_setting('m8.qu2_3')::uuid),'foreign question creates no row');
  for j in 3..4 loop
    qu:=current_setting('m8.qu1_'||j)::uuid;
    perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_text => repeat(''界'',10000)))',sid,qu),
      'type '||j||' accepts 10000 Unicode characters');
    perform pg_temp.m8_assert((select char_length(text_answer)=10000 from exam_answers
      where session_id=sid and question_id=qu),'type '||j||' full 10000 characters saved');
    select to_jsonb(a) into before_answer from exam_answers a where session_id=sid and question_id=qu;
    perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_text => repeat(''界'',10001)))',sid,qu),
      'type '||j||' rejects 10001 characters','22001','Answer must be at most 10000 characters');
    perform pg_temp.m8_assert((select to_jsonb(a)=before_answer from exam_answers a
      where session_id=sid and question_id=qu),'type '||j||' oversized refusal preserves row');
  end loop;
  for j in 1..4 loop
    qu:=current_setting('m8.qu1_'||j)::uuid;
    for i in 1..4 loop
      delta:=case i when 1 then -1 when 2 then 10 when 3 then 15 else 16 end;
      perform pg_temp.m8_actor(0);
      update exam_sessions set deadline_at=now()-make_interval(secs => delta) where id=sid;
      perform pg_temp.m8_actor(2);
      select to_jsonb(a) into before_answer from exam_answers a where session_id=sid and question_id=qu;
      value:=case j when 1 then format('p_option => %L::uuid',current_setting('m8.o1_1_1'))
        when 2 then 'p_bool => true' else format('p_text => %L','M8 clock '||i) end;
      perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,%s))',sid,qu,value),
        'type '||j||' clock delta '||delta,
        case when i=4 then 'P0001' else '00000' end,case when i=4 then 'This attempt is closed' end);
      if i=4 then
        perform pg_temp.m8_assert((select to_jsonb(a)=before_answer from exam_answers a
          where session_id=sid and question_id=qu),'type '||j||' expired refusal preserves row');
      else
        perform pg_temp.m8_assert((select case j
          when 1 then option_id=current_setting('m8.o1_1_1')::uuid
          when 2 then bool_answer=true else text_answer='M8 clock '||i end
          from exam_answers where session_id=sid and question_id=qu),
          'type '||j||' clock write persisted '||delta);
      end if;
    end loop;
  end loop;
  perform pg_temp.m8_actor(0);
  update exam_sessions set deadline_at=now()+interval '30 minutes' where id=sid;
  perform pg_temp.m8_actor(2);
end $$;

do $$
declare sid uuid:=current_setting('m8.attempt')::uuid; q uuid:=current_setting('m8.q1')::uuid;
  r jsonb; again jsonb; saved jsonb; stored exam_sessions; item jsonb; forbidden text;
begin
  select * into stored from exam_sessions where id=sid;
  r:=pg_temp.m8_call(format('select get_exam(%L)',sid),'get own exam');
  again:=pg_temp.m8_call(format('select get_exam(%L)',sid),'get own exam again');
  perform pg_temp.m8_assert(r->'questions'=again->'questions','second get preserves all question and option order');
  perform pg_temp.m8_assert(not exists(select 1 from jsonb_object_keys(r) a(k)
    where k<>all(array['session_id','quiz_id','started_at','deadline_at','server_now','questions','saved_answers'])),
    'exam top-level field allowlist');
  perform pg_temp.m8_assert(not exists(select 1 from jsonb_array_elements(r->'questions') a(v),
    lateral jsonb_object_keys(v) b(k) where k<>all(array['id','type','prompt','points','options'])),
    'question field allowlist excludes any extra correct flags or private data');
  perform pg_temp.m8_assert(not exists(select 1 from jsonb_array_elements(r->'questions') a(v),
    lateral jsonb_array_elements(case when jsonb_typeof(v->'options')='array' then v->'options' else '[]'::jsonb end) b(o),
    lateral jsonb_object_keys(o) c(k) where k<>all(array['id','text'])), 'option field allowlist');
  perform pg_temp.m8_assert(not exists(select 1 from jsonb_array_elements(r->'saved_answers') a(v),
    lateral jsonb_object_keys(v) b(k) where k<>all(array['question_id','option_id','bool_answer','text_answer'])),
    'saved-answer field allowlist');
  perform pg_temp.m8_assert((select array_agg((v->>'id')::uuid order by ord)=stored.question_order
    from jsonb_array_elements(r->'questions') with ordinality a(v,ord)),'get follows saved question order');
  for item in select v from jsonb_array_elements(r->'questions') a(v) where v->>'type'='multiple_choice' loop
    perform pg_temp.m8_assert((select jsonb_agg(v->'id' order by ord)=stored.option_orders->(item->>'id')
      from jsonb_array_elements(item->'options') with ordinality a(v,ord)),
      'get follows saved option order '||(item->>'id'));
  end loop;
  select jsonb_agg(jsonb_build_object('question_id',question_id,'option_id',option_id,
    'bool_answer',bool_answer,'text_answer',text_answer) order by question_id) into saved
    from exam_answers where session_id=sid;
  perform pg_temp.m8_assert((select jsonb_agg(v order by v->>'question_id')=saved
    from jsonb_array_elements(r->'saved_answers') a(v)),'get returns exactly own saved answers');
  foreach forbidden in array array['answer_keys','correct_option_id','correct_boolean','accepted_answers',
    'correct_answer','is_correct','explanation','points_awarded','feedback','graded_by','auto_score',
    'essay_score','total_score','M8_PRIVATE_EXPLANATION','M8_PRIVATE_KEY','M8_OTHER_STUDENT_ANSWER',
    current_setting('m8.u3'),current_setting('m8.other_attempt')] loop
    perform pg_temp.m8_assert(position(lower(forbidden) in lower(r::text))=0,
      'whole exam JSON excludes '||forbidden);
  end loop;
  perform pg_temp.m8_call(format('select get_exam(%L)',gen_random_uuid()),'unknown attempt refused','P0001','Session not found');
  perform pg_temp.m8_call(format('select get_exam(%L)',current_setting('m8.other_attempt')),
    'other student attempt refused','P0001','Session not found');
  perform pg_temp.m8_actor(3);
  perform pg_temp.m8_call(format('select get_exam(%L)',sid),'different student refused','P0001','Session not found');
  perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_bool => true))',sid,current_setting('m8.qu1_2')),
    'different student cannot save','P0001','Session not found');
  perform pg_temp.m8_actor(2);
  -- Non-zero private score ensures an accidental score field is observable.
  perform pg_temp.m8_actor(0);
  update exam_sessions set auto_score=2 where id=sid;
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call(format('select get_my_session(%L)',q),'own unreleased session metadata');
  perform pg_temp.m8_assert(r->>'session_id'=sid::text and not (r ?| array['score','total_score','auto_score','essay_score'])
    and r->'results_released'='false'::jsonb,'metadata hides unreleased score');
  perform pg_temp.m8_call(format('select get_result(%L)',sid),'in progress result hidden','P0001','Results are not available yet');
  perform pg_temp.m8_call(format('select submit_exam(%L)',sid),'submit own attempt');
  perform pg_temp.m8_assert((select status='submitted' and submitted_at is not null from exam_sessions where id=sid),
    'submission persisted');
  perform pg_temp.m8_assert((select results_released_at is null from quizzes where id=q),
    'another open attempt keeps results unreleased');
  perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',q),'submitted start refused','P0001','You have already taken this quiz');
  perform pg_temp.m8_call(format('select get_exam(%L)',sid),'finished exam refused','P0001','This attempt is finished');
  select to_jsonb(a) into saved from exam_answers a where session_id=sid and question_id=current_setting('m8.qu1_2')::uuid;
  perform pg_temp.m8_call(format('select to_jsonb(save_answer(%L,%L,p_bool => false))',sid,current_setting('m8.qu1_2')),
    'submitted attempt cannot save','P0001','This attempt is closed');
  perform pg_temp.m8_assert((select to_jsonb(a)=saved from exam_answers a
    where session_id=sid and question_id=current_setting('m8.qu1_2')::uuid),'submitted refusal preserves answer');
  perform pg_temp.m8_call(format('select get_result(%L)',sid),'submitted unreleased result hidden','P0001','Results are not available yet');
  r:=pg_temp.m8_call(format('select get_my_session(%L)',q),'submitted unreleased metadata');
  perform pg_temp.m8_assert(not (r ?| array['score','total_score','auto_score','essay_score'])
    and r->'results_released'='false'::jsonb,'submitted metadata hides score');
  perform pg_temp.m8_privacy('after submission before release');
  -- Release gating fixture: this does not test release scheduling or essay grading.
  perform pg_temp.m8_actor(0);
  update quizzes set results_released_at=now() where id=q;
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call(format('select get_result(%L)',sid),'own released result allowed');
  perform pg_temp.m8_assert((r->>'score')::integer=(select total_score from exam_sessions where id=sid),
    'released score matches own stored score');
  r:=pg_temp.m8_call(format('select get_my_session(%L)',q),'released metadata');
  perform pg_temp.m8_assert(r ? 'score' and r->'results_released'='true'::jsonb,'metadata exposes score only after release');
  perform pg_temp.m8_privacy('after release');
  perform pg_temp.m8_actor(3);
  perform pg_temp.m8_call(format('select get_result(%L)',sid),'different student cannot read released result','P0001','Session not found');
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_call(format('select get_result(%L)',current_setting('m8.other_attempt')),
    'own actor cannot read another released result','P0001','Session not found');
end $$;

select * from m8_results order by step;
select count(*) filter(where result='PASS') as passed, count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m8_results;
rollback;
