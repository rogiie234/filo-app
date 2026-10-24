-- DEV SQL Editor, postgres: run the WHOLE file after 20261024100000.
-- Synthetic, rollback-only fixtures. Any uncaught exception is a failure.
begin;
set local search_path = public;
create temporary table batch_questions(pos int primary key, id uuid, option_id uuid) on commit drop;
create function pg_temp.batch_assert(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  raise notice 'PASS: %', label;
end $$;
create function pg_temp.batch_call(payload jsonb, attempt uuid default null) returns jsonb
language plpgsql as $$
declare receipt jsonb;
begin
  set local role authenticated;
  receipt := public.save_answers(coalesce(attempt,current_setting('batch.attempt')::uuid),payload);
  reset role;
  return receipt;
exception when others then reset role; raise;
end $$;
create function pg_temp.batch_reject(payload jsonb, expected text, label text, attempt uuid default null)
returns void language plpgsql as $$
declare code text := '00000';
begin
  begin perform pg_temp.batch_call(payload,attempt);
  exception when others then code := sqlstate; end;
  perform pg_temp.batch_assert(code=expected,label||' SQLSTATE='||code);
end $$;

do $$
declare
  owner_id uuid:=gen_random_uuid(); student uuid:=gen_random_uuid(); other_student uuid:=gen_random_uuid();
  verified uuid:=gen_random_uuid(); classroom uuid:=gen_random_uuid(); quiz uuid:=gen_random_uuid();
  attempt uuid:=gen_random_uuid(); question uuid; v_option_id uuid; other_attempt uuid:=gen_random_uuid();
  kind question_type; i int; chunk int; payload jsonb; receipt jsonb; mixed jsonb;
  bool_id uuid; text_id uuid; essay_id uuid; choice_id uuid; foreign_option uuid;
begin
  insert into auth.users(id) values(owner_id),(student),(other_student);
  insert into auth.sessions(id,user_id) values(verified,student);
  insert into public.profiles(id,role,display_name) values
    (owner_id,'instructor','Batch fixture instructor'),(student,'student','Batch fixture student'),
    (other_student,'student','Batch fixture other student');
  insert into public.verified_sessions(session_id,user_id) values(verified,student);
  insert into public.classes(id,owner_id,course,section,school_year)
    values(classroom,owner_id,'Batch fixture','50 answers','2026');
  insert into public.class_members(class_id,student_id,status) values(classroom,student,'active');
  insert into public.quizzes(id,class_id,author_id,title,time_limit_minutes,opens_at,closes_at)
    values(quiz,classroom,owner_id,'Batch fixture',30,now()-interval '1 hour',now()+interval '1 hour');
  for i in 1..50 loop
    kind := case when i<=30 then 'multiple_choice'::question_type
      when i<=40 then 'true_false'::question_type when i<=48 then 'identification'::question_type else 'essay'::question_type end;
    insert into public.questions(quiz_id,position,type,prompt)
      values(quiz,i,kind,'Batch fixture question '||i) returning id into question;
    v_option_id := null;
    if kind='multiple_choice' then
      insert into public.question_options(question_id,position,text) values(question,1,'First') returning id into v_option_id;
      insert into public.question_options(question_id,position,text) values(question,2,'Second');
      insert into public.answer_keys(question_id,correct_option_id) values(question,v_option_id);
    elsif kind='true_false' then
      insert into public.answer_keys(question_id,correct_boolean) values(question,true);
    elsif kind='identification' then
      insert into public.answer_keys(question_id,accepted_answers) values(question,array['answer']);
    end if;
    insert into batch_questions values(i,question,v_option_id);
  end loop;
  update public.quizzes set status='published',published_at=now() where id=quiz;
  insert into public.exam_sessions(id,quiz_id,student_id,deadline_at,question_order)
    values(attempt,quiz,student,now()+interval '30 minutes',(select array_agg(id order by pos) from batch_questions)),
      (other_attempt,quiz,other_student,now()+interval '30 minutes','{}');
  perform set_config('batch.attempt',attempt::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',student,'session_id',verified,'role','authenticated')::text,true);

  perform pg_temp.batch_assert(not has_function_privilege('anon','public.save_answers(uuid,jsonb)','EXECUTE'), 'anonymous execute revoked');
  perform pg_temp.batch_assert(has_function_privilege('authenticated','public.save_answers(uuid,jsonb)','EXECUTE'), 'authenticated execute granted');
  -- 50 answers need three calls, covering all four types and nullable fields.
  for chunk in 0..2 loop
    select jsonb_agg(jsonb_build_object('question_id',id,'revision',1,
      'option_id',case when pos<=30 then option_id end,
      'bool_answer',case when pos between 31 and 40 then false end,
      'text_answer',case when pos>=41 then 'answer' end) order by pos)
      into payload from batch_questions where pos between chunk*20+1 and least(chunk*20+20,50);
    receipt := pg_temp.batch_call(payload);
    perform pg_temp.batch_assert(jsonb_array_length(receipt)=least(20,50-chunk*20),'batch size '||chunk);
    perform pg_temp.batch_assert(not jsonb_path_exists(receipt,'$[*].is_correct')
      and not jsonb_path_exists(receipt,'$[*].points_awarded'),'no scoring leak '||chunk);
  end loop;
  perform pg_temp.batch_assert((select count(*)=50 from public.exam_answers where session_id=attempt),'50 rows saved');
  perform pg_temp.batch_call(payload);
  perform pg_temp.batch_assert((select count(*)=50 from public.exam_answers where session_id=attempt),'repeated batch upserts without duplicates');

  select id into choice_id from batch_questions where pos=1;
  select option_id into foreign_option from batch_questions where pos=2;
  select id into bool_id from batch_questions where pos=31;
  select id into text_id from batch_questions where pos=41;
  select id into essay_id from batch_questions where pos=49;
  mixed := jsonb_build_array(
    jsonb_build_object('question_id',choice_id,'revision',2,'option_id',foreign_option),
    jsonb_build_object('question_id',bool_id,'revision',2,'bool_answer',false),
    jsonb_build_object('question_id',text_id,'revision',2,'text_answer',''),
    jsonb_build_object('question_id',essay_id,'revision',2,'text_answer',repeat('x',10001)));
  receipt := pg_temp.batch_call(mixed);
  perform pg_temp.batch_assert(receipt->0->>'error_message'='Invalid option'
    and receipt->3->>'error_code'='22001','invalid option and oversized essay are isolated');
  perform pg_temp.batch_assert(receipt->1->>'saved_at' is not null and receipt->2->>'saved_at' is not null,
    'valid neighbors save despite invalid items');
  perform pg_temp.batch_assert((select bool_answer=false from public.exam_answers where session_id=attempt and question_id=bool_id), 'false preserved');
  perform pg_temp.batch_assert((select text_answer='' from public.exam_answers where session_id=attempt and question_id=text_id),'empty text preserved');
  perform pg_temp.batch_assert((select text_answer='answer' from public.exam_answers where session_id=attempt and question_id=essay_id),'rejected text leaves previous answer intact');
  receipt := pg_temp.batch_call(jsonb_build_array(jsonb_build_object('question_id',essay_id,'revision',3,'text_answer',repeat('x',10000))));
  perform pg_temp.batch_assert(receipt->0->>'saved_at' is not null,'10000 characters accepted');
  receipt := pg_temp.batch_call(jsonb_build_array(
    jsonb_build_object('question_id',choice_id,'revision',3,'option_id',null),
    jsonb_build_object('question_id',bool_id,'revision',3,'bool_answer',null),
    jsonb_build_object('question_id',text_id,'revision',3,'text_answer',null)));
  perform pg_temp.batch_assert((select count(*)=3 from public.exam_answers where session_id=attempt
    and question_id in (choice_id,bool_id,text_id) and option_id is null and bool_answer is null and text_answer is null),'cleared answers saved');
  perform pg_temp.batch_assert(receipt->0->>'revision'='3','local revision echoed');

  perform pg_temp.batch_reject('[]','22023','empty batch rejected');
  perform pg_temp.batch_reject('{}','22023','non-array rejected');
  perform pg_temp.batch_reject(jsonb_build_array(mixed->1,mixed->1),'22023','duplicate question rejected');
  perform pg_temp.batch_assert((select bool_answer is null from public.exam_answers where session_id=attempt and question_id=bool_id),'malformed batch does not change earlier answers');
  receipt := pg_temp.batch_call(jsonb_build_array(
    jsonb_build_object('question_id',gen_random_uuid(),'revision',1,'bool_answer',true),
    jsonb_build_object('question_id',bool_id,'revision',4,'bool_answer','false'),
    jsonb_build_object('question_id',text_id,'revision',4,'text_answer','Still valid')));
  perform pg_temp.batch_assert(receipt->0->>'error_message'='Question not found'
    and receipt->1->>'error_code'='22023' and receipt->2->>'saved_at' is not null,
    'unknown question and wrong JSON type do not block valid neighbor');
  perform pg_temp.batch_reject(jsonb_build_array(jsonb_build_object('question_id',bool_id,'revision',0)),'22023','invalid revision rejected');
  select jsonb_agg(jsonb_build_object('question_id',id,'revision',1)) into payload from batch_questions where pos<=21;
  perform pg_temp.batch_reject(payload,'22023','21 answers rejected');
  payload := jsonb_build_array(jsonb_build_object('question_id',bool_id,'revision',4,'bool_answer',true));
  perform pg_temp.batch_reject(payload,'P0001','another student session rejected',other_attempt);
  delete from public.verified_sessions where session_id=verified;
  perform pg_temp.batch_reject(payload,'42501','unverified student rejected');
  insert into public.verified_sessions(session_id,user_id) values(verified,student);
  update public.classes set archived_at=now() where id=classroom;
  perform pg_temp.batch_reject(payload,'42501','archived class rejected');
  update public.classes set archived_at=null where id=classroom;
  update public.class_members set status='removed' where class_id=classroom and student_id=student;
  perform pg_temp.batch_reject(payload,'42501','removed class access rejected');
  update public.class_members set status='active' where class_id=classroom and student_id=student;
  update public.exam_sessions set status='submitted' where id=attempt;
  perform pg_temp.batch_reject(payload,'P0001','submitted session rejected');
  update public.exam_sessions set status='in_progress',deadline_at=now()-interval '16 seconds' where id=attempt;
  perform pg_temp.batch_reject(payload,'P0001','expired grace rejected');
  update public.exam_sessions set deadline_at=now()-interval '15 seconds' where id=attempt;
  receipt := pg_temp.batch_call(payload);
  perform pg_temp.batch_assert(receipt->0->>'saved_at' is not null,'existing inclusive 15-second boundary preserved');
  perform set_config('request.jwt.claims','{}',true);
  perform pg_temp.batch_reject(payload,'P0001','unsigned caller rejected');
end $$;
rollback;
