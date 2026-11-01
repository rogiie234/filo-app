-- DEV ONLY: run WHOLE file as postgres after 20261101120000.
-- Executes the scheduled command under rollback; never remove ROLLBACK.
-- On any error, run ROLLBACK separately and report the first error.
begin;
create temporary table retention_results(test text, result text) on commit drop;
create function pg_temp.retention_check(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is not true then raise exception 'FAIL: %', label; end if;
  insert into retention_results values(label, 'PASS');
end $$;
do $$
declare
  u uuid := gen_random_uuid();
  ids uuid[] := array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  token uuid := gen_random_uuid();
  command text;
  token_before jsonb;
  setting_before jsonb;
  recent_before jsonb;
begin
  perform pg_temp.retention_check((select count(*)=1 from cron.job
    where jobname='filo-purge-notifications' and active and schedule='15 4 * * *'),
    'one active daily notification job');
  select j.command into strict command from cron.job j where jobname='filo-purge-notifications';
  perform pg_temp.retention_check(command =
    ' delete from public.notifications where created_at < now() - interval ''90 days'' ',
    'scheduled command is the strict 90-day created_at predicate');
  insert into auth.users(id) values(u);
  insert into public.profiles(id,role,display_name) values(u,'instructor','Retention fixture');
  insert into public.device_tokens(id,user_id,fcm_token,device_hash)
    values(token,u,gen_random_uuid()::text,repeat('a',64));
  insert into public.notification_settings(user_id,type,enabled) values(u,'announcement',false);
  insert into public.notifications(id,recipient_id,type,title,created_at,read_at) values
    (ids[1],u,'announcement','Retention fixture',now()-interval '91 days',null),
    (ids[2],u,'announcement','Retention fixture',now()-interval '90 days 1 microsecond',now()),
    (ids[3],u,'announcement','Retention fixture',now()-interval '90 days',null),
    (ids[4],u,'announcement','Retention fixture',now()-interval '1 day',now());
  insert into public.push_deliveries(notification_id,token_id,status)
    values(ids[1],token,'sent'),(ids[4],token,'sent');
  select to_jsonb(t) into token_before from public.device_tokens t where id=token;
  select to_jsonb(s) into setting_before from public.notification_settings s where user_id=u;
  select to_jsonb(n) into recent_before from public.notifications n where id=ids[4];

  execute command;
  perform pg_temp.retention_check(not exists(select 1 from public.notifications where id=any(ids[1:2])),
    'old read and unread rows removed');
  perform pg_temp.retention_check(exists(select 1 from public.notifications where id=ids[3]),
    'exact 90-day boundary retained');
  perform pg_temp.retention_check((select to_jsonb(n)=recent_before from public.notifications n where id=ids[4]),
    'recent read row retained unchanged');
  perform pg_temp.retention_check(not exists(select 1 from public.push_deliveries where notification_id=ids[1]),
    'expired delivery ledger cascades');
  perform pg_temp.retention_check(exists(select 1 from public.push_deliveries where notification_id=ids[4]),
    'recent delivery ledger retained');
  perform pg_temp.retention_check((select to_jsonb(t)=token_before from public.device_tokens t where id=token),
    'device registration unchanged');
  perform pg_temp.retention_check((select to_jsonb(s)=setting_before from public.notification_settings s where user_id=u),
    'notification setting unchanged');
  execute command;
  perform pg_temp.retention_check((select count(*)=2 from public.notifications where recipient_id=u),
    'repeat cleanup preserves retained rows');
end $$;
select * from retention_results;
select count(*) as passed, 0 as failed, 'PASS' as overall from retention_results;
rollback;
