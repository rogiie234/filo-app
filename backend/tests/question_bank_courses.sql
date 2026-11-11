-- OWNER ONLY: DEV SQL Editor as postgres, after 20261111090000 migration.
-- Uses a temporary clone; never inserts into or edits real bank/profile rows.
begin;
create temporary table bank_course_fixture
  (like public.bank_questions including defaults including generated including constraints)
  on commit drop;
-- Seed a historical shape before attaching the current validation trigger.
insert into bank_course_fixture(id,owner_id,type,prompt,options,course)
values ('00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000002',
        'multiple_choice','Legacy fixture','{}','Course');
create trigger bank_course_fixture_guard before insert or update on bank_course_fixture
for each row execute function public.guard_bank_question();
-- Must bypass legacy content validation for a deletion-only update despite generated key.
update bank_course_fixture set deleted_at=now();
do $$
begin
  if not exists(select 1 from bank_course_fixture where deleted_at is not null and course_key='course') then
    raise exception 'Legacy soft deletion or normalized key failed';
  end if;
  insert into bank_course_fixture(owner_id,type,prompt,course)
  values ('00000000-0000-0000-0000-000000000002','essay','Valid fixture','Course A');
  if not exists(select 1 from bank_course_fixture where course_key='course a') then
    raise exception 'Course normalization failed';
  end if;
  begin
    insert into bank_course_fixture(owner_id,type,prompt,course)
    values ('00000000-0000-0000-0000-000000000002','essay','Invalid course',' ');
    raise exception 'Blank course was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into bank_course_fixture(owner_id,type,prompt,course)
    values ('00000000-0000-0000-0000-000000000002','essay','Invalid course',repeat('x',121));
    raise exception 'Overlong course was accepted';
  exception when check_violation then null;
  end;
end $$;
select 'PASS: normalized courses, course limits and legacy soft deletion' as result;
rollback;
