-- DEV SQL Editor or psql, as postgres, after migration 0010.
-- Disposable users/classes and all effects are rolled back. Any failure aborts.
begin;
create temporary table rpc_results(test text, result text) on commit drop;
grant select, insert on rpc_results to authenticated;

do $$
declare
  u uuid; s uuid;
  c uuid := gen_random_uuid(); p uuid := gen_random_uuid();
  i integer;
begin
  perform set_config('rpc_test.class', c::text, true);
  perform set_config('rpc_test.post', p::text, true);
  for i in 1..4 loop
    u := gen_random_uuid(); s := gen_random_uuid();
    perform set_config('rpc_test.user' || i, u::text, true);
    perform set_config('rpc_test.session' || i, s::text, true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id, user_id) values(s, u);
    insert into public.profiles(id, role, display_name, google_photo_url)
      values(u, case when i = 3 then 'instructor'::public.user_role
                     else 'student'::public.user_role end,
             'RPC fixture ' || i, 'https://example.com/avatar');
    insert into public.verified_sessions(session_id, user_id) values(s, u);
  end loop;
  insert into public.classes(id, owner_id, course, section, school_year)
    values(c, current_setting('rpc_test.user3')::uuid, 'RPC fixture', 'Test', '2026');
  insert into public.class_members(class_id, student_id, status)
    values(c, current_setting('rpc_test.user1')::uuid, 'active'),
          (c, current_setting('rpc_test.user4')::uuid, 'pending');
  insert into public.posts(id, class_id, author_id, kind, title)
    values(p, c, current_setting('rpc_test.user3')::uuid, 'material', 'Drive fixture');
  insert into public.post_attachments(post_id, kind, name, url)
    values(p, 'link', 'Drive fixture', 'https://drive.google.com/file/d/fixture/view');
end;
$$;

-- Calls use client privileges, not postgres privileges.
do $$
declare i integer; n integer; c uuid := current_setting('rpc_test.class')::uuid;
begin
  for i in 1..4 loop
    perform set_config('request.jwt.claims', jsonb_build_object(
      'sub', current_setting('rpc_test.user' || i),
      'session_id', current_setting('rpc_test.session' || i),
      'role', 'authenticated')::text, true);
    set local role authenticated;
    if i in (1, 3) then
      select count(*) into n from public.list_classmates(c);
      if n <> 1 then raise exception 'Expected only the active member'; end if;
      if not exists(select 1 from public.list_classmates(c)
        where id = current_setting('rpc_test.user1')::uuid
          and display_name = 'RPC fixture 1'
          and google_photo_url = 'https://example.com/avatar') then
        raise exception 'Classmate fields incorrect';
      end if;
    else
      begin
        perform public.list_classmates(c);
        raise exception 'Unauthorized roster call succeeded';
      exception when insufficient_privilege then null;
      end;
    end if;
    if i = 1 then
      perform public.report_locked_link(current_setting('rpc_test.post')::uuid);
      begin
        perform public.report_locked_link(current_setting('rpc_test.post')::uuid);
        raise exception 'Duplicate report succeeded';
      exception when invalid_parameter_value then null;
      end;
    else
      begin
        perform public.report_locked_link(current_setting('rpc_test.post')::uuid);
        raise exception 'Unauthorized report succeeded';
      exception when insufficient_privilege then null;
      end;
    end if;
    insert into rpc_results values('role ' || i || ' roster/report', 'PASS');
    reset role;
  end loop;
end;
$$;

do $$
declare n integer; p uuid := current_setting('rpc_test.post')::uuid;
begin
  select count(*) into n from public.notifications
    where type = 'link_report' and target_id = p and target_type = 'post'
      and recipient_id = current_setting('rpc_test.user3')::uuid
      and class_id = current_setting('rpc_test.class')::uuid;
  if n <> 1 then raise exception 'Expected one owner notification'; end if;
  delete from public.notifications where type = 'link_report' and target_id = p;
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', current_setting('rpc_test.user1'),
    'session_id', current_setting('rpc_test.session1'),
    'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.report_locked_link(p);
    raise exception 'Deleting notification reset limit';
  exception when invalid_parameter_value then null;
  end;
  reset role;
  update public.locked_link_reports set report_day = report_day - 1 where post_id = p;
  set local role authenticated;
  perform public.report_locked_link(p);
  reset role;
  insert into rpc_results values('notification, deletion, next UTC day', 'PASS');

  update public.class_members set status = 'removed'
    where class_id = current_setting('rpc_test.class')::uuid
      and student_id = current_setting('rpc_test.user1')::uuid;
  set local role authenticated;
  begin
    perform public.list_classmates(current_setting('rpc_test.class')::uuid);
    raise exception 'Removed member roster succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.report_locked_link(p);
    raise exception 'Removed member report succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  update public.class_members set status = 'active'
    where class_id = current_setting('rpc_test.class')::uuid
      and student_id = current_setting('rpc_test.user1')::uuid;
  delete from public.locked_link_reports where post_id = p;
  update public.post_attachments set deleted_at = now() where post_id = p;
  set local role authenticated;
  begin
    perform public.report_locked_link(p);
    raise exception 'Linkless post report succeeded';
  exception when invalid_parameter_value then null;
  end;
  reset role;
  update public.post_attachments set deleted_at = null where post_id = p;
  update public.posts set deleted_at = now() where id = p;
  set local role authenticated;
  begin
    perform public.report_locked_link(p);
    raise exception 'Deleted post report succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  update public.posts set deleted_at = null where id = p;
  update public.classes set deleted_at = now() where id = current_setting('rpc_test.class')::uuid;
  set local role authenticated;
  begin
    perform public.list_classmates(current_setting('rpc_test.class')::uuid);
    raise exception 'Deleted class roster succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.report_locked_link(p);
    raise exception 'Deleted class report succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  update public.classes set deleted_at = null where id = current_setting('rpc_test.class')::uuid;
  insert into rpc_results values('removed, linkless, deleted post/class', 'PASS');

  delete from public.verified_sessions where session_id = current_setting('rpc_test.session1')::uuid;
  set local role authenticated;
  begin
    perform public.list_classmates(current_setting('rpc_test.class')::uuid);
    raise exception 'Unverified roster succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.report_locked_link(p);
    raise exception 'Unverified report succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  if has_function_privilege('anon', 'public.list_classmates(uuid)', 'execute')
    or has_function_privilege('anon', 'public.report_locked_link(uuid)', 'execute')
    or has_table_privilege('authenticated', 'public.locked_link_reports', 'insert') then
    raise exception 'Unexpected client permissions';
  end if;
  insert into rpc_results values('OTP and privileges', 'PASS');
end;
$$;
select * from rpc_results order by test;
rollback;
