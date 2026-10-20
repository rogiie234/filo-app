-- DEV ONLY. Run WHOLE file as postgres on fiobwfzmqcffbpixzvbq after all three M7 migrations (including 20261020120000).
-- Rollback fixtures; no real accounts. FAIL rows/uncaught errors mean failure.
-- On abort, ROLLBACK separately before retry. SQL simulation is not HTTP/phone/push evidence.
begin;
create temporary table m7_results(step integer generated always as identity,
  test text, result text, detail text) on commit drop;
create function pg_temp.m7_actor(i integer) returns void language plpgsql as $$
begin
  if i=0 then perform set_config('request.jwt.claims','{}',true); return; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('m7.u'||i),
    'session_id',current_setting('m7.s'||i),'role','authenticated')::text,true);
end $$;
create function pg_temp.m7_check(q text, label text) returns void language plpgsql as $$
declare ok boolean; msg text;
begin
  begin
    set local role authenticated; execute q into ok; reset role;
  exception when others then
    get stacked diagnostics msg=message_text; reset role;
  end;
  insert into m7_results(test,result,detail) values(label,case when ok is true then 'PASS' else 'FAIL' end,msg);
end $$;
create function pg_temp.m7_run(q text, expected text, label text) returns void language plpgsql as $$
declare code text := '00000'; msg text;
begin
  begin
    set local role authenticated; execute q; reset role;
    -- Roll back unexpected success so a refused-write assertion cannot contaminate later cases.
    if expected <> '00000' then raise exception 'Unexpected success' using errcode='ZQ001'; end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text; reset role;
    if code='ZQ001' then code:='00000'; end if;
  end;
  insert into m7_results(test,result,detail) values(label,
    case when code=expected then 'PASS' else 'FAIL' end,code||coalesce(': '||msg,''));
end $$;
-- Administrator snapshot includes rows students cannot see. This is only a temporary helper.
create function pg_temp.m7_snapshot(qid uuid) returns jsonb language sql as $$
select jsonb_build_object('quiz',(select to_jsonb(q) from quizzes q where id=qid),
 'questions',(select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]') from questions x where quiz_id=qid),
 'options',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from question_options o
   join questions x on x.id=o.question_id where x.quiz_id=qid),
 'keys',(select coalesce(jsonb_agg(to_jsonb(k) order by k.question_id),'[]') from answer_keys k
   join questions x on x.id=k.question_id where x.quiz_id=qid));
$$;
create function pg_temp.m7_unchanged(qid uuid, before_state jsonb, label text) returns void language plpgsql as $$
begin
 insert into m7_results(test,result) values(label,
   case when pg_temp.m7_snapshot(qid)=before_state then 'PASS' else 'FAIL' end);
end $$;
do $$
declare u uuid; s uuid; i integer; c uuid:=gen_random_uuid();
begin
  if to_regprocedure('public.save_question(uuid,jsonb)') is null or
     to_regprocedure('public.reorder_questions(uuid,uuid[])') is null then
    raise exception 'Apply the M7 migrations first';
  end if;
  if position('delete from public.answer_keys' in lower(pg_get_functiondef(
    'public.guard_question_edits()'::regprocedure)))=0 then
    raise exception 'Apply 20261020120000_quiz_question_delete_cascade.sql before rerunning';
  end if;
  for i in 1..8 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m7.u'||i,u::text,true); perform set_config('m7.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    insert into profiles(id,role,display_name) values(u,
      case when i in (1,2,8) then 'instructor'::user_role else 'student'::user_role end,'M7 fixture '||i);
    if i<>8 then insert into verified_sessions(session_id,user_id) values(s,u); end if;
  end loop;
  insert into classes(id,owner_id,course,section,school_year)
    values(c,current_setting('m7.u1')::uuid,'M7 fixture','M7','2026-2027');
  perform set_config('m7.class',c::text,true);
  for i in 3..7 loop
    insert into class_members(class_id,student_id,status) values(c,current_setting('m7.u'||i)::uuid,
      case i when 3 then 'active'::member_status when 4 then 'active'::member_status
        when 5 then 'pending'::member_status when 6 then 'removed'::member_status else 'left'::member_status end);
  end loop;
