-- M9-BE-01 / M9-BE-02 / M9-BE-03. DEV ONLY: fiobwfzmqcffbpixzvbq, SQL Editor, postgres role.
-- Run the WHOLE file after repository migrations through 20261024110000.
-- Any FAIL or uncaught error means failure. On abort run ROLLBACK separately.
-- Synthetic rollback fixtures; guarded global worker; no trigger disabling or committed data.
begin;
set local search_path = public;
select set_config('request.jwt.claims','{}',true);
create temporary table m9_results (
  step integer generated always as identity, test text, result text, detail text
) on commit drop;

create function pg_temp.m9_assert(ok boolean, label text) returns void language plpgsql as $$
begin
  insert into m9_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end);
end $$;

create function pg_temp.m9_id(key text) returns uuid language sql as $$
  select current_setting('m9.'||key)::uuid
$$;

create function pg_temp.m9_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',pg_temp.m9_id('u'||i),'session_id',pg_temp.m9_id('auth'||i),
    'role','authenticated')::text,true);
end $$;

-- No SECURITY DEFINER here: the actual call/read must use authenticated RLS.
-- Failed expectations roll back the call's subtransaction, including unexpected success.
create function pg_temp.m9_call(query text, label text, expected text default '00000',
  expected_message text default null) returns jsonb language plpgsql as $$
declare value jsonb; code text:='00000'; msg text; context text;
begin
  begin
    set local role authenticated;
    execute query into value;
    reset role;
    if expected<>'00000' then raise exception 'Unexpected success' using errcode='ZM901'; end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text,context=pg_exception_context;
    reset role;
    if code='ZM901' then code:='00000'; end if;
  end;
  insert into m9_results(test,result,detail) values(label,
    case when code=expected and (expected_message is null or msg=expected_message)
      then 'PASS' else 'FAIL' end,code||coalesce(': '||msg,'')||coalesce(E'\n'||context,''));
  return value;
end $$;

-- Compare stored totals independently against fixture expectations after every valid grade.
create function pg_temp.m9_grade(answer_key text, points integer, p_feedback text,
  essay integer, complete boolean, label text) returns void language plpgsql as $$
begin
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(public.grade_essay(%L,%s,%L))',
    pg_temp.m9_id(answer_key),points,p_feedback),label||': call');
  perform pg_temp.m9_assert((select points_awarded=points and a.feedback is not distinct from left(p_feedback,2000)
      and graded_by=pg_temp.m9_id('u1') and is_correct is null
    from exam_answers a where id=pg_temp.m9_id(answer_key)),label||': saved answer/feedback/grader');
  perform pg_temp.m9_assert((select essay_score=essay and auto_score=6 and total_score=6+essay
      and grading_complete=complete from exam_sessions where id=pg_temp.m9_id('s1')),
    label||': essay/auto/total/completion');
end $$;

create function pg_temp.m9_privacy(phase text) returns void language plpgsql as $$
declare t text; value jsonb; populated boolean;
begin
  perform pg_temp.m9_actor(3);
  foreach t in array array['exam_sessions','exam_answers','second_chances','questions','question_options','answer_keys'] loop
    execute format('select count(*)>0 from public.%I',t) into populated;
    perform pg_temp.m9_assert(populated,phase||': populated '||t);
    value:=pg_temp.m9_call(format('select to_jsonb(count(*)) from public.%I',t),phase||': student query '||t);
    perform pg_temp.m9_assert(value='0'::jsonb,phase||': student sees zero '||t);
  end loop;
end $$;

-- Two instructor-owned classes; three submitted students, one nonparticipant,
-- one in-progress student, and a voided historical attempt for the nonparticipant.
do $$
declare i integer; j integer; u uuid; a uuid; c uuid; q uuid; qu uuid; opt uuid;
  sid uuid; aid uuid; typ question_type; order_ids uuid[];
