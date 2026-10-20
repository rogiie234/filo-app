-- M7 corrective migration: remove children while the question is still visible.
-- The lifecycle guard resolves option/key class through questions. A bare FK
-- cascade runs after the parent row disappears and therefore refuses the write.
-- Keep all ownership/class/lock checks; do not bypass the shared lifecycle guard.
begin;
create or replace function public.guard_question_edits() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.lock_quiz_content(array[new.quiz_id]);
  elsif tg_op = 'DELETE' then
    perform public.lock_quiz_content(array[old.quiz_id]);
    -- BEFORE DELETE: parent remains visible to child RLS and lifecycle guards.
    -- Remove the key first so deleting options cannot issue SET NULL on that key.
    -- Any failure rolls back the entire parent DELETE, including these children.
    delete from public.answer_keys where question_id=old.id;
    delete from public.question_options where question_id=old.id;
  else
    perform public.lock_quiz_content(array[old.quiz_id,new.quiz_id]);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke all on function public.guard_question_edits() from public, anon, authenticated;
commit;