end $$;
do $$
declare c uuid:=current_setting('m7.class')::uuid; q uuid:=gen_random_uuid(); other_q uuid:=gen_random_uuid();
  qu uuid; mc uuid; tf uuid; ident uuid; essay uuid; oid uuid; session_id uuid;
  payload jsonb; r jsonb; before_state jsonb; ids uuid[]; field text; tbl text; i integer; t text; bad jsonb; v_sql text;
  start_code text; start_message text; start_context text; start_state jsonb;
begin
  insert into quizzes(id,class_id,author_id,title,opens_at,closes_at)
    values(q,c,current_setting('m7.u1')::uuid,'M7 Quiz',now()-interval '1 hour',now()+interval '1 day'),
    (other_q,c,current_setting('m7.u1')::uuid,'M7 Other',now()-interval '1 hour',now()+interval '1 day');
  perform set_config('m7.quiz',q::text,true);
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','no questions refused');
  set local role authenticated;
  r:=save_question(q,'{"type":"essay","prompt":"Explain","points":5,"position":0}');
  reset role;
  essay:=(r->>'question_id')::uuid;
  perform pg_temp.m7_check(format('select total_points=5 and has_essay from quizzes where id=%L',q),'insert refreshes totals/essay');
  perform pg_temp.m7_run(format('update questions set points=7 where id=%L',essay),'00000','edit essay points');
  perform pg_temp.m7_check(format('select total_points=7 and has_essay from quizzes where id=%L',q),'update refreshes totals');
  perform pg_temp.m7_run(format('update questions set type=''true_false'' where id=%L',essay),'00000','change only essay to nonessay draft');
  perform pg_temp.m7_check(format('select total_points=7 and not has_essay from quizzes where id=%L',q),'type change clears has_essay');
  perform pg_temp.m7_run(format('update questions set type=''essay'' where id=%L',essay),'00000','change back to essay');
  perform pg_temp.m7_check(format('select has_essay from quizzes where id=%L',q),'type change sets has_essay');
  perform pg_temp.m7_run(format('update questions set quiz_id=%L where id=%L',other_q,essay),'00000','move unlocked question');
  perform pg_temp.m7_check(format('select total_points=0 and not has_essay from quizzes where id=%L',q),'move refreshes old parent');
  perform pg_temp.m7_check(format('select total_points=7 and has_essay from quizzes where id=%L',other_q),'move refreshes new parent');
  perform pg_temp.m7_run(format('update questions set quiz_id=%L where id=%L',q,essay),'00000','move back');
  perform pg_temp.m7_run(format('delete from questions where id=%L',essay),'00000','delete unlocked question');
  perform pg_temp.m7_check(format('select total_points=0 and not has_essay from quizzes where id=%L',q),'delete refreshes totals/essay');
  set local role authenticated;
  r:=save_question(q,'{"type":"essay","prompt":"Explain","points":1,"position":0}');
  reset role;
  essay:=(r->>'question_id')::uuid;
  for field in select unnest(array['opens_at','closes_at']) loop
    perform pg_temp.m7_run(format('update quizzes set %I=null where id=%L',field,q),'00000','clear '||field);
    perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','missing '||field||' refused');
    perform pg_temp.m7_run(format('update quizzes set opens_at=now()-interval ''1 hour'',closes_at=now()+interval ''1 day'' where id=%L',q),'00000','restore schedule');
  end loop;
  perform pg_temp.m7_run(format('update quizzes set opens_at=now()-interval ''2 days'',closes_at=now()-interval ''1 day'' where id=%L',q),'00000','past close fixture');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','past close refused');
  perform pg_temp.m7_run(format('update quizzes set closes_at=opens_at where id=%L',q),'23514','equal times refused by quiz_window');
  perform pg_temp.m7_run(format('update quizzes set closes_at=opens_at-interval ''1 minute'' where id=%L',q),'23514','reversed times refused by quiz_window');
  perform pg_temp.m7_run(format('update quizzes set opens_at=now()-interval ''1 hour'',closes_at=now()+interval ''1 day'' where id=%L',q),'00000','restore future schedule');
  -- Legacy incomplete drafts exercise publish validation independently of the new save RPC.
  for t in select unnest(array['multiple_choice','true_false','identification']) loop
    set local role authenticated;
    insert into questions(quiz_id,type,prompt) values(q,t::question_type,'Incomplete') returning id into qu;
    reset role;
    perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001',t||' missing key refused');
    set local role authenticated; insert into answer_keys(question_id) values(qu); reset role;
    perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001',t||' empty answer refused');
    if t='multiple_choice' then
      set local role authenticated;
      insert into question_options(question_id,text) values(qu,'One') returning id into oid;
      insert into question_options(question_id,text) values(qu,'Two');
      reset role;
      perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','two options without correct selection refused');
      set local role authenticated;
      delete from question_options where question_id=qu and id<>oid;
      update answer_keys set correct_option_id=oid where question_id=qu;
      reset role;
      perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','one MC option refused');
      set local role authenticated;
      insert into question_options(question_id,text) select qu,'Option '||x from generate_series(2,11) x;
      reset role;
      perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','eleven MC options refused');
    end if;
    perform pg_temp.m7_run(format('delete from questions where id=%L',qu),'00000','remove incomplete '||t);
    perform pg_temp.m7_check(format('select not exists(select 1 from questions where id=%L) and not exists(select 1 from question_options where question_id=%L) and not exists(select 1 from answer_keys where question_id=%L)',qu,qu,qu),'question and children removed together: '||t);
  end loop;
  for t in select unnest(array['multiple_choice','true_false','identification']) loop
    payload:=jsonb_build_object('type',t,'prompt',t,'points',2,'position',1);
    if t='multiple_choice' then payload:=payload||'{"options":["A","B"],"correct_option_index":1}'::jsonb;
    elsif t='true_false' then payload:=payload||'{"correct_boolean":false}'::jsonb;
    else payload:=payload||'{"accepted_answers":["answer","alternative"]}'::jsonb; end if;
    set local role authenticated; r:=save_question(q,payload); reset role;
    qu:=(r->>'question_id')::uuid;
    if t='multiple_choice' then
      mc:=qu;
      perform pg_temp.m7_check(format('select array_agg(id order by position)=array[%L::uuid,%L::uuid] from question_options where question_id=%L',r->'option_ids'->>0,r->'option_ids'->>1,mc),'returned option IDs match input order');
    elsif t='true_false' then tf:=qu; else ident:=qu; end if;
    perform pg_temp.m7_check(format('select count(*)=1 from answer_keys where question_id=%L',qu),'valid '||t||' saved');
  end loop;
  for bad in select value from jsonb_array_elements('[
    {"type":"multiple_choice","options":["A"],"correct_option_index":0},
    {"type":"multiple_choice","options":["A","B"],"correct_option_index":2},
    {"type":"multiple_choice","options":["A",null],"correct_option_index":0},
    {"type":"true_false","correct_boolean":"false"}, {"type":"true_false"},
    {"type":"identification","accepted_answers":[]}, {"type":"identification","accepted_answers":[" "]},
    {"type":"essay","prompt":" "}, {"type":"essay","points":0}, {"type":"essay","points":1001},
    {"type":"essay","points":1.5}, {"type":"essay","position":-1}, {"type":"essay","position":null},
    {"type":"unknown"}
  ]'::jsonb) loop
    payload:='{"prompt":"Invalid candidate","points":1,"position":0}'::jsonb||bad;
    before_state:=pg_temp.m7_snapshot(q);
    perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'22023','invalid new: '||bad::text);
    perform pg_temp.m7_unchanged(q,before_state,'invalid new preserves all rows');
    payload:=payload||jsonb_build_object('id',mc);
    perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'22023','invalid edit: '||bad::text);
    perform pg_temp.m7_unchanged(q,before_state,'invalid edit preserves all rows');
  end loop;
  for payload in select unnest(array[
    jsonb_build_object('type','essay','prompt',repeat('x',1001),'points',1,'position',0),
    jsonb_build_object('type','essay','prompt','X','points',1,'position',0,'explanation',repeat('x',501)),
    jsonb_build_object('type','essay','prompt','X','points',1,'position',0,'id','invalid'),
    jsonb_build_object('type','multiple_choice','prompt','X','points',1,'position',0,'options',jsonb_build_array(repeat('x',501),'B'),'correct_option_index',0),
    jsonb_build_object('type','multiple_choice','prompt','X','points',1,'position',0,'options',to_jsonb(array_fill('x'::text,array[11])),'correct_option_index',0),
    jsonb_build_object('type','identification','prompt','X','points',1,'position',0,'accepted_answers',to_jsonb(array_fill('x'::text,array[11])))]) loop
    before_state:=pg_temp.m7_snapshot(q);
    perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'22023','over-limit or invalid-id payload');
    perform pg_temp.m7_unchanged(q,before_state,'limit failure preserves all rows');
  end loop;
  payload:=jsonb_build_object('id',mc,'type','multiple_choice','prompt',repeat('x',1000),'points',1000,
    'position',0,'explanation',repeat('e',500),'options',to_jsonb(array_fill(repeat('o',500),array[10])),'correct_option_index',9);
  select id into oid from question_options where question_id=mc order by position limit 1;
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'00000','inclusive maximum lengths/points/options accepted');
  perform pg_temp.m7_check(format('select count(*)=0 from question_options where id=%L',oid),'old options replaced');
  perform pg_temp.m7_check(format('select points=1000 and length(prompt)=1000 from questions where id=%L',mc),'edit retains question ID and saves values');
  perform pg_temp.m7_check(format('select o.position=9 from answer_keys k join question_options o on o.id=k.correct_option_id where k.question_id=%L',mc),'replacement key points at correct new option');
  payload:=jsonb_build_object('id',mc,'type','essay','prompt','Essay now','points',1,'position',0);
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'00000','type change to essay');
  perform pg_temp.m7_check(format('select not exists(select 1 from answer_keys where question_id=%L) and not exists(select 1 from question_options where question_id=%L)',mc,mc),'type change clears old options/key');
  payload:=jsonb_build_object('id',mc,'type','multiple_choice','prompt','MC again','points',2,'position',0,'options',jsonb_build_array('A','B'),'correct_option_index',0);
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'00000','edit back to MC');
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',other_q,payload),'22023','foreign question id refused');
  select array_agg(id order by id desc) into ids from questions where quiz_id=q;
  perform pg_temp.m7_run(format('select reorder_questions(%L,%L::uuid[])',q,ids),'00000','reorder all questions');
  perform pg_temp.m7_check(format('select array_agg(id order by position)=%L::uuid[] from questions where quiz_id=%L',ids,q),'positions match requested order');
  before_state:=pg_temp.m7_snapshot(q);
  foreach v_sql in array array['NULL::uuid[]',quote_literal(array[mc,mc])||'::uuid[]',quote_literal(array[mc])||'::uuid[]',quote_literal(ids||gen_random_uuid())||'::uuid[]',quote_literal(ids||array[null::uuid])||'::uuid[]'] loop
    perform pg_temp.m7_run(format('select reorder_questions(%L,%s)',q,v_sql),'22023','invalid reorder: '||v_sql);
    perform pg_temp.m7_unchanged(q,before_state,'invalid reorder changes nothing');
  end loop;
  perform pg_temp.m7_actor(3);
  perform pg_temp.m7_check(format('select count(*)=0 from quizzes where id=%L',q),'student cannot read draft');
  foreach tbl in array array['questions','question_options','answer_keys'] loop
    perform pg_temp.m7_check(format('select count(*)=0 from %I',tbl),'draft student cannot read '||tbl);
  end loop;
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'42501','student save refused');
  perform pg_temp.m7_actor(2);
  perform pg_temp.m7_check(format('select count(*)=0 from quizzes where id=%L',q),'other instructor cannot read quiz');
  perform pg_temp.m7_check(format('with x as (update quizzes set title=''Foreign'' where id=%L returning id) select count(*)=0 from x',q),'other instructor cannot update quiz');
  foreach tbl in array array['questions','question_options','answer_keys'] loop
    perform pg_temp.m7_check(format('select count(*)=0 from %I where %I=%L',tbl,
      case when tbl='questions' then 'quiz_id' else 'question_id' end,
      case when tbl='questions' then q else mc end),'foreign instructor cannot read '||tbl);
  end loop;
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'42501','other instructor save refused');
  perform pg_temp.m7_run(format('select reorder_questions(%L,%L::uuid[])',q,ids),'42501','other instructor reorder refused');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','other instructor publish refused');
  perform pg_temp.m7_actor(8);
  perform pg_temp.m7_check(format('select count(*)=0 from quizzes where id=%L',q),'unverified instructor sees no quiz');
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'42501','unverified save refused');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'42501','unverified publish refused');
  perform pg_temp.m7_actor(0); update classes set archived_at=now() where id=c;
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('insert into quizzes(class_id,author_id,title) values(%L,%L,''Archived'')',c,current_setting('m7.u1')),'42501','archived class creation refused');
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'42501','archived save refused');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'P0001','archived publish refused');
  perform pg_temp.m7_actor(0);
  update classes set archived_at=null where id=c;
  update quizzes set deleted_at=now() where id=other_q;
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('select publish_quiz(%L)',other_q),'P0001','deleted quiz publish refused');
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',other_q,payload),'42501','deleted quiz save refused');
  perform pg_temp.m7_actor(0); update quizzes set deleted_at=null where id=other_q;
  perform pg_temp.m7_actor(1);
  foreach field in array array['status','published_at','results_released_at','locked_at','total_points','has_essay'] loop
    v_sql:=case field when 'status' then '''published''' when 'total_points' then '10' when 'has_essay' then 'true' else 'now()' end;
    perform pg_temp.m7_run(format('update quizzes set %I=%s where id=%L',field,v_sql,q),'42501','direct protected field refused: '||field);
  end loop;
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'00000','essay without key and complete questions publish');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'00000','publishing twice is idempotent');
  insert into m7_results(test,result) select 'one correct inbox row per active student',
    case when count(*)=2 and count(distinct recipient_id)=2 and bool_and(
      recipient_id in (current_setting('m7.u3')::uuid,current_setting('m7.u4')::uuid)
      and type='quiz_published' and class_id=c and target_type='quiz' and title='New quiz'
      and body like 'New quiz in M7 fixture: M7 Quiz, opens %') then 'PASS' else 'FAIL' end
    from notifications where target_id=q;
  for i in 1..3 loop
    perform pg_temp.m7_actor(3);
    perform pg_temp.m7_check(format('select count(*)=1 from quizzes where id=%L',q),'student reads published row phase '||i);
    foreach tbl in array array['questions','question_options','answer_keys'] loop
      perform pg_temp.m7_check(format('select count(*)=0 from %I',tbl),'checklist 2: '||tbl||' hidden phase '||i);
    end loop;
    if i=1 then
      -- Preserve earlier FAIL rows instead of aborting before the final summaries.
      -- Capture fixture state as postgres, but perform the RPC as the real fixture actor.
      start_state:=jsonb_build_object(
        'quiz_id',q,'quiz',(select jsonb_build_object('status',x.status,'deleted_at',x.deleted_at,
          'class_id',x.class_id,'opens_at',x.opens_at,'closes_at',x.closes_at) from quizzes x where x.id=q),
        'student_id',auth.uid(),
        'membership',(select m.status from class_members m where m.class_id=c and m.student_id=auth.uid()),
        'class',(select jsonb_build_object('archived_at',x.archived_at,'deleted_at',x.deleted_at) from classes x where x.id=c),
        'earlier_failures',(select coalesce(jsonb_agg(jsonb_build_object('test',test,'detail',detail) order by step),'[]')
          from m7_results where result='FAIL'));
      begin
        set local role authenticated;
        session_id:=(start_exam(q)).id;
        reset role;
        insert into m7_results(test,result) values('student start creates session','PASS');
      exception when others then
        get stacked diagnostics start_code=returned_sqlstate,start_message=message_text,start_context=pg_exception_context;
        reset role;
        insert into m7_results(test,result,detail) values('student start creates session','FAIL',
          start_code||': '||start_message||E'\n'||start_context||E'\nFixture: '||start_state::text);
        insert into m7_results(test,result,detail) values('during/after attempt checks completed','FAIL',
          'Not executed because student start failed; see the start diagnostic and earlier failures.');
        exit;
      end;
      perform pg_temp.m7_check(format('select jsonb_array_length(get_exam(%L)->''questions'')=4',session_id),'authorized get_exam returns questions');
      perform pg_temp.m7_check(format('select not (get_exam(%L)::text like ''%%correct_option_id%%'')',session_id),'get_exam omits key column');
    elsif i=2 then
      perform pg_temp.m7_actor(0);
      update exam_sessions set status='submitted',submitted_at=now(),grading_complete=true where id=session_id;
      update quizzes set results_released_at=now() where id=q;
      perform pg_temp.m7_actor(3);
      perform pg_temp.m7_run(format('select get_result(%L)',session_id),'00000','authorized released result accessible');
    end if;
  end loop;
  -- Lock a second quiz by hand and check both direct and RPC creation guards.
  perform pg_temp.m7_actor(0); update quizzes set locked_at=now() where id in (q,other_q);
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',other_q,payload-'id'),'22023','manually locked quiz save refused');
  perform pg_temp.m7_run(format('insert into questions(quiz_id,type,prompt) values(%L,''essay'',''Blocked'')',other_q),'22023','manually locked quiz question insert refused');
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'22023','locked save refused');
  perform pg_temp.m7_run(format('select reorder_questions(%L,%L::uuid[])',q,ids),'22023','locked reorder refused');
  before_state:=pg_temp.m7_snapshot(q);
  foreach field in array array['time_limit_minutes','opens_at','shuffle_questions','shuffle_options','show_correct_answers','passing_percent','instructions','type','deleted_at'] loop
    v_sql:=case field when 'time_limit_minutes' then '31' when 'opens_at' then 'now()'
      when 'passing_percent' then '50' when 'instructions' then '''Changed'''
      when 'type' then '''exam''' when 'deleted_at' then 'now()' else 'false' end;
    perform pg_temp.m7_run(format('update quizzes set %I=%s where id=%L',field,v_sql,q),'22023','locked setting refused: '||field);
  end loop;
  perform pg_temp.m7_run(format('insert into questions(quiz_id,type,prompt) values(%L,''essay'',''Blocked'')',q),'22023','locked question insert refused');
  perform pg_temp.m7_run(format('update questions set prompt=''Blocked'' where id=%L',mc),'22023','locked question update refused');
  perform pg_temp.m7_run(format('delete from questions where id=%L',mc),'22023','locked question delete refused');
  perform pg_temp.m7_run(format('update questions set quiz_id=%L where id=%L',other_q,mc),'22023','locked source cannot move');
  select id into oid from question_options where question_id=mc order by position limit 1;
  perform pg_temp.m7_run(format('insert into question_options(question_id,text) values(%L,''Blocked'')',mc),'22023','locked option insert refused');
  perform pg_temp.m7_run(format('update question_options set text=''Blocked'' where id=%L',oid),'22023','locked option update refused');
  perform pg_temp.m7_run(format('delete from question_options where id=%L',oid),'22023','locked option delete refused');
  perform pg_temp.m7_run(format('update question_options set question_id=%L where id=%L',tf,oid),'22023','locked option reparent refused');
  perform pg_temp.m7_run(format('insert into answer_keys(question_id,correct_boolean) values(%L,true)',essay),'22023','locked key insert refused');
  perform pg_temp.m7_run(format('update answer_keys set correct_option_id=null where question_id=%L',mc),'22023','locked key update refused');
  perform pg_temp.m7_run(format('delete from answer_keys where question_id=%L',mc),'22023','locked key delete refused');
  perform pg_temp.m7_run(format('update answer_keys set question_id=%L where question_id=%L',essay,tf),'22023','locked key reparent refused');
  perform pg_temp.m7_unchanged(q,before_state,'all locked mutations preserve snapshot');
  perform pg_temp.m7_run(format('update quizzes set title=''Renamed'',closes_at=now()+interval ''2 days'' where id=%L',q),'00000','locked title/valid closing time can change');
  perform pg_temp.m7_actor(0); update quizzes set locked_at=null where id=other_q;
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('update quizzes set deleted_at=now() where id=%L',other_q),'00000','unstarted draft can be deleted');
end $$;
-- A real failure AFTER the question/options writes must roll the entire RPC back.
create function pg_temp.m7_fail_key() returns trigger language plpgsql as $$
begin
  if exists(select 1 from questions where id=new.question_id and prompt='M7 injected failure') then
    raise exception 'M7 deliberate key failure';
  end if;
  return new;
