-- M10-BE-02 DEV ONLY. Run blocks separately as postgres; NOT the whole file.
-- SETUP: capture job details and next scheduled time; do not reschedule the shared job.
select jobid,jobname,schedule,command,active from cron.job where jobname='filo-purge-ai-log';
select current_setting('cron.timezone',true) as cron_timezone; -- pg_cron defaults to GMT if unset.
begin;
do $$ begin
  if exists(select 1 from public.ai_usage_log where user_id='a10be002-0000-4000-8000-000000000002'
    or id in ('a10be002-0000-4000-8000-000000000003','a10be002-0000-4000-8000-000000000004')) then
    raise exception 'Fixture collision: inspect existing rows before continuing';
  end if;
end $$;
insert into public.ai_usage_log(id,user_id,kind,status,created_at,finished_at) values
('a10be002-0000-4000-8000-000000000003','a10be002-0000-4000-8000-000000000002','generate_quiz','success',now()-interval '31 days',now()-interval '31 days'),
('a10be002-0000-4000-8000-000000000004','a10be002-0000-4000-8000-000000000002','generate_quiz','success',now(),now());
commit;

-- INSPECT: after the NEXT daily tick (03:15 in cron timezone), within 30 days of setup.
-- Expect old_removed=true, recent_retained=true, scheduled_success=true.
select not exists(select 1 from public.ai_usage_log where id='a10be002-0000-4000-8000-000000000003') as old_removed,
 exists(select 1 from public.ai_usage_log where id='a10be002-0000-4000-8000-000000000004') as recent_retained,
 exists(select 1 from cron.job_run_details d join cron.job j on j.jobid=d.jobid
   where j.jobname='filo-purge-ai-log' and d.status='succeeded'
     and d.start_time >= (select created_at from public.ai_usage_log where id='a10be002-0000-4000-8000-000000000004')) as scheduled_success;
select d.jobid,d.runid,d.status,d.return_message,d.start_time,d.end_time
from cron.job_run_details d join cron.job j on j.jobid=d.jobid
where j.jobname='filo-purge-ai-log' order by d.start_time desc limit 5;

-- CLEANUP: only after recording evidence; also use this if abandoning the check.
delete from public.ai_usage_log where user_id='a10be002-0000-4000-8000-000000000002'
  and id in ('a10be002-0000-4000-8000-000000000003','a10be002-0000-4000-8000-000000000004');
select count(*)=0 as fixtures_removed from public.ai_usage_log
where user_id='a10be002-0000-4000-8000-000000000002';
