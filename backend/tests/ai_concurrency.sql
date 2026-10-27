-- M10-BE-02 DEV ONLY. Run labeled blocks separately as postgres; NOT the whole file.
-- Reserved synthetic user has no auth account and is used only by this procedure.
-- A: start in terminal/editor 1; while sleep is running, start B in terminal/editor 2.
begin;
do $$ begin
  if exists(select 1 from public.ai_usage_log where user_id='a10be002-0000-4000-8000-000000000001') then
    raise exception 'Fixture collision: inspect existing rows before continuing';
  end if;
end $$;
set local role service_role;
select public.begin_ai_request('a10be002-0000-4000-8000-000000000001','generate_quiz') as acquired_id;
select pg_sleep(15);
commit;

-- B: run WHILE A sleeps. Expect lock wait, then refused_id NULL, one row.
begin;
set local role service_role;
select public.begin_ai_request('a10be002-0000-4000-8000-000000000001','generate_quiz') as refused_id;
reset role;
select count(*)=1 and bool_and(status='started') as only_one_acquired
from public.ai_usage_log where user_id='a10be002-0000-4000-8000-000000000001';
commit;

-- C: run after A and B complete; capture output, then remove only this fixture.
select public.finish_ai_request(id,'success') from public.ai_usage_log
where user_id='a10be002-0000-4000-8000-000000000001';
select id,status,error_code,created_at,finished_at from public.ai_usage_log
where user_id='a10be002-0000-4000-8000-000000000001';
delete from public.ai_usage_log where user_id='a10be002-0000-4000-8000-000000000001';
select count(*)=0 as fixtures_removed from public.ai_usage_log
where user_id='a10be002-0000-4000-8000-000000000001';
