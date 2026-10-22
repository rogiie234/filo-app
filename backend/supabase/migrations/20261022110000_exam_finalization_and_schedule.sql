-- M8-BE-02: normalize identification whitespace and keep expiry processing available.
begin;

create or replace function public.norm_text(t text) returns text
language sql immutable set search_path = public as $$
  select lower(btrim(regexp_replace(coalesce(t, ''), '[[:space:]]+', ' ', 'g')));
$$;

-- A verified app-open recovery path, never a client grant to the global worker.
create function public.finalize_accessible_exams() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  for r in
    select s.id from public.exam_sessions s
    join public.quizzes q on q.id=s.quiz_id
    where s.status='in_progress' and s.deadline_at + interval '15 seconds' < now()
      and q.deleted_at is null and public.class_is_open(q.class_id)
      and ((s.student_id=auth.uid() and public.is_class_member(q.class_id))
        or public.is_class_owner(q.class_id))
    order by s.id
  loop
    perform public.finalize_session(r.id, 'auto_submitted');
  end loop;
  for r in
    select q.id from public.quizzes q
    where q.status='published' and q.results_released_at is null
      and q.deleted_at is null and public.class_is_open(q.class_id)
      and (public.is_class_owner(q.class_id) or (public.is_class_member(q.class_id)
        and exists(select 1 from public.exam_sessions s
          where s.quiz_id=q.id and s.student_id=auth.uid())))
    order by q.id
  loop
    perform public.maybe_release_results(r.id);
  end loop;
end $$;
revoke all on function public.finalize_accessible_exams() from public, anon;
grant execute on function public.finalize_accessible_exams() to authenticated;

-- Supabase may require pg_cron to be enabled in the Dashboard first. Report a
-- missing extension explicitly; the scoped recovery path still deploys.
do $$
declare job_id bigint; r record;
begin
  if not exists(select 1 from pg_extension where extname='pg_cron') then
    begin
      create extension if not exists pg_cron;
    exception when others then
      raise warning 'pg_cron installation failed [%]: %. App-open finalization is deferred; unattended proof is pending.',
        sqlstate, sqlerrm;
    end;
  end if;
  if not exists(select 1 from pg_extension where extname='pg_cron') then
    return;
  end if;
  if exists(select 1 from cron.job where jobname='filo-finalize-exams'
      and username=current_user and database<>current_database()) then
    raise exception 'A same-name job belongs to another database; inspect it before scheduling';
  end if;
  -- Named scheduling replaces this job for the current database user.
  select cron.schedule('filo-finalize-exams', '* * * * *',
    'select public.finalize_expired_sessions()') into job_id;
  perform cron.alter_job(job_id, active := true);
  -- A previous owner may have created a duplicate under another username.
  for r in select jobid from cron.job
    where jobname='filo-finalize-exams' and jobid<>job_id and database=current_database()
  loop
    perform cron.unschedule(r.jobid);
  end loop;
  if (select count(*) from cron.job where jobname='filo-finalize-exams'
      and database=current_database() and active) <> 1 then
    raise exception 'Expected exactly one active filo-finalize-exams job';
  end if;
end $$;

commit;
