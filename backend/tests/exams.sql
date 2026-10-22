-- M8-BE-01. DEV ONLY: fiobwfzmqcffbpixzvbq, SQL Editor, postgres role.
-- Run the WHOLE file after repository migrations through 20261022120000.
-- Any FAIL or uncaught error means failure. On abort, ROLLBACK before rerunning.
-- No real users, secrets, sleeps, trigger disabling or persisted fixtures.
begin;
set local search_path = public;
-- Inventory non-fixture work before the global worker is exercised. Its effects
-- roll back, but configured external webhooks are outside rollback guarantees.
select id, quiz_id, deadline_at from public.exam_sessions
where status='in_progress' and deadline_at + interval '15 seconds' < now();
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
    'submit_exam(uuid)','guard_class_content_write()','lock_quiz_content(uuid[])',
    'finalize_expired_sessions()','finalize_accessible_exams()'] loop
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
  before_answer jsonb; delta integer; before_quiz_tid tid;
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
  select ctid into before_quiz_tid from quizzes where id=current_setting('m8.q8')::uuid;
  perform pg_temp.m8_actor(3);
  perform pg_temp.m8_call(format('select to_jsonb(start_exam(%L))',current_setting('m8.q8')),
    'second student starts already locked quiz');
  perform pg_temp.m8_assert((select ctid=before_quiz_tid from quizzes where id=current_setting('m8.q8')::uuid),
    'later student start does not rewrite the locked quiz row');
  perform pg_temp.m8_actor(2);
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

-- M8-BE-02 extends the original 178 checks without replacing them.
create function pg_temp.m8b_snapshot(sid uuid) returns jsonb language sql as $$
  select jsonb_build_object('session',(select to_jsonb(s) from exam_sessions s where id=sid),
    'answers',(select jsonb_agg(to_jsonb(a) order by a.question_id) from exam_answers a where session_id=sid));
$$;

create function pg_temp.m8b_grade_check(sid uuid, label text) returns void language plpgsql as $$
begin
  perform pg_temp.m8_assert((select auto_score=18 and essay_score=0 and total_score=18
    and not grading_complete from exam_sessions where id=sid),label||': weighted total 18, essay pending');
  perform pg_temp.m8_assert((select count(*)=3 and bool_and(a.is_correct and a.points_awarded=q.points)
    from exam_answers a join questions q on q.id=a.question_id
    where a.session_id=sid and q.position in (1,3,5)),label||': correct MC/boolean/normalized identification');
  perform pg_temp.m8_assert((select count(*)=4 and bool_and(not a.is_correct and a.points_awarded=0)
    from exam_answers a join questions q on q.id=a.question_id
    where a.session_id=sid and q.position in (2,4,6,9)),label||': incorrect MC/boolean/blank and wrong identification');
  perform pg_temp.m8_assert((select a.is_correct is null and a.points_awarded is null and a.graded_by is null
    from exam_answers a join questions q on q.id=a.question_id where a.session_id=sid and q.position=7),
    label||': essay ungraded');
  perform pg_temp.m8_assert(not exists(select 1 from exam_answers a join questions q on q.id=a.question_id
    where a.session_id=sid and q.position=8),label||': unanswered question adds no points or answer row');
end $$;

create function pg_temp.m8b_leaves(sid uuid, expected integer, label text) returns void language plpgsql as $$
begin
  perform pg_temp.m8_assert((select leave_count=expected and leave_count=
    (select count(*) from leave_events where session_id=sid) from exam_sessions where id=sid),label);
end $$;

do $$
declare q uuid; sid uuid; qu uuid; o uuid; wrong_option uuid; c uuid; owner_id uuid;
  i integer; j integer; typ question_type; pts integer[]:=array[2,3,5,7,11,13,17,19,23];
