-- DEV ONLY: run the WHOLE file as postgres after 20261102100000.
-- SQL tests grants/RLS and bucket configuration, NOT Storage HTTP uploads or real OTP.
-- Every fixture/helper rolls back. Any FAIL or uncaught error means failure.
-- If interrupted, run ROLLBACK separately before retrying.
begin;
create temporary table m13_results(step integer generated always as identity,
  test text, result text, detail text) on commit drop;

create function pg_temp.m13_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', current_setting('m13.u'||i), 'session_id', current_setting('m13.s'||i),
    'role', 'authenticated')::text, true);
end $$;

-- expected=denied accepts a zero-row denial or 42501, never an unrelated error.
create function pg_temp.m13_check(q text, label text, expected text default 'true')
returns void language plpgsql as $$
declare ok boolean; code text := '00000'; msg text;
begin
  begin
    set local role authenticated;
    execute q into ok;
    reset role;
  exception when others then
    get stacked diagnostics code=returned_sqlstate, msg=message_text;
    reset role;
  end;
  insert into m13_results(test,result,detail) values(label,
    case when (expected='true' and code='00000' and ok is true)
      or (expected='42501' and code='42501')
      or (expected='denied' and (code='42501' or (code='00000' and ok is true)))
      then 'PASS' else 'FAIL' end,
    code||coalesce(': '||msg, ': boolean='||coalesce(ok::text,'NULL')));
end $$;

do $$
declare i integer; u uuid; s uuid; c uuid := gen_random_uuid();
begin
  if not exists (select 1 from storage.buckets where id='avatars') then
    raise exception 'avatars bucket missing';
  end if;
  for i in 1..7 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('m13.u'||i,u::text,true);
    perform set_config('m13.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    if i<>7 then
      insert into public.verified_sessions(session_id,user_id) values(s,u);
    end if;
    -- Actor 6 exercises real authenticated onboarding inserts below.
    if i<>6 then
      insert into public.profiles(id,role,display_name,email,privacy_accepted_at,privacy_version)
        values(u,case when i=1 then 'instructor'::public.user_role else 'student'::public.user_role end,
          'M13 fixture','m13@example.invalid',now(),'m13-original');
    end if;
  end loop;
  perform set_config('m13.class',c::text,true);
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,current_setting('m13.u1')::uuid,'M13 fixture','Test','2026');
  insert into public.class_members(class_id,student_id,status)
    select c,current_setting('m13.u'||gs.n)::uuid,
      case when gs.n=4 then 'pending'::public.member_status else 'active'::public.member_status end
    from generate_series(2,4) as gs(n);
end $$;

-- Bucket settings are privileged configuration checks, not upload success claims.
insert into m13_results(test,result)
select 'private avatars / exact 512 KiB / JPEG PNG WebP configuration',
  case when not public and file_size_limit=524288
    and allowed_mime_types @> array['image/jpeg','image/png','image/webp']::text[]
    and allowed_mime_types <@ array['image/jpeg','image/png','image/webp']::text[]
    then 'PASS' else 'FAIL' end from storage.buckets where id='avatars';

