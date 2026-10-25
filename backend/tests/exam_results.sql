-- M9-BE-01. DEV ONLY: fiobwfzmqcffbpixzvbq, SQL Editor, postgres role.
-- Run the WHOLE file after repository migrations through 20261024100000.
-- Any FAIL or uncaught error means failure. On abort run ROLLBACK separately.
-- Synthetic fixtures only; no global worker, trigger disabling, or committed data.
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
    perform pg_temp.m9_assert((select (results_released_at is not null)=(n=5) from quizzes where id=q),
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

select step,test,result,detail from m9_results order by step;
select count(*) filter(where result='PASS') as passed,count(*) filter(where result='FAIL') as failed,
  case when bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]'::jsonb) as failures from m9_results;
rollback;