begin
  perform pg_temp.m8_actor(0);
  -- Separate instructor/class verifies the fallback cannot sweep another owner.
  owner_id:=gen_random_uuid();
  perform set_config('m8.u7',owner_id::text,true);
  perform set_config('m8.s7',gen_random_uuid()::text,true);
  insert into auth.users(id) values(owner_id);
  insert into auth.sessions(id,user_id) values(current_setting('m8.s7')::uuid,owner_id);
  insert into verified_sessions(session_id,user_id) values(current_setting('m8.s7')::uuid,owner_id);
  insert into profiles(id,role,display_name) values(owner_id,'instructor','M8-BE-02 other instructor');
  c:=gen_random_uuid(); perform set_config('m8b.other_class',c::text,true);
  insert into classes(id,owner_id,course,section,school_year) values(c,owner_id,'M8-BE-02 other','M8B','2026-2027');
  insert into class_members(class_id,student_id,status) values(c,current_setting('m8.u3')::uuid,'active');
  for i in 1..8 loop
    q:=gen_random_uuid(); sid:=gen_random_uuid();
    perform set_config('m8b.q'||i,q::text,true); perform set_config('m8b.s'||i,sid::text,true);
    insert into quizzes(id,class_id,author_id,title,opens_at,closes_at)
      values(q,case when i=8 then c else current_setting('m8.class')::uuid end,
        case when i=8 then owner_id else current_setting('m8.u1')::uuid end,
        'M8-BE-02 grading '||i,now()-interval '1 hour',now()+interval '1 hour');
    for j in 1..9 loop
      qu:=gen_random_uuid(); perform set_config('m8b.qu'||i||'_'||j,qu::text,true);
      typ:=case when j in (1,2,8) then 'multiple_choice'::question_type
        when j in (3,4) then 'true_false' when j=7 then 'essay' else 'identification' end;
      insert into questions(id,quiz_id,position,type,prompt,points,explanation)
        values(qu,q,j,typ,'M8B question '||j,pts[j],'M8B_PRIVATE_EXPLANATION');
      if typ='multiple_choice' then
        o:=gen_random_uuid();
        insert into question_options(id,question_id,position,text) values(o,qu,1,'Correct option');
        insert into answer_keys(question_id,correct_option_id) values(qu,o);
        wrong_option:=gen_random_uuid();
        insert into question_options(id,question_id,position,text) values(wrong_option,qu,2,'Wrong option');
        if j=2 then o:=wrong_option; end if;
      elsif typ='true_false' then
        insert into answer_keys(question_id,correct_boolean) values(qu,j=3);
      elsif typ='identification' then
        insert into answer_keys(question_id,accepted_answers) values(qu,array['Green Leaf','SPROUT']);
      end if;
      if j<>8 then
        -- Sessions are inserted below; keep answer values in question settings.
        if typ='multiple_choice' then perform set_config('m8b.option'||i||'_'||j,o::text,true); end if;
      end if;
    end loop;
    update quizzes set status='published',published_at=now(),locked_at=now() where id=q;
    insert into exam_sessions(id,quiz_id,student_id,deadline_at,question_order,option_orders)
      select sid,q,current_setting(case when i in (7,8) then 'm8.u3' else 'm8.u2' end)::uuid,
        now()+interval '30 minutes',array_agg(id order by position),
        (select jsonb_object_agg(x.id::text,(select jsonb_agg(z.id order by z.position)
          from question_options z where z.question_id=x.id)) from questions x
          where x.quiz_id=q and x.type='multiple_choice')
        from questions where quiz_id=q;
    for j in 1..9 loop
      if j=8 then continue; end if;
      qu:=current_setting('m8b.qu'||i||'_'||j)::uuid;
      insert into exam_answers(session_id,question_id,option_id,bool_answer,text_answer)
        values(sid,qu,case when j in (1,2) then current_setting('m8b.option'||i||'_'||j)::uuid end,
          case when j in (3,4) then true end,
          case j when 5 then E' \tGrEeN   LEAF\n ' when 6 then E' \t \n '
            when 7 then 'Essay awaiting human grading' when 9 then 'Wrong identification' end);
    end loop;
  end loop;
end $$;

do $$
declare sid uuid:=current_setting('m8b.s1')::uuid; late_id uuid:=current_setting('m8b.s2')::uuid;
  r jsonb; before_state jsonb; e1 uuid:=gen_random_uuid(); e2 uuid:=gen_random_uuid(); helper text;
  deadline timestamptz; i integer;
