-- M8-BE-02 unattended proof, INSPECT. DEV, postgres. READS ONLY.
-- Requires pg_cron installed; job/extension queries provide proof context.
select name, default_version, installed_version from pg_available_extensions where name='pg_cron';
select extname, extversion from pg_extension where extname='pg_cron';

select jobid,jobname,schedule,command,active,database,username from cron.job
where jobname='filo-finalize-exams' order by jobid;
select d.jobid,d.runid,d.status,d.return_message,d.start_time,d.end_time
from cron.job_run_details d join cron.job j on j.jobid=d.jobid
where j.jobname='filo-finalize-exams' order by d.start_time desc limit 10;
-- This is real DEV work the active global job may finalize, not proof fixtures.
select id,quiz_id,deadline_at from public.exam_sessions
where status='in_progress' and deadline_at+interval '15 seconds'<now()
  and id<>'8b020000-0000-4000-8000-000000000006';

-- No get_result/get_my_session/submit/finalization calls: observing cannot pass
-- the test by doing the work. Re-run this file in a NEW query after waiting.
with proof as (
  select s.*,a.points_awarded,a.is_correct,q.results_released_at
  from public.exam_sessions s
  join public.quizzes q on q.id=s.quiz_id
  join public.exam_answers a on a.session_id=s.id
    and a.question_id='8b020000-0000-4000-8000-000000000005'
  where s.id='8b020000-0000-4000-8000-000000000006'
), evidence as (
  select p.*, (select count(*)=1 and bool_and(n.recipient_id=p.student_id
      and n.class_id=(select class_id from public.quizzes where id=p.quiz_id)
      and n.title='Results available' and n.target_type='quiz'
      and n.body='Results are available: M8-BE-02 CRON PROOF ONLY')
    from public.notifications n where n.target_id=p.quiz_id and n.type='results_released')
    as correct_release_inbox, exists(select 1 from cron.job_run_details d join cron.job j on j.jobid=d.jobid
    where j.jobname='filo-finalize-exams' and j.database=current_database()
      and j.active and j.schedule='* * * * *'
      and btrim(j.command,' ;')='select public.finalize_expired_sessions()'
      and d.status='succeeded' and d.start_time>p.deadline_at+interval '15 seconds'
      and d.end_time is not null) as successful_cron_after_expiry
  from proof p
)
select case when not exists(select 1 from evidence) then 'NO FIXTURE — run setup first'
  when exists(select 1 from evidence where status='auto_submitted' and submitted_at=deadline_at
    and auto_score=7 and essay_score=0 and total_score=7 and grading_complete
    and points_awarded=7 and is_correct and successful_cron_after_expiry
    and results_released_at>=deadline_at and correct_release_inbox) then 'PASS'
  when now()<=(select deadline_at+interval '2 minutes' from evidence) then 'WAIT — inspect again after inspect_after'
  else 'FAIL — inspect job history; do not finalize manually' end as unattended_overall,
  (select to_jsonb(e) from evidence e) as proof;
