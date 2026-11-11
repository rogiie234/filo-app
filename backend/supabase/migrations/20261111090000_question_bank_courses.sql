-- Existing questions have no reliable course provenance; retain them as unassigned.
begin;
alter table public.bank_questions
  add column course text,
  add column course_key text generated always as (lower(btrim(course))) stored,
  add constraint bank_question_course_valid check (
    course is null or (course = btrim(course) and char_length(course) between 1 and 120)
  );
-- Generated values are not available in BEFORE triggers; ignore only that derived key
-- when recognizing legacy soft-delete-only updates. Preserve all content validation.
create or replace function public.guard_bank_question() returns trigger
language plpgsql security definer set search_path = public as $$
declare p jsonb; opts jsonb; idx integer; n integer;
begin
  -- Soft deletion must still work for pre-migration legacy shapes.
  if tg_op='UPDATE' and (to_jsonb(new)-'deleted_at'-'updated_at'-'course_key') =
     (to_jsonb(old)-'deleted_at'-'updated_at'-'course_key') then return new; end if;
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

create index bank_questions_owner_course_idx
  on public.bank_questions(owner_id, course_key, created_at desc, id)
  where deleted_at is null;
comment on column public.bank_questions.course is
  'Instructor course grouping. Legacy null entries require explicit assignment; not an access-control boundary.';
commit;