begin
  for i in 1..7 loop
    u:=gen_random_uuid(); a:=gen_random_uuid();
    perform set_config('m9.u'||i,u::text,true);
    perform set_config('m9.auth'||i,a::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(a,u);
    insert into profiles(id,role,display_name) values(u,
      case when i<=2 then 'instructor'::user_role else 'student'::user_role end,'M9 fixture '||i);
    insert into verified_sessions(session_id,user_id) values(a,u);
  end loop;
  for i in 1..2 loop
    c:=gen_random_uuid(); q:=gen_random_uuid();
    perform set_config('m9.c'||i,c::text,true); perform set_config('m9.q'||i,q::text,true);
    insert into classes(id,owner_id,course,section,school_year)
      values(c,pg_temp.m9_id('u'||i),'M9 fixture','Results '||i,'2026-2027');
    for j in 3..7 loop
      insert into class_members(class_id,student_id,status) values(c,pg_temp.m9_id('u'||j),'active');
    end loop;
    insert into quizzes(id,class_id,author_id,title,opens_at,closes_at,passing_percent,show_correct_answers)
      values(q,c,pg_temp.m9_id('u'||i),'M9 results fixture '||i,
        now()-interval '1 hour',now()+interval '2 hours',60,i=1);
    order_ids:='{}';
    for j in 1..8 loop
      typ:=case j when 1 then 'multiple_choice'::question_type when 2 then 'true_false'
        when 3 then 'identification' else 'essay' end;
      qu:=gen_random_uuid(); perform set_config('m9.qu'||i||'_'||j,qu::text,true);
      order_ids:=array_prepend(qu,order_ids);
      insert into questions(id,quiz_id,position,type,prompt,points,explanation)
        values(qu,q,j,typ,'M9 question '||j,2,'M9 explanation '||j);
      if j=1 then
        opt:=gen_random_uuid(); perform set_config('m9.opt'||i,opt::text,true);
        insert into question_options(id,question_id,position,text) values(opt,qu,1,'M9 correct choice');
        insert into question_options(question_id,position,text) values(qu,2,'M9 wrong choice');
        insert into answer_keys(question_id,correct_option_id) values(qu,opt);
      elsif j=2 then insert into answer_keys(question_id,correct_boolean) values(qu,true);
      elsif j=3 then insert into answer_keys(question_id,accepted_answers) values(qu,array['M9 key']);
      end if;
    end loop;
    update quizzes set status='published',published_at=now() where id=q;
    for j in 1..5 loop
      sid:=gen_random_uuid(); perform set_config('m9.s'||i||'_'||j,sid::text,true);
      if i=1 then perform set_config('m9.s'||j,sid::text,true); end if;
      insert into exam_sessions(id,quiz_id,student_id,status,deadline_at,submitted_at,question_order)
        values(sid,q,pg_temp.m9_id('u'||(j+2)),
          case j when 2 then 'auto_submitted'::session_status when 4 then 'voided'
            when 5 then 'in_progress' else 'submitted' end,
          now()+interval '30 minutes',case when j<=3 then now() end,order_ids);
      if j in (1,5) then
        insert into exam_answers(session_id,question_id,option_id,bool_answer,text_answer)
          select sid,pg_temp.m9_id('qu'||i||'_'||n),
            case when n=1 then pg_temp.m9_id('opt'||i) end,
            case when n=2 then true end,
            case n when 3 then 'M9 key' when 4 then 'First essay' when 5 then 'Second essay'
              when 6 then '' when 7 then '   ' end from generate_series(1,7) n;
      end if;
      perform grade_session(sid);
    end loop;
    insert into second_chances(quiz_id,student_id,previous_session_id,reason,granted_by)
      values(q,pg_temp.m9_id('u6'),pg_temp.m9_id('s'||i||'_4'),'M9 fixture retry reason',pg_temp.m9_id('u'||i));
  end loop;
  select id into aid from exam_answers where session_id=pg_temp.m9_id('s1') and question_id=pg_temp.m9_id('qu1_4');
  perform set_config('m9.a1',aid::text,true);
  select id into aid from exam_answers where session_id=pg_temp.m9_id('s1') and question_id=pg_temp.m9_id('qu1_5');
  perform set_config('m9.a2',aid::text,true);
end $$;

select pg_temp.m9_privacy('before release');

do $$
declare answer_id uuid; snapshot jsonb; after_snapshot jsonb;
  row record; r jsonb;
begin
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',pg_temp.m9_id('q1')),'unreleased metadata');
  perform pg_temp.m9_assert(not (r ?| array['score','total_score','essay_score','auto_score'])
    and r->'results_released'='false'::jsonb,'metadata omits all unreleased scores');
  perform pg_temp.m9_call(format('select get_result(%L)',pg_temp.m9_id('s1')),
    'unreleased result refused','P0001','Results are not available yet');
  perform pg_temp.m9_actor(6);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',pg_temp.m9_id('q1')),'no current attempt metadata');
  perform pg_temp.m9_assert(r is null,'voided-only student gets no current session');

  -- Each rejection also checks complete answer and session snapshots unchanged.
  for row in select * from (values
    (1,4,-1,'Points must be between 0 and 2','negative score'),
    (1,4,3,'Points must be between 0 and 2','above maximum'),
    (1,1,1,'Only essay answers are graded by hand','non-essay'),
    (2,4,1,'Not allowed','other instructor'),
    (3,4,1,'Not allowed','student caller'),
    (1,4,1,'This attempt is not submitted yet','in-progress attempt')
  ) v(actor,question_no,points,message,label) loop
    select id into answer_id from exam_answers where session_id=pg_temp.m9_id(
      case when row.label='in-progress attempt' then 's5' else 's1' end)
      and question_id=pg_temp.m9_id('qu1_'||row.question_no);
    select jsonb_build_object('answer',to_jsonb(a),'session',to_jsonb(s)) into snapshot
      from exam_answers a join exam_sessions s on s.id=a.session_id where a.id=answer_id;
    perform pg_temp.m9_actor(row.actor);
    perform pg_temp.m9_call(format('select to_jsonb(grade_essay(%L,%s,%L))',answer_id,row.points,'Rejected feedback'),
      row.label,'P0001',row.message);
    select jsonb_build_object('answer',to_jsonb(a),'session',to_jsonb(s)) into after_snapshot
      from exam_answers a join exam_sessions s on s.id=a.session_id where a.id=answer_id;
    perform pg_temp.m9_assert(snapshot=after_snapshot,row.label||': no stored changes');
  end loop;
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',pg_temp.m9_id('q1')),
    'release while attempt in progress','P0001','Some students are still taking this quiz');
  update exam_sessions set status='voided' where id=pg_temp.m9_id('s5');
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',pg_temp.m9_id('q1')),
    'release with unfinished essays','P0001','Grade all essay answers first');
  perform pg_temp.m9_assert((select results_released_at is null from quizzes where id=pg_temp.m9_id('q1'))
    and not exists(select 1 from notifications where target_id=pg_temp.m9_id('q1')),
    'refused release changes neither timestamp nor inbox');
