-- OWNER ONLY: disposable DEV after 20261111110000. Temp clones only; rollback.
begin;
create temporary table purge_classes(id uuid primary key,deleted_at timestamptz,purge_requested_at timestamptz);
create temporary table purge_attempts(class_id uuid primary key,attempted_at timestamptz not null);
do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.claim_deleted_class_purges()'::regprocedure);
  definition:=replace(definition,'public.claim_deleted_class_purges()', 'pg_temp.claim_deleted_class_purges()');
  definition:=replace(definition,'public.classes','pg_temp.purge_classes');
  definition:=replace(definition,'public.class_purge_attempts','pg_temp.purge_attempts');
  execute definition;
end $$;
insert into purge_classes
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,now()-interval '15 days',null
from generate_series(1,26) i;
-- Live classes and recent recoverable classes must never be selected.
insert into purge_classes values(gen_random_uuid(),null,null),(gen_random_uuid(),now(),null),
  ('ffffffff-ffff-ffff-ffff-ffffffffffff',now(),now());
do $$
declare first_ids uuid[]; next_ids uuid[];
begin
  select array_agg(id) into first_ids from pg_temp.claim_deleted_class_purges();
  if cardinality(first_ids)<>25 then raise exception 'Expected bounded 25-class batch'; end if;
  -- Simulate every selected class failing: leave all class rows intact.
  select array_agg(id) into next_ids from pg_temp.claim_deleted_class_purges();
  if not ('00000000-0000-0000-0000-000000000026'::uuid=any(next_ids)) then
    raise exception 'Unattempted class starved behind failed batch';
  end if;
  if not ('ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid=any(next_ids)) then
    raise exception 'Explicit permanent deletion not selected';
  end if;
  if exists(select 1 from purge_attempts a join purge_classes c on c.id=a.class_id
    where c.deleted_at is null or (c.deleted_at>now()-interval '14 days' and c.purge_requested_at is null)) then
    raise exception 'Ineligible class claimed';
  end if;
  if has_function_privilege('authenticated','public.claim_deleted_class_purges()','execute')
    or has_function_privilege('anon','public.claim_deleted_class_purges()','execute') then
    raise exception 'Purge claim must remain service-only';
  end if;
end $$;
select 'PASS: failed batch rotates; live/recoverable classes excluded; service-only claim' as result;
rollback;