end $$;
create trigger m7_inject_key_failure before insert on public.answer_keys
for each row execute function pg_temp.m7_fail_key();
do $$
declare q uuid:=gen_random_uuid(); r jsonb; payload jsonb; state jsonb; mc uuid;
begin
  perform pg_temp.m7_actor(0);
  insert into quizzes(id,class_id,author_id,title,opens_at,closes_at)
    values(q,current_setting('m7.class')::uuid,current_setting('m7.u1')::uuid,'Atomic fixture',now()-interval '1 hour',now()+interval '1 day');
  perform pg_temp.m7_actor(1);
  perform pg_temp.m7_run(format('select reorder_questions(%L,''{}''::uuid[])',q),'00000','empty quiz accepts empty reorder');
  state:=pg_temp.m7_snapshot(q);
  payload:='{"type":"multiple_choice","prompt":"M7 injected failure","points":1,"position":0,"options":["A","B"],"correct_option_index":0}';
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'P0001','late new-key failure surfaces');
  perform pg_temp.m7_unchanged(q,state,'late new-key failure rolls back question/options/totals');
  set local role authenticated;
  r:=save_question(q,payload||'{"prompt":"Original"}'::jsonb);
  reset role;
  mc:=(r->>'question_id')::uuid;
  perform pg_temp.m7_run(format('update questions set quiz_id=%L where id=%L',current_setting('m7.quiz'),mc),'22023','unlocked source cannot move into locked destination');
  state:=pg_temp.m7_snapshot(q);
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload||jsonb_build_object('id',mc)),'P0001','late edit-key failure surfaces');
  perform pg_temp.m7_unchanged(q,state,'late edit failure restores original options/key/points');
  payload:=jsonb_build_object('type','identification','prompt','Ten accepted','points',1,'position',1,
    'accepted_answers',to_jsonb(array_fill('accepted'::text,array[10])));
  perform pg_temp.m7_run(format('select save_question(%L,%L::jsonb)',q,payload),'00000','ten accepted answers allowed');
  perform pg_temp.m7_run(format('select publish_quiz(%L)',q),'00000','publish unstarted delete fixture');
  perform pg_temp.m7_run(format('update quizzes set deleted_at=now() where id=%L',q),'00000','published quiz with no starts can be deleted');
end $$;
drop trigger m7_inject_key_failure on public.answer_keys;
select * from m7_results order by step;
select count(*) filter(where result='PASS') as passed, count(*) filter(where result='FAIL') as failed,
 case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
 coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m7_results;
rollback;