end $$;

select pg_temp.m9_grade('a1',1,repeat('x',2000),1,false,'valid partial score and 2000 feedback');
select pg_temp.m9_grade('a1',0,null,0,false,'zero and clear feedback');
select pg_temp.m9_grade('a1',2,repeat('é',2001),2,false,'full marks and oversized Unicode feedback truncation');
select pg_temp.m9_grade('a2',1,'M9 essay feedback',3,true,'last answered essay completes grading');
select pg_temp.m9_grade('a1',1,'M9 revised feedback',2,true,'regrade replaces prior points');

do $$
declare i integer; r jsonb; review jsonb; item jsonb; order_ids uuid[]; got_ids uuid[]; n integer;
  q uuid:=pg_temp.m9_id('q1'); sid uuid:=pg_temp.m9_id('s1');
begin
  perform pg_temp.m9_assert((select grading_complete and essay_score=0 from exam_sessions
    where id=pg_temp.m9_id('s2')),'no answer rows do not block completion');
  perform pg_temp.m9_assert((select count(*)=2 and bool_and(points_awarded is null) from exam_answers
    where session_id=sid and question_id in(pg_temp.m9_id('qu1_6'),pg_temp.m9_id('qu1_7')))
    and not exists(select 1 from exam_answers where session_id=sid and question_id=pg_temp.m9_id('qu1_8')),
    'empty/whitespace/missing essays remain ungraded without blocking');
  perform pg_temp.m9_assert((select results_released_at is null from quizzes where id=q),
    'nonparticipant keeps automatic release pending before close');
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'fully graded unreleased metadata');
  perform pg_temp.m9_assert(not (r ?| array['score','total_score','essay_score','auto_score'])
    and r->'results_released'='false'::jsonb,'completed grading does not expose unreleased score');
  perform pg_temp.m9_call(format('select get_result(%L)',sid),
    'fully graded result still refused before release','P0001','Results are not available yet');
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),'manual release');
  perform pg_temp.m9_assert((select results_released_at is not null and closes_at<=now() from quizzes where id=q),
    'manual release closes and timestamps quiz');
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),'repeat release');
  perform pg_temp.m9_assert((select count(*)=3 from notifications where target_id=q and type='results_released')
    and (select count(distinct recipient_id)=3 from notifications where target_id=q and type='results_released')
    and not exists(select 1 from notifications where target_id=q and recipient_id in(pg_temp.m9_id('u6'),pg_temp.m9_id('u7'))),
    'one inbox row each for submitted and auto-submitted; no voided/nonparticipant rows');
  for i in 3..5 loop
    perform pg_temp.m9_assert((select count(*)=1 from notifications where target_id=q and type='results_released'
      and recipient_id=pg_temp.m9_id('u'||i) and title='Results available' and target_type='quiz'),
      'submitted student '||i||': exactly one results inbox row');
  end loop;
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'released metadata');
  perform pg_temp.m9_assert(r->'score'='8'::jsonb and r->'results_released'='true'::jsonb,'metadata includes released score');
  r:=pg_temp.m9_call(format('select get_result(%L)',sid),'released result with threshold');
  perform pg_temp.m9_assert(r->'score'='8'::jsonb and r->'total_points'='16'::jsonb
    and r->'percent'='50'::jsonb and r->'passed'='false'::jsonb,'8/16 = 50 percent below 60 threshold');
  review:=r->'review';
  select question_order into order_ids from exam_sessions where id=sid;
  select array_agg((x->>'question_id')::uuid order by ord) into got_ids
    from jsonb_array_elements(review) with ordinality v(x,ord);
  perform pg_temp.m9_assert(got_ids=order_ids and jsonb_array_length(review)=8,'review follows saved reverse student order');
  for n in 1..8 loop
    select x into item from jsonb_array_elements(review) x where x->>'question_id'=pg_temp.m9_id('qu1_'||n)::text;
    perform pg_temp.m9_assert(item->>'explanation'='M9 explanation '||n and item->'points'='2'::jsonb,
      'review question '||n||': explanation and maximum');
    if n=1 then
      perform pg_temp.m9_assert(item->>'your_answer'='M9 correct choice' and item->>'correct_answer'='M9 correct choice'
        and item->'points_awarded'='2'::jsonb,'MC answer/key/points');
    elsif n=2 then
      perform pg_temp.m9_assert(item->'your_answer'='true'::jsonb and item->'correct_answer'='true'::jsonb
        and item->'points_awarded'='2'::jsonb,'boolean answer/key/points');
    elsif n=3 then
      perform pg_temp.m9_assert(item->>'your_answer'='M9 key' and item->'correct_answer'='["M9 key"]'::jsonb
        and item->'points_awarded'='2'::jsonb,'identification answer/accepted keys/points');
    else
      perform pg_temp.m9_assert(item->'correct_answer'='null'::jsonb,'essay '||n||': no correct answer');
      if n in (4,5) then
        perform pg_temp.m9_assert(item->>'your_answer'=case n when 4 then 'First essay' else 'Second essay' end
          and item->'points_awarded'='1'::jsonb and item->>'feedback'=case n when 4 then 'M9 revised feedback' else 'M9 essay feedback' end,
          'essay '||n||': student answer/awarded points/feedback');
      end if;
    end if;
  end loop;
  perform pg_temp.m9_call(format('select get_result(%L)',pg_temp.m9_id('s2')),'peer result refused','P0001','Session not found');
  -- Privileged fixture variations only: real calls below still use the student role.
  update quizzes set passing_percent=50 where id=q;
  r:=pg_temp.m9_call(format('select get_result(%L)',sid),'exact passing threshold');
  perform pg_temp.m9_assert(r->'score'='8'::jsonb and r->'total_points'='16'::jsonb
    and r->'percent'='50'::jsonb and r->'passed'='true'::jsonb,'exact percentage passes');
  update quizzes set passing_percent=49 where id=q;
  r:=pg_temp.m9_call(format('select get_result(%L)',sid),'above passing threshold');
  perform pg_temp.m9_assert(r->'score'='8'::jsonb and r->'total_points'='16'::jsonb
    and r->'percent'='50'::jsonb and r->'passed'='true'::jsonb,'above threshold passes');
  update quizzes set passing_percent=null,show_correct_answers=false where id=q;
  r:=pg_temp.m9_call(format('select get_result(%L)',sid),'no threshold and review disabled');
  perform pg_temp.m9_assert(r->'score'='8'::jsonb and r->'total_points'='16'::jsonb and r->'percent'='50'::jsonb
    and r->'passed'='null'::jsonb and r->'review'='null'::jsonb,'no threshold has null passed; disabled review has no answers/feedback');
  -- 7/16 exercises actual whole-number rounding rather than an exact integer ratio.
  perform pg_temp.m9_grade('a1',0,'M9 rounding',1,true,'rounding fixture grade');
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select get_result(%L)',sid),'rounded percentage');
  perform pg_temp.m9_assert(r->'score'='7'::jsonb and r->'total_points'='16'::jsonb and r->'percent'='44'::jsonb
    and r->'passed'='null'::jsonb,'7/16 rounds to 44 percent without threshold');
  perform pg_temp.m9_actor(7);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'student with only voided attempt');
  perform pg_temp.m9_assert(r is null,'no non-voided attempt returns null after release');
  -- Truly no attempt, rather than only voided history.
  delete from exam_sessions where id=pg_temp.m9_id('s5');
  r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'student with no attempt');
  perform pg_temp.m9_assert(r is null,'no attempt returns null');
