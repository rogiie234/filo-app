-- M12-BE-04 / DEV ONLY / postgres. Select ONE numbered block at a time.
-- This is a committed live test, NOT rollback acceptance. Never run whole file.
-- Use new private class/post UUIDs per run; replace NULL IDs in selected blocks.
-- Do not paste tokens/secrets here. Keep the edited roster/IDs outside Git.
do $$ begin raise exception 'Select one numbered block; never run whole push_burst.sql'; end $$;

-- 1. SETUP. Set instructor, class and post UUIDs; supply 40 existing TEST students.
-- No account creation/token transfer. Setup itself does not insert a post.
begin;
do $$
declare
  owner uuid := null;
  room uuid := null;
  post uuid := null;
  roster uuid[] := array[]::uuid[];
begin
  if owner is null or room is null or post is null or room=post
    or cardinality(roster)<>40 or owner=any(roster)
    or (select count(distinct x) from unnest(roster) x)<>40 then
    raise exception 'Supply new class/post IDs, one instructor and 40 distinct test students';
  end if;
  if not exists(select 1 from public.profiles where id=owner and role='instructor' and deleted_at is null)
    or (select count(*) from public.profiles where id=any(roster) and role='student' and deleted_at is null)<>40 then
    raise exception 'All fixture accounts must already exist with the expected roles';
  end if;
  if exists(select 1 from public.classes where id=room)
    or exists(select 1 from public.posts where id=post) then
    raise exception 'Fixture ID collision; use new IDs, do not delete existing data';
  end if;
  insert into public.classes(id,owner_id,course,section,school_year)
    values(room,owner,'M12-BE-04 push burst '||post::text,'M12-BE-04','DEV');
  insert into public.class_members(class_id,student_id,status)
    select room,x,'active' from unnest(roster) x;
end $$;
commit;

-- 2. READ-ONLY PREFLIGHT. Set room. Expected 40 active/eligible, 40 phones,
-- zero muted. Token presence cannot prove current Firebase validity/phone receipt.
with params as (select null::uuid as room), members as (
  select m.student_id from public.class_members m,params p
  where m.class_id=p.room and m.status='active'
)
select count(*) as active_recipients,
  count(*) filter(where p.role='student' and p.deleted_at is null) as eligible_students,
  (select count(*) from public.device_tokens t join members m on m.student_id=t.user_id) as registered_phones,
  count(*) filter(where exists(select 1 from public.notification_settings s
    where s.user_id=m.student_id and s.type='announcement' and not s.enabled
      and (s.class_id is null or s.class_id=(select room from params)))) as muted_recipients
from members m join public.profiles p on p.id=m.student_id;
-- Inspect ALL custom wrappers to rule out duplicate dispatch; do not print tgargs.
select t.tgname,t.tgenabled,p.proname
from pg_trigger t join pg_proc p on p.oid=t.tgfoid
where t.tgrelid='public.notifications'::regclass and not t.tgisinternal;

-- 3. EVENT. Only after owner confirms DEV, 40 test-owned valid registrations,
-- one dispatcher, deployment/secrets and baseline quota. Set room/post IDs.
-- Repeats preflight atomically; COMMIT launches the normal async webhook burst.
begin;
do $$
declare room uuid := null; post uuid := null; owner uuid; total integer;
  dev_targets_confirmed boolean := false;
begin
  if not dev_targets_confirmed then
    raise exception 'Confirm DEV, test-owned valid FCM targets and baseline usage, then set confirmation true';
  end if;
  if room is null or post is null then raise exception 'Supply this run class/post IDs'; end if;
  select owner_id into owner from public.classes where id=room
    and course='M12-BE-04 push burst '||post::text and section='M12-BE-04' and school_year='DEV'
    and deleted_at is null and archived_at is null for update;
  if not found then raise exception 'Dedicated run class not found'; end if;
  if not exists(select 1 from public.profiles where id=owner and role='instructor' and deleted_at is null) then
    raise exception 'Test instructor is unavailable';
  end if;
  if exists(select 1 from public.posts where class_id=room)
    or exists(select 1 from public.posts where id=post) then
    raise exception 'Run already used; inspect it, never resend automatically';
  end if;
  if (select count(*) from public.class_members where class_id=room)<>40
    or (select count(*) from public.class_members m join public.profiles p on p.id=m.student_id
      where m.class_id=room and m.status='active' and p.role='student' and p.deleted_at is null)<>40 then
    raise exception 'Require exactly 40 active eligible test recipients';
  end if;
  if exists(select 1 from public.class_members m where m.class_id=room and
      (select count(*) from public.device_tokens t where t.user_id=m.student_id)<>1)
    or (select count(distinct t.fcm_token) from public.device_tokens t
      join public.class_members m on m.student_id=t.user_id where m.class_id=room)<>40 then
    raise exception 'Require one distinct registered phone per recipient';
  end if;
  if exists(select 1 from public.notification_settings s join public.class_members m on m.student_id=s.user_id
    where m.class_id=room and s.type='announcement' and not s.enabled
      and (s.class_id is null or s.class_id=room)) then
    raise exception 'Muted recipient; do not change existing settings for the burst';
  end if;
  select count(*) into total from pg_trigger t join pg_proc p on p.oid=t.tgfoid
    where t.tgrelid='public.notifications'::regclass and not t.tgisinternal
      and p.proname in ('dispatch_notification_push','http_request');
  if total<>1 or not exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
    where t.tgrelid='public.notifications'::regclass and t.tgenabled='O'
      and p.proname='dispatch_notification_push') then
    raise exception 'Require one enabled canonical push webhook; inspect custom wrappers separately';
  end if;
  if (select count(*) from pg_trigger t join pg_proc p on p.oid=t.tgfoid
    where t.tgrelid='public.posts'::regclass and t.tgenabled='O'
      and p.proname='notify_new_post')<>1 then
    raise exception 'Require the existing announcement notification trigger';
  end if;
  insert into public.posts(id,class_id,author_id,kind,title,body)
    values(post,room,owner,'announcement','M12-BE-04 synthetic burst','Controlled DEV delivery test');
  if (select count(*) from public.notifications where class_id=room)<>40
    or (select count(distinct recipient_id) from public.notifications
      where class_id=room and target_type='post' and target_id=post)<>40 then
    raise exception 'Expected 40 event inbox rows; rolling back before webhook dispatch';
  end if;