begin
  perform pg_temp.m8_actor(2);
  foreach helper in array array['finalize_expired_sessions()','finalize_session(uuid,session_status)',
    'grade_session(uuid)','recalc_session_scores(uuid)','maybe_release_results(uuid)','release_ready_results()',
    'bump_leave_count()'] loop
    perform pg_temp.m8_assert(not has_function_privilege('authenticated','public.'||helper,'EXECUTE'),
      'student cannot execute privileged helper '||helper);
    perform pg_temp.m8_assert(not has_function_privilege('anon','public.'||helper,'EXECUTE'),
      'anonymous cannot execute privileged helper '||helper);
  end loop;
  perform pg_temp.m8_call('select to_jsonb(finalize_expired_sessions())','student worker call refused','42501');
  perform pg_temp.m8b_leaves(sid,0,'leave count begins at zero');
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',e1,sid),'first leave');
  perform pg_temp.m8b_leaves(sid,1,'first event counts once');
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',e1,sid),'duplicate leave retry');
  perform pg_temp.m8b_leaves(sid,1,'duplicate creates no row or increment');
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',e2,sid),'second distinct leave');
  perform pg_temp.m8b_leaves(sid,2,'distinct event counts again');
  perform pg_temp.m8_actor(3);
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',gen_random_uuid(),sid),
    'other student leave refused','P0001','Session not found');
  perform pg_temp.m8b_leaves(sid,2,'foreign refusal preserves count');
  perform pg_temp.m8_actor(0);
  update exam_sessions set deadline_at=now()-interval '60 seconds' where id=sid;
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',gen_random_uuid(),sid),
    'event exactly deadline plus 60 seconds accepted');
  perform pg_temp.m8b_leaves(sid,3,'60-second boundary counts');
  perform pg_temp.m8_actor(0);
  update exam_sessions set deadline_at=now()-interval '61 seconds' where id=sid;
  perform pg_temp.m8_actor(2);
  perform pg_temp.m8_call(format('select to_jsonb(log_leave(%L,%L,now()))',gen_random_uuid(),sid),
    'event after deadline plus minute ignored');
  perform pg_temp.m8b_leaves(sid,3,'late event creates no row or count');
  perform pg_temp.m8_actor(0);
  update exam_sessions set deadline_at=now()+interval '30 minutes' where id=sid;
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call(format('select submit_exam(%L)',sid),'M8B normal submission');
  perform pg_temp.m8_assert(r->>'status'='submitted' and (r->>'submitted_at')::timestamptz=now(),
    'normal submission status and timestamp');
  perform pg_temp.m8_assert(not exists(select 1 from jsonb_object_keys(r) a(k)
    where k<>all(array['status','submitted_at'])),'submission response exposes no score');
  perform pg_temp.m8b_grade_check(sid,'normal submit grading');
  before_state:=pg_temp.m8b_snapshot(sid);
  perform pg_temp.m8_call(format('select submit_exam(%L)',sid),'repeat normal submission');
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(sid)=before_state,'repeat normal submit changes nothing');
  perform pg_temp.m8_actor(3);
  perform pg_temp.m8_call(format('select submit_exam(%L)',sid),'other student submit refused','P0001','Session not found');
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(sid)=before_state,'foreign submit leaves state unchanged');
  perform pg_temp.m8_actor(0);
  update exam_sessions set deadline_at=now()-interval '1 second' where id=late_id returning deadline_at into deadline;
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call(format('select submit_exam(%L)',late_id),'submit after deadline within grace');
  perform pg_temp.m8_assert(r->>'status'='auto_submitted' and (r->>'submitted_at')::timestamptz=deadline,
    'late submission auto status and deadline timestamp');
  perform pg_temp.m8b_grade_check(late_id,'late submit grading');
  before_state:=pg_temp.m8b_snapshot(late_id);
  perform pg_temp.m8_call(format('select submit_exam(%L)',late_id),'repeat late submission');
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(late_id)=before_state,'repeat late submit changes nothing');
  for i in 1..2 loop
    r:=pg_temp.m8_call(format('select get_my_session(%L)',current_setting('m8b.q'||i)),
      'M8B unreleased metadata '||i);
    perform pg_temp.m8_assert(r->'results_released'='false'::jsonb and
      not (r ?| array['score','auto_score','essay_score','total_score','percent']),
      'M8B unreleased metadata hides score '||i);
    perform pg_temp.m8_call(format('select get_result(%L)',current_setting('m8b.s'||i)),
      'M8B unreleased result refused '||i,'P0001','Results are not available yet');
    perform pg_temp.m8_call(format('select get_exam(%L)',current_setting('m8b.s'||i)),
      'M8B finished exam cannot expose grading '||i,'P0001','This attempt is finished');
  end loop;
  perform pg_temp.m8_privacy('M8B graded but unreleased');
end $$;