end $$;

select pg_temp.m9_privacy('after release');

-- The second class also proves grade_essay triggers automatic release after close,
-- including scoring an auto-submitted attempt. No global cron worker is invoked.
do $$
declare q uuid:=pg_temp.m9_id('q2'); sid uuid:=pg_temp.m9_id('s2_1'); aid uuid; n integer;
begin
  update exam_sessions set status='auto_submitted' where id=sid;
  update exam_sessions set status='voided' where id=pg_temp.m9_id('s2_5');
  update quizzes set closes_at=now() where id=q;
  perform pg_temp.m9_actor(2);
  for n in 4..5 loop
    select id into aid from exam_answers where session_id=sid and question_id=pg_temp.m9_id('qu2_'||n);
    perform pg_temp.m9_call(format('select to_jsonb(grade_essay(%L,2,%L))',aid,'M9 automatic release'),
      'auto-submitted grade '||n);
    perform pg_temp.m9_assert((select points_awarded=2 and feedback='M9 automatic release'
      and graded_by=pg_temp.m9_id('u2') from exam_answers where id=aid),'auto-submitted saved grade '||n);
    perform pg_temp.m9_assert((select auto_score=6 and essay_score=(n-3)*2 and total_score=6+(n-3)*2
      and grading_complete=(n=5) from exam_sessions where id=sid),'auto-submitted totals/completion '||n);
    perform pg_temp.m9_assert((select case when n=5 then results_released_at=now() else results_released_at is null end from quizzes where id=q),
      'automatic release only after last grade '||n);
  end loop;
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),'manual release after automatic release');
  perform pg_temp.m9_assert((select count(*)=3 and count(distinct recipient_id)=3 from notifications
    where target_id=q and type='results_released') and not exists(select 1 from notifications
    where target_id=q and recipient_id in(pg_temp.m9_id('u6'),pg_temp.m9_id('u7'))),
    'automatic then manual release has one inbox row per submitted student only');
