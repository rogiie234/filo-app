-- M7-BE-02/03. M7-SA-01 owner accepted bank retention and started-quiz delete protection.
begin;

create or replace function public.guard_started_quiz_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and old.locked_at is not null
     and new.deleted_at is distinct from old.deleted_at then
    raise exception 'A started quiz cannot be deleted' using errcode = '22023';
  end if;
  return new;
end $$;
create trigger trg_guard_started_quiz_delete before update on public.quizzes
for each row execute function public.guard_started_quiz_delete();
revoke all on function public.guard_started_quiz_delete() from public, anon, authenticated;

-- Shared strict validation for atomic saves and stored bank content.
create or replace function public.validate_question_payload(p jsonb) returns void
language plpgsql set search_path = public as $$
declare t text; n integer; v jsonb;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'Question must be an object' using errcode='22023';
  end if;
  t := p->>'type';
  if t is null or t not in ('multiple_choice','true_false','identification','essay') then
    raise exception 'Invalid question type' using errcode='22023';
  end if;
  if jsonb_typeof(p->'prompt') is distinct from 'string'
     or not ((p->>'prompt') ~ '[^[:space:]]') or length(p->>'prompt')>1000 then
    raise exception 'Prompt must contain 1 to 1000 characters' using errcode='22023';
  end if;
  if p ? 'explanation' and p->'explanation' <> 'null'::jsonb and (
    jsonb_typeof(p->'explanation') <> 'string' or length(p->>'explanation')>500) then
    raise exception 'Explanation must be at most 500 characters' using errcode='22023';
  end if;
  if jsonb_typeof(p->'points') is distinct from 'number' then
    raise exception 'Points must be an integer from 1 to 1000' using errcode='22023';
  end if;
  if (p->>'points')::numeric <> trunc((p->>'points')::numeric)
     or (p->>'points')::numeric not between 1 and 1000 then
    raise exception 'Points must be an integer from 1 to 1000' using errcode='22023';
  end if;
  if jsonb_typeof(p->'position') is distinct from 'number' then
    raise exception 'Position must be a nonnegative integer' using errcode='22023';
  end if;
  if (p->>'position')::numeric <> trunc((p->>'position')::numeric)
     or (p->>'position')::numeric not between 0 and 2147483647 then
    raise exception 'Position must be a nonnegative integer' using errcode='22023';
  end if;
  if t='multiple_choice' then
    if jsonb_typeof(p->'options') is distinct from 'array' then
      raise exception 'Provide 2 to 10 options' using errcode='22023';
    end if;
    n := jsonb_array_length(p->'options');
    if n not between 2 and 10 then
      raise exception 'Provide 2 to 10 options' using errcode='22023';
    end if;
    for v in select value from jsonb_array_elements(p->'options') loop
      if jsonb_typeof(v) <> 'string' or not ((v #>> '{}') ~ '[^[:space:]]') or length(v #>> '{}')>500 then
        raise exception 'Each option must contain 1 to 500 characters' using errcode='22023';
      end if;
    end loop;
    if jsonb_typeof(p->'correct_option_index') is distinct from 'number' then
      raise exception 'Choose one correct option' using errcode='22023';
    end if;
    if (p->>'correct_option_index')::numeric <> trunc((p->>'correct_option_index')::numeric)
       or (p->>'correct_option_index')::numeric not between 0 and n-1 then
      raise exception 'Choose one correct option' using errcode='22023';
    end if;
  elsif t='true_false' then
    if jsonb_typeof(p->'correct_boolean') is distinct from 'boolean' then
      raise exception 'Choose true or false' using errcode='22023';
    end if;
  elsif t='identification' then
    if jsonb_typeof(p->'accepted_answers') is distinct from 'array' then
      raise exception 'Provide 1 to 10 accepted answers' using errcode='22023';
    end if;
    if jsonb_array_length(p->'accepted_answers') not between 1 and 10 then
      raise exception 'Provide 1 to 10 accepted answers' using errcode='22023';
    end if;
    for v in select value from jsonb_array_elements(p->'accepted_answers') loop
      if jsonb_typeof(v) <> 'string' or not ((v #>> '{}') ~ '[^[:space:]]') then
        raise exception 'Accepted answers must be nonblank text' using errcode='22023';
      end if;
    end loop;
  end if;
end $$;
revoke all on function public.validate_question_payload(jsonb) from public, anon, authenticated;

create or replace function public.require_editable_quiz(p_quiz uuid) returns void
language plpgsql security definer set search_path = public as $$
declare q quizzes;
begin
  if not current_user_ok() or not exists(select 1 from profiles where id=auth.uid() and role='instructor') then
    raise exception 'Not allowed' using errcode='42501';
  end if;
  select * into q from quizzes where id=p_quiz for update;
  if not found or not is_class_owner(q.class_id) or q.deleted_at is not null
     or not class_is_open(q.class_id) then
    raise exception 'Quiz is inaccessible or read-only' using errcode='42501';
  end if;
  if q.locked_at is not null then
    raise exception 'This quiz has already been started by a student' using errcode='22023';
  end if;
end $$;
revoke all on function public.require_editable_quiz(uuid) from public, anon, authenticated;

create or replace function public.save_question(p_quiz uuid, p_question jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qid uuid; oid uuid; ids uuid[] := '{}'; correct_id uuid;
  opt record; t question_type; accepted text[];
begin
  perform require_editable_quiz(p_quiz);
  perform validate_question_payload(p_question);
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
    update questions set type=t, prompt=p_question->>'prompt',
      points=(p_question->>'points')::numeric::integer, explanation=p_question->>'explanation',
      position=(p_question->>'position')::numeric::integer where id=qid;
    delete from answer_keys where question_id=qid;
    delete from question_options where question_id=qid;
  else
    insert into questions(quiz_id,type,prompt,points,explanation,position)
      values(p_quiz,t,p_question->>'prompt',(p_question->>'points')::numeric::integer,
        p_question->>'explanation',(p_question->>'position')::numeric::integer)
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

create or replace function public.reorder_questions(p_quiz uuid, p_ordered_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform require_editable_quiz(p_quiz);
  if p_ordered_ids is null or coalesce(array_ndims(p_ordered_ids),1)<>1
     or exists(select 1 from unnest(p_ordered_ids) x where x is null)
     or cardinality(p_ordered_ids)<>(select count(distinct x) from unnest(p_ordered_ids) x)
     or cardinality(p_ordered_ids)<>(select count(*) from questions where quiz_id=p_quiz)
     or exists(select 1 from unnest(p_ordered_ids) x where not exists(
       select 1 from questions where id=x and quiz_id=p_quiz)) then
    raise exception 'Provide every question id exactly once' using errcode='22023';
  end if;
  update questions q set position=u.ord-1
    from unnest(p_ordered_ids) with ordinality u(id,ord)
    where q.id=u.id and q.quiz_id=p_quiz;
end $$;
revoke all on function public.reorder_questions(uuid,uuid[]) from public, anon, authenticated;
grant execute on function public.reorder_questions(uuid,uuid[]) to authenticated;

-- Bank tombstones remain readable by their owner for sync. No hard client deletion.
drop policy bank_own on public.bank_questions;
create policy bank_own on public.bank_questions for all to authenticated
using (current_user_ok() and owner_id=auth.uid() and exists(
  select 1 from profiles where id=auth.uid() and role='instructor'))
with check (current_user_ok() and owner_id=auth.uid() and exists(
  select 1 from profiles where id=auth.uid() and role='instructor'));
revoke delete on public.bank_questions from authenticated;

create or replace function public.guard_bank_question() returns trigger
language plpgsql security definer set search_path = public as $$
declare p jsonb; opts jsonb; idx integer; n integer;
begin
  -- Soft deletion must still work for pre-migration legacy shapes.
  if tg_op='UPDATE' and (to_jsonb(new)-'deleted_at'-'updated_at') =
     (to_jsonb(old)-'deleted_at'-'updated_at') then return new; end if;
  p := jsonb_build_object('type',new.type,'prompt',new.prompt,'points',new.points,
    'explanation',new.explanation,'position',0);
  if new.type='multiple_choice' then
    if jsonb_typeof(new.options) is distinct from 'array' then
      raise exception 'Bank options must be an array' using errcode='22023';
    end if;
    if exists(select 1 from jsonb_array_elements(new.options) x where
      jsonb_typeof(x) is distinct from 'object' or jsonb_typeof(x->'text') is distinct from 'string'
      or jsonb_typeof(x->'is_correct') is distinct from 'boolean') then
      raise exception 'Bank options require text and a correct flag' using errcode='22023';
    end if;
    select jsonb_agg(x->'text' order by ord), count(*) filter(where (x->>'is_correct')::boolean),
      min(ord-1) filter(where (x->>'is_correct')::boolean)
      into opts,n,idx from jsonb_array_elements(new.options) with ordinality u(x,ord);
    if n<>1 then raise exception 'Choose one correct option' using errcode='22023'; end if;
    p := p || jsonb_build_object('options',opts,'correct_option_index',idx);
  elsif new.type='true_false' then
    p := p || jsonb_build_object('correct_boolean',new.answer->'boolean');
  elsif new.type='identification' then
    p := p || jsonb_build_object('accepted_answers',new.answer->'accepted');
  end if;
  perform validate_question_payload(p);
  -- Keep only fields used by the selected type; copies never inherit stale keys.
  if new.type='multiple_choice' then new.answer:=null;
  elsif new.type in ('true_false','identification') then new.options:=null;
  else new.options:=null; new.answer:=null; end if;
  return new;
end $$;
create trigger trg_guard_bank_question before insert or update on public.bank_questions
for each row execute function public.guard_bank_question();
revoke all on function public.guard_bank_question() from public, anon, authenticated;
commit;
