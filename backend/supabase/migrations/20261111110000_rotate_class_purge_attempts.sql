-- Separate retry metadata avoids changing deleted-class content/owner guards.
begin;
create table public.class_purge_attempts (
  class_id uuid primary key references public.classes(id) on delete cascade,
  attempted_at timestamptz not null
);
alter table public.class_purge_attempts enable row level security;
revoke all on public.class_purge_attempts from public, anon, authenticated;
grant select, insert, update, delete on public.class_purge_attempts to service_role;

create function public.claim_deleted_class_purges()
returns table(id uuid) language sql security definer set search_path='' as $$
  with candidates as materialized (
    select c.id, a.attempted_at
    from public.classes c left join public.class_purge_attempts a on a.class_id=c.id
    where c.deleted_at is not null
      and (c.deleted_at < now()-interval '14 days' or c.purge_requested_at is not null)
    order by a.attempted_at nulls first, c.deleted_at, c.id
    limit 25 for update of c skip locked
  ), claimed as (
    insert into public.class_purge_attempts(class_id,attempted_at)
    select c.id,clock_timestamp() from candidates c
    on conflict(class_id) do update set attempted_at=excluded.attempted_at
    returning class_id
  )
  select c.id from candidates c join claimed a on a.class_id=c.id
  order by c.attempted_at nulls first,c.id;
$$;
revoke all on function public.claim_deleted_class_purges() from public,anon,authenticated;
grant execute on function public.claim_deleted_class_purges() to service_role;
commit;