end $$;

do $$
declare actor integer; owned integer; t text; filter text; r jsonb; expected bigint; fixture_sessions uuid[];
begin
  for actor in 1..2 loop
    perform pg_temp.m9_actor(actor);
    for owned in 1..2 loop
      select array_agg(id) into fixture_sessions from exam_sessions where quiz_id=pg_temp.m9_id('q'||owned);
      foreach t in array array['exam_sessions','exam_answers','second_chances'] loop
        -- Literal IDs avoid a session-policy denial masking a leaking answer policy.
        filter:=case when t='exam_answers' then format('session_id=any(%L::uuid[])',fixture_sessions)
          else format('quiz_id=%L',pg_temp.m9_id('q'||owned)) end;
        execute format('select count(*) from public.%I where %s',t,filter) into expected;
        perform pg_temp.m9_assert(expected>0,'populated instructor control '||actor||'/'||owned||' '||t);
        r:=pg_temp.m9_call(format('select to_jsonb(count(*)) from public.%I where %s',t,filter),
          'instructor '||actor||' class '||owned||' read '||t);
        perform pg_temp.m9_assert(r=to_jsonb(case when actor=owned then expected else 0::bigint end),
          'instructor '||actor||' class '||owned||' exact visible count '||t);
      end loop;
    end loop;
  end loop;
end $$;


-- M9-BE-02: independent release/retake fixtures, sharing verified identities only.
create function pg_temp.m9_rule_quiz(label text) returns uuid language plpgsql as $$
declare c uuid:=gen_random_uuid(); q uuid:=gen_random_uuid(); qu uuid:=gen_random_uuid();
  previous_claims text:=current_setting('request.jwt.claims',true);
begin
  -- Content guards check JWT ownership even during privileged fixture setup.
  perform pg_temp.m9_actor(1);
  insert into classes(id,owner_id,course,section,school_year)
    values(c,pg_temp.m9_id('u1'),'M9-BE-02 fixture',label,'2026-2027');
  insert into class_members(class_id,student_id,status) values
    (c,pg_temp.m9_id('u3'),'active'),(c,pg_temp.m9_id('u4'),'pending'),
    (c,pg_temp.m9_id('u5'),'removed'),(c,pg_temp.m9_id('u6'),'active');
  insert into quizzes(id,class_id,author_id,title,opens_at,closes_at,time_limit_minutes)
    values(q,c,pg_temp.m9_id('u1'),label,now()-interval '1 hour',now()+interval '2 hours',30);
  insert into questions(id,quiz_id,position,type,prompt,points) values(qu,q,1,'essay','Explain',2);
  update quizzes set status='published',published_at=now() where id=q;
  perform set_config('request.jwt.claims',coalesce(previous_claims,'{}'),true);
  return q;
end $$;

create function pg_temp.m9_rule_attempt(q uuid, actor integer, state session_status,
  complete boolean default true) returns uuid language plpgsql as $$
declare sid uuid:=gen_random_uuid(); qu uuid;
begin
  select id into qu from questions where quiz_id=q;
  insert into exam_sessions(id,quiz_id,student_id,status,deadline_at,submitted_at,question_order,grading_complete)
    values(sid,q,pg_temp.m9_id('u'||actor),state,now()+interval '5 minutes',
      case when state in ('submitted','auto_submitted') then now() end,array[qu],complete);
  insert into exam_answers(session_id,question_id,text_answer,points_awarded,graded_by)
    values(sid,qu,'Original essay',case when complete then 2 end,
      case when complete then pg_temp.m9_id('u1') end);
  return sid;
end $$;

create function pg_temp.m9_rule_snapshot(q uuid) returns jsonb language sql as $$
  select jsonb_build_object('quiz',(select to_jsonb(z) from quizzes z where id=q),
    'sessions',(select jsonb_agg(to_jsonb(s) order by id) from exam_sessions s where quiz_id=q),
    'answers',(select jsonb_agg(to_jsonb(a) order by a.id) from exam_answers a
      join exam_sessions s on s.id=a.session_id where s.quiz_id=q),
    'audit',(select jsonb_agg(to_jsonb(c) order by id) from second_chances c where quiz_id=q),
    'inbox',(select jsonb_agg(to_jsonb(n) order by id) from notifications n where target_id=q))
$$;

