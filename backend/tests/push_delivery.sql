-- DEV ONLY: run WHOLE file as postgres after 20261101110000_push_delivery.sql.
-- Rollback-only database assertions; no FCM/HTTP/Redmi evidence. Do not remove ROLLBACK.
begin;
create temporary table push_results(step integer generated always as identity, test text, result text) on commit drop;
create function pg_temp.push_check(ok boolean,label text) returns void language plpgsql as $$
begin insert into push_results(test,result) values(label,case when ok is true then 'PASS' else 'FAIL' end); end $$;
do $$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); n uuid:=gen_random_uuid();
  n2 uuid:=gen_random_uuid(); t uuid:=gen_random_uuid(); v uuid; next_v uuid; c uuid:=gen_random_uuid();
  answer text; removed boolean; before_row jsonb;
begin
  insert into auth.users(id) values(u),(other_user);
  insert into public.profiles(id,role,display_name) values(u,'instructor','Push fixture'),(other_user,'instructor','Push fixture');
  insert into public.classes(id,owner_id,course,section,school_year) values(c,u,'Push fixture','Test','2026');
  insert into public.notifications(id,recipient_id,class_id,type,title,body)
    values(n,u,c,'announcement','Synthetic push test','Synthetic body'),(n2,u,c,'material','Synthetic push test','Synthetic body');
  insert into public.device_tokens(id,user_id,fcm_token,device_hash)
    values(t,u,gen_random_uuid()::text,repeat('a',64)) returning registration_version into v;
  select to_jsonb(x) into before_row from public.notifications x where id=n;
  set local role service_role;
  answer:=public.claim_push_delivery(n,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='claimed','service claims own recipient token');
  set local role service_role;
  answer:=public.claim_push_delivery(n,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='duplicate','repeat claim suppressed');
  perform pg_temp.push_check((select count(*)=1 from public.push_deliveries where notification_id=n),'one ledger row per phone');
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,other_user,v);
  reset role;
  perform pg_temp.push_check(answer='stale','wrong recipient refused');
  insert into public.notification_settings(user_id,type,enabled) values(u,'material',false);
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='muted','global mute blocks claim');
  update public.notification_settings set enabled=true where user_id=u;
  insert into public.notification_settings(user_id,class_id,type,enabled) values(u,c,'material',false);
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='muted','class mute overrides global on');
  update public.notification_settings set enabled=(class_id is not null) where user_id=u;
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='muted','global mute overrides class on');
  delete from public.notification_settings where user_id=u;
  update public.device_tokens set user_id=other_user where id=t returning registration_version into next_v;
  perform pg_temp.push_check(v<>next_v,'registration version rotates on ownership transfer');
  set local role service_role;
  removed:=public.delete_invalid_push_token(t,u,v);
  answer:=public.claim_push_delivery(n2,t,u,v);
  reset role;
  perform pg_temp.push_check(not removed and answer='stale','old version cannot delete or claim transferred token');
  perform pg_temp.push_check(exists(select 1 from public.device_tokens where id=t and user_id=other_user),'transferred token retained');
  update public.device_tokens set user_id=u where id=t returning registration_version into v;
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,u,v);
  reset role;
  perform pg_temp.push_check(answer='claimed','missing settings mean on');
  update public.push_deliveries set status='failed',error_code='timeout',finished_at=now() where notification_id=n2;
  set local role service_role;
  answer:=public.claim_push_delivery(n2,t,u,v);
  removed:=public.delete_invalid_push_token(t,u,v);
  reset role;
  perform pg_temp.push_check(answer='duplicate','uncertain delivery never automatically resends');
  perform pg_temp.push_check(removed and not exists(select 1 from public.device_tokens where id=t),'current invalid token deleted');
  perform pg_temp.push_check((select count(*)=2 from public.push_deliveries where token_id=t),'token cleanup preserves delivery evidence');
  perform pg_temp.push_check((select to_jsonb(x)=before_row from public.notifications x where id=n),'inbox row unchanged after cleanup');
  perform pg_temp.push_check(exists(select 1 from public.notifications where id=n2 and read_at is null),'failed delivery inbox remains unread and visible');
  perform pg_temp.push_check(not has_table_privilege('authenticated','public.push_deliveries','SELECT')
    and not has_table_privilege('anon','public.push_deliveries','SELECT'),'delivery ledger not client-readable');
  perform pg_temp.push_check(not has_function_privilege('authenticated','public.claim_push_delivery(uuid,uuid,uuid,uuid)','EXECUTE')
    and not has_function_privilege('anon','public.claim_push_delivery(uuid,uuid,uuid,uuid)','EXECUTE'),'client cannot claim delivery');
  perform pg_temp.push_check(not has_function_privilege('authenticated','public.delete_invalid_push_token(uuid,uuid,uuid)','EXECUTE')
    and not has_function_privilege('anon','public.delete_invalid_push_token(uuid,uuid,uuid)','EXECUTE'),'client cannot delete invalid tokens');
end $$;
select * from push_results order by step;
select count(*) filter(where result='PASS') as passed,count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall from push_results;
rollback;
