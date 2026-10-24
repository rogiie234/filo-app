-- Additive answer batching; legacy save_answer remains unchanged.
begin;
create or replace function public.save_answers(p_session uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  s exam_sessions;
  item jsonb;
  ids uuid[] := '{}';
  question uuid;
  revision bigint;
  saved timestamptz;
  receipts jsonb := '[]';
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from exam_sessions
   where id = p_session and student_id = auth.uid() for update;
  if not found then raise exception 'Session not found'; end if;
  if not exists (select 1 from quizzes q where q.id = s.quiz_id
      and is_class_member(q.class_id) and class_is_open(q.class_id)) then
    raise exception 'Class access denied' using errcode = '42501';
  end if;
  if s.status <> 'in_progress' or now() > s.deadline_at + interval '15 seconds' then
    raise exception 'This attempt is closed';
  end if;
  if jsonb_typeof(p_answers) is distinct from 'array' then
    raise exception 'Answers must be an array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_answers) not between 1 and 20 then
    raise exception 'Send between 1 and 20 answers' using errcode = '22023';
  end if;
  -- Validate identities before writing so every item has a unique receipt.
  for item in select value from jsonb_array_elements(p_answers) loop
    if jsonb_typeof(item) is distinct from 'object'
       or jsonb_typeof(item->'question_id') is distinct from 'string'
       or jsonb_typeof(item->'revision') is distinct from 'number'
       or (item->>'revision') !~ '^[1-9][0-9]*$' then
      raise exception 'Invalid answer identity or revision' using errcode = '22023';
    end if;
    question := (item->>'question_id')::uuid;
    revision := (item->>'revision')::bigint;
    if question = any(ids) then
      raise exception 'Duplicate question in answer batch' using errcode = '22023';
    end if;
    ids := array_append(ids, question);
  end loop;
  for item in select value from jsonb_array_elements(p_answers) loop
    question := (item->>'question_id')::uuid;
    revision := (item->>'revision')::bigint;
    begin
      if coalesce(jsonb_typeof(item->'option_id'), 'null') not in ('string','null')
         or coalesce(jsonb_typeof(item->'bool_answer'), 'null') not in ('boolean','null')
         or coalesce(jsonb_typeof(item->'text_answer'), 'null') not in ('string','null') then
        raise exception 'Invalid answer payload' using errcode = '22023';
      end if;
      saved := public.save_answer(p_session, question, (item->>'option_id')::uuid,
        (item->>'bool_answer')::boolean, item->>'text_answer');
      receipts := receipts || jsonb_build_array(jsonb_build_object(
        'question_id',question,'revision',revision,'saved_at',saved));
    exception
      when sqlstate '22001' or sqlstate '22023' or sqlstate '22P02' then
        receipts := receipts || jsonb_build_array(jsonb_build_object(
          'question_id',question,'revision',revision,'error_code',sqlstate,
          'error_message',case when sqlstate='22001' then sqlerrm else 'Invalid answer payload' end));
      when raise_exception then
        -- Session/access failures abort the request, rolling back all items.
        if sqlerrm not in ('Question not found','Invalid option') then raise; end if;
        receipts := receipts || jsonb_build_array(jsonb_build_object(
          'question_id',question,'revision',revision,'error_code',sqlstate,'error_message',sqlerrm));
    end;
  end loop;
  return receipts;
end $$;
revoke all on function public.save_answers(uuid,jsonb) from public, anon;
grant execute on function public.save_answers(uuid,jsonb) to authenticated;
commit;