-- Automatic release: open-roster completion, closed nonparticipants, and voided history.
do $$
declare q uuid; sid uuid; before_state jsonb; released boolean;
begin
  perform pg_temp.m9_actor(2);
  q:=pg_temp.m9_rule_quiz('M9B automatic active roster');
  perform pg_temp.m9_assert(auth.uid()=pg_temp.m9_id('u2'),
    'M9B fixture construction restores foreign instructor claims');
  sid:=pg_temp.m9_rule_attempt(q,3,'submitted');
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released and (select results_released_at is null from quizzes where id=q),
    'M9B open quiz active not-started blocks release');
  perform pg_temp.m9_rule_attempt(q,6,'voided');
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released and (select results_released_at is null from quizzes where id=q),
    'M9B voided attempt counts as not submitted');
  perform pg_temp.m9_rule_attempt(q,6,'auto_submitted');
  before_state:=pg_temp.m9_rule_snapshot(q);
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released and before_state=pg_temp.m9_rule_snapshot(q),
    'M9C all submitted remains unreleased during wait without inbox changes');
  update exam_sessions set submitted_at=now()-interval '10 minutes'+interval '1 microsecond'
    where quiz_id=q and status in ('submitted','auto_submitted');
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released,'M9C one microsecond before wait boundary does not release');
  update exam_sessions set submitted_at=now()-interval '10 minutes'
    where quiz_id=q and status in ('submitted','auto_submitted');
  -- A recent voided historical attempt must not extend the wait.
  update exam_sessions set submitted_at=now() where quiz_id=q and status='voided';
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(released and (select results_released_at=now() and closes_at>now() from quizzes where id=q),
    'M9B all active submitted and graded releases while open ignoring pending and removed');
  perform pg_temp.m9_assert((select count(*)=2 and count(distinct recipient_id)=2
    and bool_and(recipient_id in(pg_temp.m9_id('u3'),pg_temp.m9_id('u6')))
    from notifications where target_id=q and type='results_released'),
    'M9B automatic inbox only active submitted attempts, no voided duplicate');
  before_state:=pg_temp.m9_rule_snapshot(q);
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released and before_state=pg_temp.m9_rule_snapshot(q),
    'M9B repeat automatic release preserves complete snapshot');

  q:=pg_temp.m9_rule_quiz('M9B closed nonparticipants');
  perform pg_temp.m9_rule_attempt(q,3,'submitted');
  update quizzes set closes_at=now() where id=q;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(released and (select results_released_at=now() from quizzes where id=q),
    'M9B closed quiz releases despite active not-started student');
  perform pg_temp.m9_assert((select count(*)=1 and bool_and(recipient_id=pg_temp.m9_id('u3'))
    from notifications where target_id=q and type='results_released'),'M9B closed release inbox excludes nonparticipants');
end $$;

-- Manual release refuses without changing quiz, sessions, answers, audit or inbox.
do $$
declare row record; q uuid; sid uuid; before_state jsonb;
begin
  for row in select * from (values
    ('foreign instructor',2,'Not allowed'),('student',3,'Not allowed'),
    ('in progress',1,'Some students are still taking this quiz'),
    ('ungraded essay',1,'Grade all essay answers first'),
    ('before opening',1,'This quiz has not opened yet')
  ) v(label,actor,message) loop
    q:=pg_temp.m9_rule_quiz('M9B manual '||row.label);
    sid:=pg_temp.m9_rule_attempt(q,3,
      case when row.label='in progress' then 'in_progress'::session_status else 'submitted' end,
      row.label<>'ungraded essay');
    if row.label='before opening' then update quizzes set opens_at=now()+interval '1 hour' where id=q; end if;
    before_state:=pg_temp.m9_rule_snapshot(q);
    perform pg_temp.m9_actor(row.actor);
    perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),
      'M9B manual refusal '||row.label,'P0001',row.message);
    perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),'M9B manual refusal unchanged '||row.label);
  end loop;
  q:=pg_temp.m9_rule_quiz('M9B manual success');
  perform pg_temp.m9_rule_attempt(q,3,'submitted');
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),'M9B normal manual release');
  perform pg_temp.m9_assert((select results_released_at=now() and closes_at=now() from quizzes where id=q),
    'M9B early manual release closes exactly now');
  before_state:=pg_temp.m9_rule_snapshot(q);
  perform pg_temp.m9_call(format('select to_jsonb(release_results(%L))',q),'M9B manual release twice');
  perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),'M9B manual twice changes nothing');
  perform pg_temp.m9_actor(6);
  perform pg_temp.m9_call(format('select to_jsonb(start_exam(%L))',q),'M9B never-started student after release',
    'P0001','This quiz has closed');
  perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),'M9B refused start after release unchanged');
end $$;

