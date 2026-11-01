-- DEV ONLY: run the WHOLE file as postgres after 20261101100000.
-- All fixtures and helpers roll back. Any FAIL or uncaught error means failure.
-- On abort run ROLLBACK separately. This simulates claims, not real OTP/FCM/HTTP.
begin;
create temporary table m12_results(step integer generated always as identity,
  test text, result text, detail text) on commit drop;
create function pg_temp.m12_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when i=0 then '{}' else
    jsonb_build_object('sub',current_setting('m12.u'||i),
      'session_id',current_setting('m12.s'||i),'role','authenticated')::text end,true);
end $$;
create function pg_temp.m12_check(q text, label text) returns void language plpgsql as $$
declare ok boolean; msg text;
begin
  begin
    set local role authenticated; execute q into ok; reset role;
  exception when others then
    get stacked diagnostics msg=message_text; reset role;
  end;
  insert into m12_results(test,result,detail)
    values(label,case when ok is true then 'PASS' else 'FAIL' end,msg);
end $$;
create function pg_temp.m12_run(q text, expected text, label text) returns void language plpgsql as $$
declare code text:='00000'; msg text;
begin
  begin
    set local role authenticated; execute q; reset role;
    if expected<>'00000' then raise exception 'Unexpected success' using errcode='ZM001'; end if;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text; reset role;
    if code='ZM001' then code:='00000'; end if;
  end;
  insert into m12_results(test,result,detail) values(label,
    case when code=expected then 'PASS' else 'FAIL' end,code||coalesce(': '||msg,''));
end $$;
do $$
declare i integer; u uuid; s uuid; c uuid:=gen_random_uuid();
begin
  if exists (select 1 from public.device_tokens where fcm_token in
    ('m12-token','m12-other-phone','blocked','x','forged')) then
    raise exception 'M12 token fixture collision; inspect provenance without deleting unrelated rows';
  end if;
  if to_regprocedure('public.register_device_token(text,text,text)') is null
    or to_regprocedure('public.unregister_device_token(text)') is null
    or to_regprocedure('public.set_notification_setting(notification_type,uuid,boolean)') is null then
    raise exception 'Apply M12-BE-01 migration first';
  end if;
  for i in 1..4 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m12.u'||i,u::text,true);
    perform set_config('m12.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    insert into public.profiles(id,role,display_name) values(u,'instructor','M12 fixture');
    if i<>3 then insert into public.verified_sessions(session_id,user_id) values(s,u); end if;
  end loop;
  update public.profiles set deleted_at=now() where id=current_setting('m12.u4')::uuid;
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,current_setting('m12.u1')::uuid,'M12 fixture','Test','2026');
  perform set_config('m12.class',c::text,true);
end $$;
do $$
declare c uuid:=current_setting('m12.class')::uuid; t public.notification_type;
  tbl text; stmt text; actor integer; token_id uuid; setting_id uuid;