end $$;
commit;

-- 4. MEASURE. Set room/post. Poll manually, stop observing at five minutes.
-- event_at is server post.created_at (transaction timestamp), not a commit clock.
-- Timing includes enqueue/claim/provider/store; accepted != physical receipt.
with params as (select null::uuid as room,null::uuid as post), event as (
  select p.id,p.created_at from public.posts p,params x
  where p.id=x.post and p.class_id=x.room
), inbox as (
  select n.* from public.notifications n,params p
  where n.class_id=p.room and n.target_type='post' and n.target_id=p.post
), ledger as (
  select d.* from public.push_deliveries d join inbox n on n.id=d.notification_id
), timings as (
  select extract(epoch from (d.finished_at-e.created_at))*1000 as ms
  from ledger d cross join event e where d.finished_at is not null
)
select e.id as post_id,e.created_at as event_at,clock_timestamp() as observed_at,
  40 as expected_recipients,(select count(*) from inbox) as inbox_rows,
  (select count(distinct recipient_id) from inbox) as inbox_recipients,
  (select count(*) from ledger) as delivery_claims,
  (select count(*) from ledger where status='sent') as firebase_accepted,
  (select count(*) from ledger where status='invalid_token') as invalid_tokens,
  (select count(*) from ledger where status='failed') as failed,
  (select count(*) from ledger where status<>'claimed' and finished_at is not null) as terminal_records,
  (select count(*) from ledger where status='claimed' or finished_at is null) as unfinished,
  (select count(distinct m.student_id) from public.class_members m,params p
    where m.class_id=p.room and not exists(select 1 from inbox n join ledger d on d.notification_id=n.id
      where n.recipient_id=m.student_id)) as recipients_without_delivery,
  (select count(*) from ledger where error_code is not null) as recorded_errors,
  (select min(ms) from timings) as min_completion_ms,
  (select percentile_cont(0.5) within group(order by ms) from timings) as median_completion_ms,
  (select percentile_cont(0.95) within group(order by ms) from timings) as p95_completion_ms,
  (select max(ms) from timings) as event_to_last_record_ms,
  clock_timestamp()>=e.created_at+interval '5 minutes' as observation_window_elapsed
from event e;
-- Zero rows = wrong IDs/missing event, not zero failures. Unfinished/missing at
-- five minutes = INCOMPLETE. Extra claims/recipients = anomaly, not a healthy40.

-- 5. CLEANUP. Only after recording metrics/logs and no work remains in flight.
-- Set room/post; deletes run class and its cascading inbox/ledger/post/members.
-- Never delete profiles/auth users/tokens/settings. Class-scoped settings block cleanup.
begin;
do $$
declare room uuid := null; post uuid := null;
begin
  if room is null or post is null or not exists(select 1 from public.classes
    where id=room and course='M12-BE-04 push burst '||post::text and section='M12-BE-04' and school_year='DEV') then
    raise exception 'Run ownership marker mismatch';
  end if;
  if exists(select 1 from public.posts where class_id=room and id<>post)
    or exists(select 1 from public.notification_settings where class_id=room)
    or exists(select 1 from public.post_attachments where post_id=post)
    or exists(select 1 from public.submissions where post_id=post)
    or exists(select 1 from public.quizzes where class_id=room)
    or exists(select 1 from public.notifications where class_id=room
      and (target_type is distinct from 'post' or target_id is distinct from post)) then
    raise exception 'Unexpected class data/settings; inspect instead of broad cleanup';
  end if;
  if exists(select 1 from public.posts where id=post and created_at>clock_timestamp()-interval '5 minutes') then
    raise exception 'Observation window still open; preserve fixtures and wait';
  end if;
  if exists(select 1 from public.push_deliveries d join public.notifications n on n.id=d.notification_id
    where n.class_id=room and (d.status='claimed' or d.finished_at is null)) then
    raise exception 'Unfinished deliveries: preserve evidence and inspect logs first';
  end if;
  delete from public.classes where id=room;
end $$;
commit;