-- Second-chance refusals, including whitespace-trimmed validation and caller checks.
do $$
declare row record; q uuid; sid uuid; before_state jsonb;
begin
  for row in select * from (values
    ('short reason',1,'  123456789  ','Please give a reason of at least 10 characters'),
    ('foreign instructor',2,'Phone failure confirmed','Not allowed'),
    ('student caller',3,'Phone failure confirmed','Not allowed'),
    ('no attempt',1,'Phone failure confirmed','This student has no attempt to reset'),
    ('released',1,'Phone failure confirmed','Results are already released. Create a new quiz instead.'),
    ('closed',1,'Phone failure confirmed','Extend the closing time first so the student can retake it')
  ) v(label,actor,reason,message) loop
    q:=pg_temp.m9_rule_quiz('M9B chance '||row.label);
    if row.label<>'no attempt' then sid:=pg_temp.m9_rule_attempt(q,3,'submitted'); end if;
    if row.label='released' then update quizzes set results_released_at=now() where id=q; end if;
    if row.label='closed' then update quizzes set closes_at=now() where id=q; end if;
    before_state:=pg_temp.m9_rule_snapshot(q);
    perform pg_temp.m9_actor(row.actor);
    perform pg_temp.m9_call(format('select to_jsonb(grant_second_chance(%L,%L,%L,%L))',
      q,pg_temp.m9_id('u3'),row.reason,'Showed phone in person'),
      'M9B chance refusal '||row.label,'P0001',row.message);
    perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),'M9B chance refusal unchanged '||row.label);
  end loop;
end $$;

-- Retake from either state: preserve history, hide it, then create fresh attempt 2.
do $$
declare n integer; q uuid; old_id uuid; new_id uuid; r jsonb; old_answers jsonb; released boolean;
begin
  for n in 1..2 loop
    q:=pg_temp.m9_rule_quiz('M9B valid chance '||n);
    if n=2 then update quizzes set closes_at=now()+interval '10 minutes' where id=q; end if;
    old_id:=pg_temp.m9_rule_attempt(q,3,case n when 1 then 'in_progress'::session_status else 'submitted' end);
    perform pg_temp.m9_rule_attempt(q,6,'submitted');
    select jsonb_agg(to_jsonb(a) order by id) into old_answers from exam_answers a where session_id=old_id;
    perform pg_temp.m9_actor(1);
    perform pg_temp.m9_call(format('select to_jsonb(grant_second_chance(%L,%L,%L,%L))',
      q,pg_temp.m9_id('u3'),'  Phone failure confirmed  ','Showed phone in person'), 'M9B valid chance '||n);
    perform pg_temp.m9_assert((select status='voided' from exam_sessions where id=old_id)
      and old_answers=(select jsonb_agg(to_jsonb(a) order by id) from exam_answers a where session_id=old_id),
      'M9B archived attempt and answers retained '||n);
    perform pg_temp.m9_assert((select count(*)=1 and bool_and(previous_session_id=old_id
      and student_id=pg_temp.m9_id('u3') and granted_by=pg_temp.m9_id('u1')
      and reason='Phone failure confirmed' and proof_note='Showed phone in person' and created_at=now())
      from second_chances where quiz_id=q),'M9B complete second-chance audit '||n);
    perform pg_temp.m9_assert((select count(*)=1 and bool_and(recipient_id=pg_temp.m9_id('u3')
      and title='Another attempt granted' and body='Your instructor allowed you another attempt at M9B valid chance '||n
      and target_type='quiz' and class_id=(select class_id from quizzes where id=q))
      from notifications where target_id=q and type='second_chance'),'M9B second-chance inbox '||n);
    released:=maybe_release_results(q);
    perform pg_temp.m9_assert(not released and (select results_released_at is null from quizzes where id=q),
      'M9B voiding previously submitted attempt blocks open release '||n);
    perform pg_temp.m9_actor(3);
    r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'M9B metadata after void '||n);
    perform pg_temp.m9_assert(r is null,'M9B voided metadata hidden before restart '||n);
    r:=pg_temp.m9_call(format('select to_jsonb(start_exam(%L))',q),'M9B start retake '||n);
    new_id:=(r->>'id')::uuid;
    perform pg_temp.m9_assert(new_id<>old_id and (select attempt_no=2 and status='in_progress'
      and started_at=now() and deadline_at=least(now()+interval '30 minutes',
        (select closes_at from quizzes where id=q)) and deadline_at>now()+interval '5 minutes'
      and auto_score=0 and essay_score=0 and not grading_complete and submitted_at is null
      from exam_sessions where id=new_id) and not exists(select 1 from exam_answers where session_id=new_id),
      'M9B attempt 2 fresh empty state and correct deadline '||n);
    r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'M9B retake metadata '||n);
    perform pg_temp.m9_assert(r->>'session_id'=new_id::text and r->'attempt_no'='2'::jsonb
      and not (r ? 'score') and (select status='voided' from exam_sessions where id=old_id),
      'M9B metadata exposes replacement only '||n);
  end loop;
end $$;