do $$
declare i integer; sid uuid; before_state jsonb; unrelated jsonb; r jsonb;
begin
  perform pg_temp.m8_actor(0);
  select jsonb_agg(jsonb_build_object('id',s.id,'quiz_id',s.quiz_id,'deadline_at',s.deadline_at)) into unrelated
    from exam_sessions s join quizzes q on q.id=s.quiz_id
    where s.status='in_progress' and s.deadline_at + interval '15 seconds' < now()
      and q.class_id not in (current_setting('m8.class')::uuid,current_setting('m8b.other_class')::uuid);
  if unrelated is not null then
    raise exception 'Global worker would touch unrelated expired DEV attempts: %. ROLLBACK and resolve those separately before rerunning.',unrelated;
  end if;
  for i in 3..8 loop
    update exam_sessions set deadline_at=now()-make_interval(secs => case i when 4 then 10 when 5 then 15 else 16 end)
      where id=current_setting('m8b.s'||i)::uuid;
  end loop;
  before_state:=pg_temp.m8b_snapshot(current_setting('m8b.s4')::uuid);
  perform finalize_expired_sessions();
  for i in select n from generate_series(3,8) n where n not in (4,5) loop
    sid:=current_setting('m8b.s'||i)::uuid;
    perform pg_temp.m8_assert((select status='auto_submitted' and submitted_at=deadline_at from exam_sessions where id=sid),
      'worker finalizes expired session '||i);
    perform pg_temp.m8b_grade_check(sid,'worker grading '||i);
  end loop;
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(current_setting('m8b.s4')::uuid)=before_state,
    'worker leaves session inside grace unchanged');
  perform pg_temp.m8_assert((select status='in_progress' and submitted_at is null and auto_score=0
    from exam_sessions where id=current_setting('m8b.s5')::uuid),'worker leaves exact 15-second boundary alone');
  before_state:=pg_temp.m8b_snapshot(current_setting('m8b.s3')::uuid);
  perform finalize_expired_sessions();
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(current_setting('m8b.s3')::uuid)=before_state,
    'repeat worker preserves finalized timestamps answers and scores');
  -- A ready quiz must also release on reopen when no new expiry is needed.
  update exam_answers set points_awarded=0 where session_id=current_setting('m8b.s3')::uuid
    and question_id=current_setting('m8b.qu3_7')::uuid;
  perform recalc_session_scores(current_setting('m8b.s3')::uuid);
  update quizzes set closes_at=now() where id=current_setting('m8b.q3')::uuid;
  perform pg_temp.m8_assert((select results_released_at is null from quizzes
    where id=current_setting('m8b.q3')::uuid),'ready fallback quiz starts unreleased');
  -- Reset only fallback fixtures; setup is privileged, calls below are authenticated.
  for i in 6..8 loop
    update exam_sessions set status='in_progress',submitted_at=null,auto_score=0,essay_score=0 where id=current_setting('m8b.s'||i)::uuid;
    update exam_answers set is_correct=null,points_awarded=null where session_id=current_setting('m8b.s'||i)::uuid;
  end loop;
  perform pg_temp.m8_actor(6);
  perform pg_temp.m8_call('select to_jsonb(finalize_accessible_exams())','non-member fallback returns no private data');
  perform pg_temp.m8_assert((select count(*)=3 from exam_sessions where id in
    (current_setting('m8b.s6')::uuid,current_setting('m8b.s7')::uuid,current_setting('m8b.s8')::uuid)
    and status='in_progress'),'unrelated user cannot finalize other attempts');
  perform pg_temp.m8_assert((select results_released_at is null from quizzes
    where id=current_setting('m8b.q3')::uuid),'unrelated user cannot release another class result');
  perform pg_temp.m8_actor(2);
  r:=pg_temp.m8_call('select to_jsonb(finalize_accessible_exams())','student app-open fallback');
  perform pg_temp.m8_assert(r is null or r in ('null'::jsonb,'""'::jsonb),
    'fallback returns no score or session data');
  perform pg_temp.m8b_grade_check(current_setting('m8b.s6')::uuid,'student fallback grading');
  perform pg_temp.m8_assert((select status='auto_submitted' from exam_sessions where id=current_setting('m8b.s6')::uuid),
    'student fallback finalizes own expired attempt');
  perform pg_temp.m8_assert((select results_released_at=now() from quizzes
    where id=current_setting('m8b.q3')::uuid),'fallback releases an already-finalized ready quiz');
  perform pg_temp.m8_assert((select count(*)=2 from exam_sessions where id in
    (current_setting('m8b.s7')::uuid,current_setting('m8b.s8')::uuid) and status='in_progress'),
    'student fallback leaves peer and foreign class alone');
  perform pg_temp.m8_actor(1);
  perform pg_temp.m8_call('select to_jsonb(finalize_accessible_exams())','instructor app-open fallback');
  perform pg_temp.m8_assert((select status='auto_submitted' from exam_sessions where id=current_setting('m8b.s7')::uuid),
    'instructor fallback finalizes owned-class attempt');
  perform pg_temp.m8_assert((select status='in_progress' from exam_sessions where id=current_setting('m8b.s8')::uuid),
    'instructor fallback leaves another owner alone');
  before_state:=pg_temp.m8b_snapshot(current_setting('m8b.s7')::uuid);
  perform pg_temp.m8_call('select to_jsonb(finalize_accessible_exams())','repeat fallback');
  perform pg_temp.m8_assert(pg_temp.m8b_snapshot(current_setting('m8b.s7')::uuid)=before_state,'fallback is idempotent');
  perform pg_temp.m8_actor(0);
  delete from verified_sessions where user_id=current_setting('m8.u6')::uuid;
  perform pg_temp.m8_actor(6);
  perform pg_temp.m8_call('select to_jsonb(finalize_accessible_exams())','unverified fallback refused','42501','OTP verification required');
  perform pg_temp.m8_actor(0);
end $$;

select * from m8_results order by step;
select count(*) filter(where result='PASS') as passed, count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m8_results;
rollback;