do $$
declare actor integer; col record; expr jsonb; original jsonb; candidate public.user_role;
begin
  perform pg_temp.m13_actor(6);
  perform pg_temp.m13_check($q$with x as (
    insert into public.profiles(id,role,display_name,email,school,google_photo_url,
      privacy_accepted_at,privacy_version)
    values(auth.uid(),'student','M13 onboarding','new@example.invalid','School',
      'https://example.invalid/photo',now(),'m13-initial') returning id)
    select count(*)=1 from x$q$, 'onboarding insert preserves role and consent');
  delete from public.profiles where id=current_setting('m13.u6')::uuid;
  perform pg_temp.m13_check($q$with x as (
    insert into public.profiles(id,role,display_name,email,privacy_accepted_at,privacy_version)
    values(auth.uid(),'instructor','M13 onboarding','new@example.invalid',now(),'m13-initial')
    returning id) select count(*)=1 from x$q$, 'instructor onboarding insert preserves role and consent');

  for actor in 1..2 loop
    perform pg_temp.m13_actor(actor);
    select to_jsonb(p) into original from public.profiles p where id=auth.uid();
    perform pg_temp.m13_check($q$with x as (update public.profiles
      set display_name='M13 edited',school='M13 school',avatar_path=auth.uid()::text||'/photo.png'
      where id=auth.uid() returning *) select count(*)=1 from x$q$,
      'actor '||actor||': all three edits affect one row');
    perform pg_temp.m13_check($q$select count(*)=1 from public.profiles
      where id=auth.uid() and display_name='M13 edited' and school='M13 school'
        and avatar_path=auth.uid()::text||'/photo.png'$q$,'actor '||actor||': edits persisted');
    perform pg_temp.m13_check($q$with x as (update public.profiles set school=null,avatar_path=null
      where id=auth.uid() returning id) select count(*)=1 from x$q$,
      'actor '||actor||': optional fields clear');
    -- Test every non-editable column, including future additions, using its current value.
    for col in select column_name from information_schema.columns
      where table_schema='public' and table_name='profiles'
        and column_name not in ('display_name','school','avatar_path') loop
      perform pg_temp.m13_check(format('update public.profiles set %1$I=%1$I where id=auth.uid()',col.column_name),
        'actor '||actor||': protected column '||col.column_name,'42501');
    end loop;
    candidate:=case when actor=1 then 'student'::public.user_role else 'instructor'::public.user_role end;
    perform pg_temp.m13_check(format('update public.profiles set role=%L where id=auth.uid()',candidate),
      'actor '||actor||': role change refused','42501');
    perform pg_temp.m13_check('delete from public.profiles where id=auth.uid()',
      'actor '||actor||': cannot delete/reinsert profile to change role','42501');
    perform pg_temp.m13_check('update public.profiles set email=''changed@example.invalid'' where id=auth.uid()',
      'actor '||actor||': email change refused','42501');
    perform pg_temp.m13_check($q$update public.profiles set display_name='M13 forbidden',
      privacy_accepted_at=null where id=auth.uid()$q$,'actor '||actor||': mixed update refused','42501');
    perform pg_temp.m13_check(format($q$insert into public.profiles(id,role,display_name)
      values(auth.uid(),%L,'M13 forbidden') on conflict(id) do update
      set role=excluded.role,display_name=excluded.display_name$q$,candidate),
      'actor '||actor||': role upsert refused','42501');
    perform pg_temp.m13_check($q$select display_name='M13 edited' from public.profiles where id=auth.uid()$q$,
      'actor '||actor||': failed mixed/upsert changes atomic');
    select to_jsonb(p)-array['display_name','school','avatar_path','updated_at'] into expr
      from public.profiles p where id=auth.uid();
    insert into m13_results(test,result) values('actor '||actor||': protected values unchanged',
    case when expr=original-array['display_name','school','avatar_path','updated_at']
        then 'PASS' else 'FAIL' end);
    perform pg_temp.m13_check(format($q$with x as (update public.profiles set display_name='intruder'
      where id=%L::uuid returning id) select count(*)=0 from x$q$,current_setting('m13.u'||(3-actor))),
      'actor '||actor||': other profile not editable');
  end loop;
end $$;

