-- DEV ONLY. Run WHOLE file as postgres on fiobwfzmqcffbpixzvbq after both M7 migrations.
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
    raise exception 'Apply both M7 migrations first';
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
declare c uuid:=current_setting('m7.class')::uuid; q uuid:=gen_random_uuid(); b uuid; mc uuid;
  copied uuid; r jsonb; row_data bank_questions; payload jsonb; snapshot jsonb; bank_before jsonb;
  t text; i integer; field text; val text; opts jsonb;
begin
  insert into quizzes(id,class_id,author_id,title) values(q,c,current_setting('m7.u1')::uuid,'Bank copy target');
  perform pg_temp.m7_actor(1);
  for t in select unnest(array['multiple_choice','true_false','identification','essay']) loop
    set local role authenticated;
    insert into bank_questions(owner_id,type,prompt,points,explanation,options,answer,source_class_id)
      values(auth.uid(),t::question_type,'Bank '||t,1,'Explanation',
        case when t='multiple_choice' then '[{"text":"A","is_correct":false},{"text":"B","is_correct":true}]'::jsonb end,
        case t when 'true_false' then '{"boolean":false}'::jsonb
          when 'identification' then '{"accepted":["answer","Alternative"]}'::jsonb end,c)
      returning * into row_data;
    reset role;
    b:=row_data.id;
    if t='multiple_choice' then mc:=b; end if;
    perform pg_temp.m7_check(format('select count(*)=1 from bank_questions where id=%L',b),'owner reads bank '||t);
    -- Bank -> save_question adapter: no bank ID or linkage is passed to the quiz.
    payload:=jsonb_build_object('type',row_data.type,'prompt',row_data.prompt,'points',row_data.points,
      'explanation',row_data.explanation,'position',0);
    if t='multiple_choice' then
      select jsonb_agg(x->'text' order by ord),min(ord-1) filter(where (x->>'is_correct')::boolean)
        into opts,i from jsonb_array_elements(row_data.options) with ordinality u(x,ord);
      payload:=payload||jsonb_build_object('options',opts,'correct_option_index',i);
    elsif t='true_false' then payload:=payload||jsonb_build_object('correct_boolean',row_data.answer->'boolean');
    elsif t='identification' then payload:=payload||jsonb_build_object('accepted_answers',row_data.answer->'accepted'); end if;
    set local role authenticated; r:=save_question(q,payload); reset role;
    copied:=(r->>'question_id')::uuid;
    perform pg_temp.m7_check(format('select prompt=%L and type=%L::question_type and points=1 from questions where id=%L',row_data.prompt,t,copied),'bank '||t||' copied through save_question');
    if t='multiple_choice' then
      perform pg_temp.m7_check(format('select o.position=1 and o.text=''B'' from answer_keys k join question_options o on o.id=k.correct_option_id where k.question_id=%L',copied),'bank correct flag maps to new correct option');
    elsif t='true_false' then
      perform pg_temp.m7_check(format('select correct_boolean=false from answer_keys where question_id=%L',copied),'bank false preserved');
    elsif t='identification' then
      perform pg_temp.m7_check(format('select accepted_answers=array[''answer'',''Alternative''] from answer_keys where question_id=%L',copied),'bank accepted answers preserved');
    else
      perform pg_temp.m7_check(format('select count(*)=0 from answer_keys where question_id=%L',copied),'bank essay copy has no key');
    end if;
    snapshot:=pg_temp.m7_snapshot(q);
    perform pg_temp.m7_run(format('update bank_questions set prompt=''Changed bank'' where id=%L',b),'00000','owner updates bank '||t);
    perform pg_temp.m7_run(format('update bank_questions set deleted_at=now() where id=%L',b),'00000','owner soft deletes bank '||t);
    perform pg_temp.m7_check(format('select deleted_at is not null from bank_questions where id=%L',b),'owner receives bank tombstone');
    perform pg_temp.m7_unchanged(q,snapshot,'bank changes/delete do not alter quiz copy');
    perform pg_temp.m7_run(format('delete from bank_questions where id=%L',b),'42501','hard delete refused; use tombstone');
  end loop;
  -- Restore the MC fixture for access/validation cases.
  perform pg_temp.m7_run(format('update bank_questions set deleted_at=null where id=%L',mc),'00000','owner can clear bank tombstone');
  perform pg_temp.m7_run(format('update bank_questions set owner_id=%L where id=%L',current_setting('m7.u2'),mc),'42501','owner transfer refused');
  for i in select unnest(array[2,3,8]) loop
    perform pg_temp.m7_actor(i);
    perform pg_temp.m7_check(format('select count(*)=0 from bank_questions where id=%L',mc),'actor '||i||' cannot read another bank row');
    perform pg_temp.m7_check(format('with x as(update bank_questions set prompt=''Intrusion'' where id=%L returning id) select count(*)=0 from x',mc),'actor '||i||' cannot update another bank row');
    perform pg_temp.m7_check(format('with x as(update bank_questions set deleted_at=now() where id=%L returning id) select count(*)=0 from x',mc),'actor '||i||' cannot soft delete another bank row');
    perform pg_temp.m7_run(format('insert into bank_questions(owner_id,type,prompt) values(%L,''essay'',''Forged'')',current_setting('m7.u1')),'42501','actor '||i||' cannot create for another owner');
    if i<>2 then
      perform pg_temp.m7_run('insert into bank_questions(owner_id,type,prompt) values(auth.uid(),''essay'',''Own forbidden'')','42501','student/unverified cannot create own bank row');
    else
      perform pg_temp.m7_run('insert into bank_questions(owner_id,type,prompt) values(auth.uid(),''essay'',''Other instructor own'')','00000','second instructor can create own row');
    end if;
  end loop;
  perform pg_temp.m7_actor(1);
  foreach field in array array['prompt','points','explanation'] loop
    for i in 1..2 loop
      val:=case field when 'prompt' then quote_literal(case when i=1 then '' else repeat('p',1001) end)
        when 'points' then case when i=1 then '0' else '1001' end
        else quote_literal(repeat('e',501)) end;
      select to_jsonb(x) into bank_before from bank_questions x where id=mc;
      perform pg_temp.m7_run(format('update bank_questions set %I=%s where id=%L',field,val,mc),'22023','bank invalid '||field||' boundary '||i);
      insert into m7_results(test,result) select 'invalid bank update preserves row',
        case when to_jsonb(x)=bank_before then 'PASS' else 'FAIL' end from bank_questions x where id=mc;
    end loop;
  end loop;
  perform pg_temp.m7_run(format('update bank_questions set prompt=%L,points=1000,explanation=%L where id=%L',repeat('p',1000),repeat('e',500),mc),'00000','bank inclusive maxima accepted');
  perform pg_temp.m7_run(format('update bank_questions set prompt=''X'',points=1,explanation=null where id=%L',mc),'00000','bank lower limits accepted');
  perform pg_temp.m7_run(format('update bank_questions set options=''[{"text":"A","is_correct":false}]''::jsonb where id=%L',mc),'22023','bank malformed/no correct choice refused');
  perform pg_temp.m7_run(format('update bank_questions set options=''[{"text":"A","is_correct":true},{"text":"B","is_correct":true}]''::jsonb where id=%L',mc),'22023','bank two correct choices refused');
end $$;
select * from m7_results order by step;
select count(*) filter(where result='PASS') as passed, count(*) filter(where result='FAIL') as failed,
 case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
 coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m7_results;
rollback;