begin
  perform pg_temp.m12_actor(1);
  perform pg_temp.m12_run('select register_device_token(''m12-token'',repeat(''a'',64),''android'')','00000','register token');
  select id into token_id from public.device_tokens where fcm_token='m12-token';
  perform pg_temp.m12_run('select register_device_token(''m12-token'',repeat(''b'',64),''android'')','00000','register same token again');
  perform pg_temp.m12_check(format('select count(*)=1 and bool_and(id=%L::uuid and device_hash=repeat(''b'',64)) from device_tokens where fcm_token=''m12-token''',token_id),'duplicate retains one row and updates metadata');
  perform pg_temp.m12_actor(2);
  perform pg_temp.m12_check('select count(*)=0 from device_tokens where fcm_token=''m12-token''','other account cannot read token');
  perform pg_temp.m12_run('select register_device_token(''m12-token'',repeat(''c'',64),''android'')','00000','same phone token moves to second account');
  perform pg_temp.m12_check(format('select count(*)=1 and bool_and(id=%L::uuid and user_id=auth.uid()) from device_tokens where fcm_token=''m12-token''',token_id),'new account owns same unique row');
  perform pg_temp.m12_actor(1);
  perform pg_temp.m12_run('select unregister_device_token(''m12-token'')','00000','old account unregister is safe no-op');
  perform pg_temp.m12_check('select count(*)=0 from device_tokens where fcm_token=''m12-token''','old owner cannot read transferred token');
  perform pg_temp.m12_actor(2);
  perform pg_temp.m12_check('select count(*)=1 from device_tokens where fcm_token=''m12-token''','old account did not delete new ownership');
  perform pg_temp.m12_run('select register_device_token(''m12-other-phone'',repeat(''d'',64),''android'')','00000','another phone retained');
  perform pg_temp.m12_run('select unregister_device_token(''m12-token'')','00000','sign-out unregister');
  perform pg_temp.m12_run('select unregister_device_token(''m12-token'')','00000','repeat unregister');
  perform pg_temp.m12_check('select count(*)=0 from device_tokens where fcm_token=''m12-token''','signed-out token absent');
  perform pg_temp.m12_check('select count(*)=1 from device_tokens where fcm_token=''m12-other-phone''','unregister preserves another phone');
  perform pg_temp.m12_actor(1);
  foreach t in array enum_range(null::public.notification_type) loop
    perform pg_temp.m12_check(format('select coalesce((select enabled from notification_settings where user_id=auth.uid() and class_id is null and type=%L),true)',t),'missing global setting means on: '||t);
    perform pg_temp.m12_run(format('select set_notification_setting(%L,null,false)',t),'00000','disable global type: '||t);
    perform pg_temp.m12_check(format('select count(*)=1 and bool_and(not enabled) from notification_settings where class_id is null and type=%L',t),'global type saved: '||t);
  end loop;
  select id into setting_id from public.notification_settings
    where user_id=auth.uid() and class_id is null and type='announcement';
  perform pg_temp.m12_run('select set_notification_setting(''announcement'',null,true)','00000','enable existing global setting');
  perform pg_temp.m12_check(format('select count(*)=1 and bool_and(enabled and id=%L::uuid) from notification_settings where class_id is null and type=''announcement''',setting_id),'global upsert keeps row');
  perform pg_temp.m12_check(format('select coalesce((select enabled from notification_settings where user_id=auth.uid() and class_id=%L and type=''announcement''),true)',c),'missing class setting means on');
  perform pg_temp.m12_run(format('select set_notification_setting(''announcement'',%L,false)',c),'00000','disable one class type');
  perform pg_temp.m12_check(format('select count(*)=1 and bool_and(not enabled) from notification_settings where class_id=%L and type=''announcement''',c),'class disabled value persisted');
  perform pg_temp.m12_run(format('select set_notification_setting(''announcement'',%L,true)',c),'00000','enable same class type');
  perform pg_temp.m12_check(format('select count(*)=1 and bool_and(enabled) from notification_settings where class_id=%L and type=''announcement''',c),'class upsert keeps one row');
  perform pg_temp.m12_check('select count(*)=1 and bool_and(not enabled) from notification_settings where class_id is null and type=''material''','other type unaffected');
  perform pg_temp.m12_actor(2);
  perform pg_temp.m12_check('select count(*)=0 from notification_settings where user_id=current_setting(''m12.u1'')::uuid','other account cannot read settings');
  perform pg_temp.m12_run(format('select set_notification_setting(''announcement'',%L,false)',c),'42501','unrelated class refused');
  insert into public.class_members(class_id,student_id,status)
    values(c,current_setting('m12.u2')::uuid,'active');
  perform pg_temp.m12_run(format('select set_notification_setting(''announcement'',%L,false)',c),'00000','active member saves own class setting');
  perform pg_temp.m12_run('select set_notification_setting(''announcement'',null,false)','00000','second account saves own global setting');
  perform pg_temp.m12_actor(1);
  perform pg_temp.m12_check('select enabled from notification_settings where user_id=auth.uid() and class_id is null and type=''announcement''','second account did not alter first settings');
  foreach tbl in array array['device_tokens','notification_settings'] loop
    perform pg_temp.m12_run(format('delete from %I where user_id=current_setting(''m12.u2'')::uuid',tbl),'42501','direct delete refused: '||tbl);
    perform pg_temp.m12_run(format('update %I set user_id=auth.uid() where user_id=current_setting(''m12.u2'')::uuid',tbl),'42501','direct ownership change refused: '||tbl);
  end loop;
  perform pg_temp.m12_run('insert into device_tokens(user_id,fcm_token) values(current_setting(''m12.u2'')::uuid,''forged'')','42501','forged token insert refused');
  perform pg_temp.m12_run('insert into notification_settings(user_id,type) values(current_setting(''m12.u2'')::uuid,''announcement'')','42501','forged setting insert refused');
  perform pg_temp.m12_run('update notification_settings set enabled=false where user_id=auth.uid()','42501','own direct setting write also refused');
  perform pg_temp.m12_run('select register_device_token('''',repeat(''a'',64),''android'')','22023','blank token refused');
  perform pg_temp.m12_run('select register_device_token(null,repeat(''a'',64),''android'')','22023','null token refused');
  perform pg_temp.m12_run('select register_device_token('' spaced '',repeat(''a'',64),''android'')','22023','token whitespace refused');
  perform pg_temp.m12_run('select register_device_token(''x'',''bad'',''android'')','22023','malformed device hash refused');
  perform pg_temp.m12_run('select register_device_token(''x'',null,''android'')','22023','null device hash refused');
  perform pg_temp.m12_run('select register_device_token(''x'',repeat(''a'',64),''ios'')','22023','unsupported platform refused');
  perform pg_temp.m12_run('select unregister_device_token(null)','22023','null unregister token refused');
  perform pg_temp.m12_run('select set_notification_setting(null,null,true)','22023','null type refused');
  perform pg_temp.m12_run('select set_notification_setting(''announcement'',null,null)','22023','null enabled refused');
  perform pg_temp.m12_run('select set_notification_setting(''announcement'',''00000000-0000-0000-0000-000000000000'',true)','22023','reserved class sentinel refused');
  for actor in 0..4 loop
    if actor in (1,2) then continue; end if;
    perform pg_temp.m12_actor(actor);
    foreach stmt in array array[
      'select register_device_token(''blocked'',repeat(''a'',64),''android'')',
      'select unregister_device_token(''m12-other-phone'')',
      'select set_notification_setting(''announcement'',null,false)'] loop
      perform pg_temp.m12_run(stmt,'42501','missing auth / OTP / deleted account '||actor||': '||stmt);
    end loop;
    if actor=3 then
      perform pg_temp.m12_check('select count(*)=0 from device_tokens','unverified session reads no tokens');
      perform pg_temp.m12_check('select count(*)=0 from notification_settings','unverified session reads no settings');
    end if;
  end loop;
  perform pg_temp.m12_check('select not has_function_privilege(''anon'',''public.register_device_token(text,text,text)'',''EXECUTE'') and not has_function_privilege(''anon'',''public.unregister_device_token(text)'',''EXECUTE'') and not has_function_privilege(''anon'',''public.set_notification_setting(notification_type,uuid,boolean)'',''EXECUTE'')','anon has no RPC grants');
end $$;
select * from m12_results order by step;
select count(*) filter(where result='PASS') as passed,
  count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures from m12_results;
rollback;
