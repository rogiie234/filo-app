-- M12-BE-03: daily inbox retention; owner applies after reviewing DEV history.
begin;
create index idx_notifications_created_at on public.notifications(created_at);

-- Named scheduling updates this job if the statement is reapplied.
-- pg_cron uses UTC in this deployment: 12:15 Asia/Manila.
select cron.schedule(
  'filo-purge-notifications', '15 4 * * *',
  $$ delete from public.notifications where created_at < now() - interval '90 days' $$);
commit;