do $$
declare actor integer; state text; path text; claims jsonb;
begin
  for actor in 1..3 loop
    perform pg_temp.m13_actor(actor);
    path:=auth.uid()::text||'/m13.png';
    perform pg_temp.m13_check(format($q$with x as (insert into storage.objects(bucket_id,name)
      values('avatars',%L) returning id) select count(*)=1 from x$q$,path),
      'actor '||actor||': own avatar metadata insert');
    perform pg_temp.m13_check(format($q$with x as (update storage.objects set metadata='{"mimetype":"image/png"}'
      where bucket_id='avatars' and name=%L returning id) select count(*)=1 from x$q$,path),
      'actor '||actor||': own avatar metadata update');
    perform pg_temp.m13_check(format($q$insert into storage.objects(bucket_id,name)
      values('avatars',%L)$q$,current_setting('m13.u5')||'/forged.png'),
      'actor '||actor||': foreign folder insert refused','42501');
    perform pg_temp.m13_check(format($q$update storage.objects set name=%L
      where bucket_id='avatars' and name=%L$q$,current_setting('m13.u5')||'/moved.png',path),
      'actor '||actor||': cannot move avatar to foreign folder','42501');
    perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',path),
      'actor '||actor||': owner reads avatar');
  end loop;
  -- Student 2's photo is the access matrix target.
  path:=current_setting('m13.u2')||'/m13.png';
  perform pg_temp.m13_actor(3);
  perform pg_temp.m13_check(format($q$with x as (update storage.objects set metadata='{}'
    where bucket_id='avatars' and name=%L returning id) select count(*)=0 from x$q$,path),
    'classmate cannot update another avatar');
  perform pg_temp.m13_check(format($q$with x as (delete from storage.objects
    where bucket_id='avatars' and name=%L returning id) select count(*)=0 from x$q$,path),
    'classmate cannot delete another avatar','denied');
  perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',path),
    'avatar remains after classmate delete attempt');
  for actor in 1..5 loop
    perform pg_temp.m13_actor(actor);
    perform pg_temp.m13_check(format('select count(*)=%s from storage.objects where bucket_id=''avatars'' and name=%L',
      case when actor<=3 then 1 else 0 end,path),'avatar read actor '||actor);
  end loop;
  perform pg_temp.m13_actor(4);
  perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',
    current_setting('m13.u1')||'/m13.png'),'pending student can read instructor avatar');
  foreach state in array array['declined','removed','left'] loop
    update public.class_members set status=state::public.member_status
      where class_id=current_setting('m13.class')::uuid and student_id=current_setting('m13.u3')::uuid;
    perform pg_temp.m13_actor(3);
    perform pg_temp.m13_check(format('select count(*)=0 from storage.objects where bucket_id=''avatars'' and name=%L',path),
      state||' student cannot read classmate avatar');
    perform pg_temp.m13_actor(1);
    perform pg_temp.m13_check('select count(*)=1 from public.profiles where id=current_setting(''m13.u3'')::uuid',
      state||' member profile retained for instructor');
    perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',
      current_setting('m13.u3')||'/m13.png'),state||' member avatar retained for instructor');
  end loop;
  update public.class_members set status='active' where class_id=current_setting('m13.class')::uuid;
  update public.classes set archived_at=now() where id=current_setting('m13.class')::uuid;
  perform pg_temp.m13_actor(3);
  perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',path),
    'archived class remains readable');
  update public.classes set deleted_at=now() where id=current_setting('m13.class')::uuid;
  foreach actor in array array[1,3,4] loop
    perform pg_temp.m13_actor(actor);
    perform pg_temp.m13_check(format('select count(*)=0 from storage.objects where bucket_id=''avatars'' and name=%L',path),
      'deleted class grants no avatar relationship actor '||actor);
    perform pg_temp.m13_check('select count(*)=0 from public.profiles where id=current_setting(''m13.u2'')::uuid',
      'deleted class grants no profile relationship actor '||actor);
  end loop;

  perform pg_temp.m13_actor(2);
  perform pg_temp.m13_check(format('select count(*)=0 from storage.objects where bucket_id=''avatars'' and name=%L',
    current_setting('m13.u1')||'/m13.png'),'deleted class grants no instructor avatar access');
  perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',path),
    'self avatar remains readable after class deletion');
  update public.classes set deleted_at=null where id=current_setting('m13.class')::uuid;
  perform pg_temp.m13_actor(3);
  perform pg_temp.m13_check(format('select count(*)=1 from storage.objects where bucket_id=''avatars'' and name=%L',path),
    'restored class grants classmate access again');

  for actor in 1..7 loop
    if actor not in (2,7) then continue; end if;
    foreach state in array array['no OTP','missing session','malformed session','mismatched session','missing subject','revoked session'] loop
      if state='no OTP' and actor<>7 then continue; end if;
      perform pg_temp.m13_actor(actor);
      claims:=current_setting('request.jwt.claims')::jsonb;
      if state='missing session' then claims:=claims-'session_id';
      elsif state='malformed session' then claims:=jsonb_set(claims,'{session_id}','"bad"');
      elsif state='mismatched session' then claims:=jsonb_set(claims,'{session_id}',to_jsonb(current_setting('m13.s1')));
      elsif state='missing subject' then claims:=claims-'sub';
      elsif state='revoked session' then
        delete from auth.sessions where id=current_setting('m13.s'||actor)::uuid;
      end if;
      perform set_config('request.jwt.claims',claims::text,true);
      perform pg_temp.m13_check('select not public.is_session_verified()','actor '||actor||' / '||state||': gate false');
      perform pg_temp.m13_check('select count(*)=0 from public.profiles','actor '||actor||' / '||state||': no profiles','denied');
      perform pg_temp.m13_check($q$with x as (update public.profiles set display_name='blocked'
        where id=auth.uid() returning id) select count(*)=0 from x$q$,
        'actor '||actor||' / '||state||': no profile update','denied');
      perform pg_temp.m13_check('select count(*)=0 from storage.objects where bucket_id=''avatars''',
        'actor '||actor||' / '||state||': no avatar reads','denied');
      perform pg_temp.m13_check(format('insert into storage.objects(bucket_id,name) values(''avatars'',%L)',
        current_setting('m13.u'||actor)||'/'||replace(state,' ','-')||'.png'),
        'actor '||actor||' / '||state||': avatar insert refused','42501');
      perform pg_temp.m13_check($q$with x as (update storage.objects set metadata='{}'
        where bucket_id='avatars' returning id) select count(*)=0 from x$q$,
        'actor '||actor||' / '||state||': no avatar updates','denied');
      perform pg_temp.m13_check($q$with x as (delete from storage.objects
        where bucket_id='avatars' returning id) select count(*)=0 from x$q$,
        'actor '||actor||' / '||state||': no avatar deletes','denied');
    end loop;
  end loop;
end $$;

select * from m13_results order by step;
select count(*) filter(where result='PASS') as passed,
  count(*) filter(where result='FAIL') as failed,
  case when count(*)>0 and bool_and(result='PASS') then 'PASS' else 'FAIL' end as overall,
  coalesce(jsonb_agg(test) filter(where result='FAIL'),'[]') as failures,
  coalesce(jsonb_agg(jsonb_build_object('test',test,'detail',detail))
    filter(where result='FAIL'),'[]') as failure_details from m13_results;
rollback;