-- M9-BE-03: replacement submissions reset the wait; grading never bypasses it.
do $$
declare q uuid; old_id uuid; new_id uuid; aid uuid; r jsonb; released boolean;
begin
  q:=pg_temp.m9_rule_quiz('M9C replacement wait');
  old_id:=pg_temp.m9_rule_attempt(q,3,'submitted');
  perform pg_temp.m9_rule_attempt(q,6,'auto_submitted');
  update exam_sessions set submitted_at=now()-interval '9 minutes' where quiz_id=q;
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(grant_second_chance(%L,%L,%L))',
    q,pg_temp.m9_id('u3'),'Phone failure confirmed'),'M9C grant during wait');
  -- Age the original submissions past the wait while the replacement is not started.
  update exam_sessions set submitted_at=now()-interval '11 minutes' where quiz_id=q;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released,'M9C granted but not restarted blocks after original wait');
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select to_jsonb(start_exam(%L))',q),'M9C start replacement');
  new_id:=(r->>'id')::uuid;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released,'M9C replacement in progress blocks after original wait');
  perform pg_temp.m9_call(format('select to_jsonb(save_answer(%L,%L,p_text => %L))',
    new_id,(select id from questions where quiz_id=q),'Replacement essay'),'M9C save replacement essay');
  perform pg_temp.m9_call(format('select submit_exam(%L)',new_id),'M9C submit replacement');
  select id into aid from exam_answers where session_id=new_id;
  perform pg_temp.m9_actor(1);
  perform pg_temp.m9_call(format('select to_jsonb(grade_essay(%L,2))',aid),'M9C grade during wait');
  perform pg_temp.m9_assert((select grading_complete and submitted_at=now() from exam_sessions where id=new_id)
    and (select results_released_at is null from quizzes where id=q),
    'M9C replacement submission resets wait and last essay cannot bypass it');
  perform pg_temp.m9_actor(3);
  r:=pg_temp.m9_call(format('select get_my_session(%L)',q),'M9C metadata during wait');
  perform pg_temp.m9_assert(not (r ? 'score') and r->'results_released'='false'::jsonb,
    'M9C score hidden during wait');
  perform pg_temp.m9_call(format('select get_result(%L)',new_id),'M9C result hidden during wait',
    'P0001','Results are not available yet');
  update exam_sessions set submitted_at=now()-interval '10 minutes' where id=new_id;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(released,'M9C replacement releases at new wait boundary');

  q:=pg_temp.m9_rule_quiz('M9C missing submission time');
  perform pg_temp.m9_rule_attempt(q,3,'submitted');
  perform pg_temp.m9_rule_attempt(q,6,'auto_submitted');
  update exam_sessions set submitted_at=null where quiz_id=q;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released,'M9C no qualifying timestamp keeps open quiz unreleased');
  update quizzes set closes_at=now() where id=q;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(released,'M9C closing bypasses missing timestamp wait');
end $$;

-- Exercise the real worker deterministically, never touching unrelated expired attempts.
do $$
declare q uuid; sid uuid; released boolean; before_state jsonb;
begin
  q:=pg_temp.m9_rule_quiz('M9B worker release');
  sid:=pg_temp.m9_rule_attempt(q,3,'in_progress',false);
  update quizzes set closes_at=now() where id=q;
  released:=maybe_release_results(q);
  perform pg_temp.m9_assert(not released and (select results_released_at is null from quizzes where id=q),
    'M9B in-progress attempt blocks even closed quiz');
  if exists(select 1 from exam_sessions where status='in_progress'
    and deadline_at+interval '15 seconds'<now() and id<>sid) then
    raise exception 'Unrelated overdue DEV attempts exist. ROLLBACK and resolve separately; do not remove this worker guard';
  end if;
  update exam_sessions set deadline_at=now()-interval '16 seconds' where id=sid;
  -- An unanswered essay permits worker completion; grading release is covered above.
  delete from exam_answers where session_id=sid;
  perform finalize_expired_sessions();
  perform pg_temp.m9_assert((select status='auto_submitted' and submitted_at=deadline_at
    and grading_complete from exam_sessions where id=sid),'M9B worker finalizes overdue attempt');
  perform pg_temp.m9_assert((select results_released_at=now() from quizzes where id=q)
    and (select count(*)=1 and bool_and(recipient_id=pg_temp.m9_id('u3')) from notifications
      where target_id=q and type='results_released'),'M9B worker releases and notifies after finalization');
  before_state:=pg_temp.m9_rule_snapshot(q);
  perform finalize_expired_sessions();
  perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),'M9B repeated worker preserves release and inbox');

  q:=pg_temp.m9_rule_quiz('M9C worker wait expiry');
  perform pg_temp.m9_rule_attempt(q,3,'submitted');
  perform pg_temp.m9_rule_attempt(q,6,'auto_submitted');
  update exam_sessions set submitted_at=now()-interval '10 minutes' where quiz_id=q;
  perform finalize_expired_sessions();
  perform pg_temp.m9_assert((select results_released_at=now() and closes_at>now() from quizzes where id=q),
    'M9C worker releases open quiz after wait without any newly expired session');
  before_state:=pg_temp.m9_rule_snapshot(q);
  perform finalize_expired_sessions();
  perform pg_temp.m9_assert(before_state=pg_temp.m9_rule_snapshot(q),
    'M9C worker after wait is idempotent');
end $$;

select step,test,result,detail from m9_results order by step;
select count(*) filter(where result='PASS') as passed,count(*) filter(where result='FAIL') as failed,
  case when bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]'::jsonb) as failures from m9_results;
rollback;
