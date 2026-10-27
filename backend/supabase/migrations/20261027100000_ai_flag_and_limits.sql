-- M10-BE-02: atomic AI provenance; keep the existing RPC signature.
begin;

create or replace function public.save_question(p_quiz uuid, p_question jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qid uuid; oid uuid; ids uuid[] := '{}'; correct_id uuid;
  opt record; t question_type; accepted text[];
begin
  perform require_editable_quiz(p_quiz);
  perform validate_question_payload(p_question);
  if p_question ? 'ai_generated' and jsonb_typeof(p_question->'ai_generated') is distinct from 'boolean' then
    raise exception 'ai_generated must be a boolean' using errcode='22023';
  end if;
  begin
    qid := nullif(p_question->>'id','')::uuid;
  exception when invalid_text_representation then
    raise exception 'Invalid question id' using errcode='22023';
  end;
  t := (p_question->>'type')::question_type;
  if qid is not null then
    if not exists(select 1 from questions where id=qid and quiz_id=p_quiz) then
      raise exception 'Question does not belong to this quiz' using errcode='22023';
    end if;
    update questions set ai_generated=ai_generated or coalesce((p_question->>'ai_generated')::boolean,false), type=t, prompt=p_question->>'prompt',
      points=(p_question->>'points')::numeric::integer, explanation=p_question->>'explanation',
      position=(p_question->>'position')::numeric::integer where id=qid;
    delete from answer_keys where question_id=qid;
    delete from question_options where question_id=qid;
  else
    insert into questions(quiz_id,type,prompt,points,explanation,position,ai_generated)
      values(p_quiz,t,p_question->>'prompt',(p_question->>'points')::numeric::integer,
        p_question->>'explanation',(p_question->>'position')::numeric::integer,
        coalesce((p_question->>'ai_generated')::boolean,false))
      returning id into qid;
  end if;
  if t='multiple_choice' then
    for opt in select value, ordinality from jsonb_array_elements_text(p_question->'options') with ordinality loop
      insert into question_options(question_id,position,text)
        values(qid,opt.ordinality-1,opt.value) returning id into oid;
      ids := array_append(ids,oid);
      if opt.ordinality-1=(p_question->>'correct_option_index')::numeric then correct_id:=oid; end if;
    end loop;
    insert into answer_keys(question_id,correct_option_id) values(qid,correct_id);
  elsif t='true_false' then
    insert into answer_keys(question_id,correct_boolean) values(qid,(p_question->>'correct_boolean')::boolean);
  elsif t='identification' then
    select array_agg(value order by ordinality) into accepted
      from jsonb_array_elements_text(p_question->'accepted_answers') with ordinality;
    insert into answer_keys(question_id,accepted_answers) values(qid,accepted);
  end if;
  return jsonb_build_object('question_id',qid,'option_ids',to_jsonb(ids));
end $$;
revoke all on function public.save_question(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.save_question(uuid,jsonb) to authenticated;

commit;
