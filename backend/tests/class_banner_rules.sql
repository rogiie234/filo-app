-- DEV ONLY: run the WHOLE file as postgres after 20261102130000.
-- Rollback-only SQL/RLS/configuration checks; NOT Storage HTTP upload evidence.
-- Any FAIL or uncaught error fails acceptance. After interruption run ROLLBACK.
begin;
-- Match Storage API's transaction-local guard so DELETE checks actually exercise RLS.
set local storage.allow_delete_query = 'true';
create temporary table m14_results(step integer generated always as identity,
  test text, result text, detail text) on commit drop;

create function pg_temp.m14_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',current_setting('m14.u'||i),'session_id',current_setting('m14.s'||i),
    'role','authenticated')::text,true);
end $$;

create function pg_temp.m14_check(q text,label text,expected text default 'true')
returns void language plpgsql as $$
declare ok boolean; code text := '00000'; msg text;
begin
  begin
    set local role authenticated;
    execute q into ok;
    reset role;
  exception when others then
    get stacked diagnostics code=returned_sqlstate,msg=message_text;
    reset role;
  end;
  insert into m14_results(test,result,detail) values(label,
    case when (expected='true' and code='00000' and ok is true)
      or (expected='denied' and (code='42501' or (code='00000' and ok is true)))
      or (expected=code) then 'PASS' else 'FAIL' end,
    code||coalesce(': '||msg,': boolean='||coalesce(ok::text,'NULL')));
end $$;

do $$
declare i integer; u uuid; s uuid; c uuid;
begin
  if not exists(select 1 from pg_constraint where conrelid='public.classes'::regclass
    and conname='classes_banner_color_preset_check' and convalidated) then
    raise exception 'Apply M14 banner migration first';
  end if;
  for i in 1..9 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m14.u'||i,u::text,true);
    perform set_config('m14.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    if i<>8 then insert into public.verified_sessions(session_id,user_id) values(s,u); end if;
    insert into public.profiles(id,role,display_name,email,privacy_accepted_at,privacy_version)
      values(u,case when i in (1,2,8) then 'instructor'::public.user_role
        else 'student'::public.user_role end,'M14 fixture','m14@example.invalid',now(),'m14');
  end loop;
  for i in 1..2 loop
    c:=gen_random_uuid(); perform set_config('m14.c'||i,c::text,true);
    insert into public.classes(id,owner_id,course,section,school_year)
      values(c,current_setting('m14.u'||i)::uuid,'M14 fixture','Banner','2026');
    insert into storage.objects(bucket_id,name) values('banners',c::text||'/existing.png');
  end loop;
  insert into public.class_members(class_id,student_id,status)
    select current_setting('m14.c1')::uuid,current_setting('m14.u'||n)::uuid,
      case n when 3 then 'active'::public.member_status when 4 then 'pending'::public.member_status
        when 5 then 'removed'::public.member_status else 'left'::public.member_status end
    from generate_series(3,6) gs(n);
  insert into public.class_members(class_id,student_id,status)
    values(current_setting('m14.c1')::uuid,current_setting('m14.u9')::uuid,'declined');
end $$;

insert into m14_results(test,result)
select 'private bucket / exact 2 MiB / JPEG PNG WebP configuration',
  case when exists(select 1 from storage.buckets where id='banners' and not public
    and file_size_limit=2097152 and cardinality(allowed_mime_types)=3
    and allowed_mime_types @> array['image/jpeg','image/png','image/webp']::text[])
  then 'PASS' else 'FAIL' end;

do $$
declare k text; actor integer; path text:=current_setting('m14.c1')||'/existing.png';
begin
  perform pg_temp.m14_actor(1);
  foreach k in array array['forest','teal','sage','pine','ocean','slate','olive','plum'] loop
    perform pg_temp.m14_check(format($q$with x as (update public.classes set banner_color=%L,
      banner_path=null where id=current_setting('m14.c1')::uuid returning banner_color)
      select count(*)=1 and bool_and(banner_color=%L) from x$q$,k,k),'owner preset '||k);
    perform pg_temp.m14_check(format($q$with x as (insert into public.classes
      (owner_id,course,section,school_year,banner_color) values(auth.uid(),'M14','Preset','2026',%L)
      returning id) select count(*)=1 from x$q$,k),'create preset '||k);
  end loop;
  foreach k in array array['','FOREST','unknown',' forest','forest '] loop
    perform pg_temp.m14_check(format($q$update public.classes set banner_color=%L
      where id=current_setting('m14.c1')::uuid$q$,k),'invalid update '||quote_literal(k),'23514');
    perform pg_temp.m14_check(format($q$insert into public.classes
      (owner_id,course,section,school_year,banner_color) values(auth.uid(),'M14','Invalid','2026',%L)$q$,k),
      'invalid insert '||quote_literal(k),'23514');
  end loop;
  perform pg_temp.m14_check($q$with x as (update public.classes set banner_color=null,banner_path=null
    where id=current_setting('m14.c1')::uuid returning id) select count(*)=1 from x$q$,'owner default');
  perform pg_temp.m14_check(format($q$with x as (update public.classes set banner_color=null,banner_path=%L
    where id=current_setting('m14.c1')::uuid returning id) select count(*)=1 from x$q$,path),'owner upload reference');
  perform pg_temp.m14_check($q$with x as (update public.classes set banner_color='forest',banner_path=null
    where id=current_setting('m14.c1')::uuid returning id) select count(*)=1 from x$q$,'upload to preset');

  for actor in 1..9 loop
    perform pg_temp.m14_actor(actor);
    perform pg_temp.m14_check(format('select count(*)=%s from storage.objects where bucket_id=''banners'' and name=%L',
      case when actor in (1,3) then 1 else 0 end,path),'actor '||actor||' read',
      case when actor=8 then 'denied' else 'true' end);
    if actor<>1 then
      perform pg_temp.m14_check($q$with x as (update public.classes set banner_color='plum',banner_path=null
        where id=current_setting('m14.c1')::uuid returning id) select count(*)=0 from x$q$,
        'actor '||actor||' preset write denied','denied');
      perform pg_temp.m14_check(format($q$with x as (update public.classes set banner_color=null,banner_path=%L
        where id=current_setting('m14.c1')::uuid returning id) select count(*)=0 from x$q$,path),
        'actor '||actor||' upload reference denied','denied');
      perform pg_temp.m14_check(format('insert into storage.objects(bucket_id,name) values(''banners'',%L)',
        current_setting('m14.c1')||'/denied-'||actor||'.png'),'actor '||actor||' upload denied','42501');
      perform pg_temp.m14_check(format($q$with x as (update storage.objects set metadata='{}'
        where bucket_id='banners' and name=%L returning id) select count(*)=0 from x$q$,path),
        'actor '||actor||' replace denied','denied');
      perform pg_temp.m14_check(format($q$with x as (delete from storage.objects
        where bucket_id='banners' and name=%L returning id) select count(*)=0 from x$q$,path),
        'actor '||actor||' delete denied','denied');
    end if;
  end loop;
  insert into m14_results(test,result)
    select 'denied class writes retain preset and cleared upload',
      case when banner_color='forest' and banner_path is null then 'PASS' else 'FAIL' end
    from public.classes where id=current_setting('m14.c1')::uuid;
  perform pg_temp.m14_actor(1);
  perform pg_temp.m14_check(format($q$with x as (insert into storage.objects(bucket_id,name)
    values('banners',%L) returning id) select count(*)=1 from x$q$,
    current_setting('m14.c1')||'/new.png'),'owner upload metadata');
  perform pg_temp.m14_check(format($q$with x as (update storage.objects set metadata='{"m14":true}'
    where bucket_id='banners' and name=%L returning id) select count(*)=1 from x$q$,path),'owner replacement');
  perform pg_temp.m14_check(format($q$update storage.objects set name=%L
    where bucket_id='banners' and name=%L$q$,current_setting('m14.c2')||'/stolen.png',path),
    'cross-class destination denied','42501');
  perform pg_temp.m14_check(format($q$select count(*)=1 from storage.objects
    where bucket_id='banners' and name=%L$q$,path),'denied move retains original');

  update public.classes set archived_at=now() where id=current_setting('m14.c1')::uuid;
  perform pg_temp.m14_check(format('select count(*)=1 from storage.objects where bucket_id=''banners'' and name=%L',path),'archived owner read');
  perform pg_temp.m14_check(format('insert into storage.objects(bucket_id,name) values(''banners'',%L)',
    current_setting('m14.c1')||'/archived.png'),'archived upload denied','42501');
  perform pg_temp.m14_check(format($q$with x as (update storage.objects set metadata='{}'
    where bucket_id='banners' and name=%L returning id) select count(*)=0 from x$q$,path),'archived replace denied','denied');
  perform pg_temp.m14_check(format($q$with x as (delete from storage.objects
    where bucket_id='banners' and name=%L returning id) select count(*)=0 from x$q$,path),'archived delete denied','denied');
  perform pg_temp.m14_actor(3);
  perform pg_temp.m14_check(format('select count(*)=1 from storage.objects where bucket_id=''banners'' and name=%L',path),'archived active member read');
  update public.classes set deleted_at=now() where id=current_setting('m14.c1')::uuid;
  for actor in 1..3 loop
    perform pg_temp.m14_actor(actor);
    perform pg_temp.m14_check(format('select count(*)=0 from storage.objects where bucket_id=''banners'' and name=%L',path),'deleted class actor '||actor||' denied');
  end loop;
  update public.classes set deleted_at=null,archived_at=null where id=current_setting('m14.c1')::uuid;
  perform pg_temp.m14_actor(1);
  perform pg_temp.m14_check(format($q$with x as (delete from storage.objects
    where bucket_id='banners' and name=%L returning id) select count(*)=1 from x$q$,path),'owner delete');
end $$;

-- Anonymous read must either return zero rows or lack table privileges.
do $$
declare n bigint; code text:='00000';
begin
  perform set_config('request.jwt.claims','{"role":"anon"}',true);
  begin
    set local role anon;
    select count(*) into n from storage.objects where bucket_id='banners'
      and name=current_setting('m14.c2')||'/existing.png';
    reset role;
  exception when others then
    get stacked diagnostics code=returned_sqlstate;
    reset role;
  end;
  insert into m14_results(test,result,detail) values('anonymous read denied',
    case when code='42501' or (code='00000' and n=0) then 'PASS' else 'FAIL' end,code);
end $$;

select * from m14_results order by step;
select count(*) filter(where result='PASS') as passed,count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(jsonb_build_object('test',test,'detail',detail))
    filter(where result='FAIL'),'[]') as failure_details
from m14_results;
rollback;
