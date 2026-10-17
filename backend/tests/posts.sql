-- DEV ONLY: run the entire file as postgres after all migrations through
-- 20261017100000_post_attachment_limit.sql. No real accounts/credentials needed.
-- Fail-fast: any exception is FAIL. Successful results and fixtures roll back.
-- Two-session concurrency and retained device downloads require separate checks.
begin;
create temporary table post_results(step integer generated always as identity, test text, result text) on commit drop;
create function pg_temp.post_check(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  insert into post_results(test,result) values(label,'PASS');
end $$;
create function pg_temp.post_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('post_test.u'||i),
    'session_id',current_setting('post_test.s'||i),'role','authenticated')::text,true);
end $$;
-- Execute under the real authenticated role; never a SECURITY DEFINER test helper.
create function pg_temp.post_sql(q text, expected text, label text) returns void language plpgsql as $$
declare actual text := '00000';
begin
  begin
    set local role authenticated;
    execute q;
    reset role;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
    reset role;
  end;
  perform pg_temp.post_check(actual=expected,label||' [SQLSTATE '||actual||']');
end $$;
create function pg_temp.post_rows(q text, expected integer, label text) returns void language plpgsql as $$
declare n integer;
begin
  set local role authenticated;
  execute q;
  get diagnostics n = row_count;
  reset role;
  perform pg_temp.post_check(n=expected,label);
end $$;
do $$
declare u uuid; s uuid; c uuid := gen_random_uuid(); p uuid; a uuid; i integer;
  sub_id uuid := gen_random_uuid(); quiz_id uuid := gen_random_uuid(); exam_id uuid := gen_random_uuid();
  base text; k text; col text; q text; n integer;
begin
  perform set_config('post_test.class',c::text,true);
  for i in 1..6 loop
    u:=gen_random_uuid(); s:=gen_random_uuid();
    perform set_config('post_test.u'||i,u::text,true);
    perform set_config('post_test.s'||i,s::text,true);
    insert into auth.users(id) values(u);
    insert into auth.sessions(id,user_id) values(s,u);
    insert into public.profiles(id,role,display_name) values(u,
      case when i<=2 then 'instructor'::public.user_role else 'student'::public.user_role end,'Post fixture '||i);
    insert into public.verified_sessions(session_id,user_id) values(s,u);
  end loop;
  insert into public.classes(id,owner_id,course,section,school_year)
    values(c,current_setting('post_test.u1')::uuid,'Posts fixture','QA','2026-2027');
  for i in 3..6 loop
    insert into public.class_members(class_id,student_id,status) values(c,current_setting('post_test.u'||i)::uuid,
      case when i<=4 then 'active'::public.member_status when i=5 then 'pending'::public.member_status else 'removed'::public.member_status end);
  end loop;
  perform pg_temp.post_actor(1);
  base:=format('insert into public.posts(class_id,author_id,kind,title,points,due_at) values(%L,%L,',c,current_setting('post_test.u1'));
  perform pg_temp.post_sql(base||'''assignment'',''missing points'',null,now())','23514','assignment requires points');
  perform pg_temp.post_sql(base||'''assignment'',''missing due'',100,null)','23514','assignment requires due date');
  foreach k in array array['announcement','material'] loop
    perform pg_temp.post_sql(base||format('%L,''invalid'',1,null)',k),'23514',k||' rejects points');
    perform pg_temp.post_sql(base||format('%L,''invalid'',null,now())',k),'23514',k||' rejects due date');
  end loop;
  foreach k in array array['announcement','material','assignment'] loop
    perform pg_temp.post_sql(base||format('%L,%L,%s,%s)',k,k,
      case when k='assignment' then '100' else 'null' end,
      case when k='assignment' then 'now()+interval ''1 day''' else 'null' end),'00000','create '||k);
    select id into p from public.posts where class_id=c and kind::text=k;
    perform pg_temp.post_check((select count(*) from public.notifications where target_id=p)=2,k||' exact inbox fanout');
    for i in 3..4 loop
      perform pg_temp.post_check((select count(*) from public.notifications where target_id=p
        and recipient_id=current_setting('post_test.u'||i)::uuid and class_id=c and target_type='post' and type::text=k)=1,
        k||' one inbox row for active student '||i);
    end loop;
  end loop;
  -- Checklist 1: another active student's turned-in work and returned grade
  -- exist, so zero rows proves isolation rather than an empty fixture.
  insert into public.submissions(id,post_id,student_id,status,submitted_at)
    values(sub_id,p,current_setting('post_test.u4')::uuid,'turned_in',now());
  insert into public.submission_grades(submission_id,score,returned_at) values(sub_id,50,now());
  insert into public.quizzes(id,class_id,author_id,title) values(quiz_id,c,current_setting('post_test.u1')::uuid,'Isolation fixture');
  insert into public.exam_sessions(id,quiz_id,student_id,deadline_at)
    values(exam_id,quiz_id,current_setting('post_test.u4')::uuid,now()+interval '1 hour');
  perform pg_temp.post_actor(3);
  perform pg_temp.post_rows(format('select id from public.submissions where id=%L',sub_id),0,'checklist 1: no peer submission');
  perform pg_temp.post_rows(format('select submission_id from public.submission_grades where submission_id=%L',sub_id),0,'checklist 1: no peer returned grade');
  perform pg_temp.post_rows(format('select id from public.exam_sessions where id=%L',exam_id),0,'checklist 1: no peer exam session');
  perform pg_temp.post_actor(4);
  perform pg_temp.post_rows(format('select id from public.submissions where id=%L',sub_id),1,'student sees own submission control');
  perform pg_temp.post_rows(format('select submission_id from public.submission_grades where submission_id=%L',sub_id),1,'student sees own returned grade control');
  perform pg_temp.post_actor(1);
  -- p is the assignment. Exercise every granted editable field together.
  perform pg_temp.post_rows(format('update public.posts set title=''Edited'',body=''Updated'',points=50,due_at=now()+interval ''2 days'',accept_late=false,allow_files=false,max_files=1 where id=%L',p),1,'owner edits all allowed content columns');
  perform pg_temp.post_check((select title='Edited' and body='Updated' and points=50 and not accept_late and not allow_files and max_files=1 from public.posts where id=p),'edited values persisted');
  foreach col in array array['id','class_id','author_id','kind','created_at','updated_at'] loop
    q:=case when col='kind' then '''material''' when col in ('created_at','updated_at') then 'now()' else 'gen_random_uuid()' end;
    perform pg_temp.post_sql(format('update public.posts set %I=%s where id=%L',col,q,p),'42501','immutable column '||col);
  end loop;
  for i in 1..10 loop
    perform pg_temp.post_sql(format('insert into public.post_attachments(post_id,kind,name,url) values(%L,''link'',%L,''https://example.com'')',p,'Link '||i),'00000','attachment slot '||i);
  end loop;
  q:=format('insert into public.post_attachments(post_id,kind,name,url) values(%L,''link'',''Extra'',''https://example.com'')',p);
  perform pg_temp.post_sql(q,'23514','eleventh attachment refused');
  select id into a from public.post_attachments where post_id=p limit 1;
  perform pg_temp.post_rows(format('update public.post_attachments set deleted_at=now() where id=%L',a),1,'soft delete attachment');
  perform pg_temp.post_sql(q,'00000','deleted slot reusable');
  perform pg_temp.post_sql(format('update public.post_attachments set deleted_at=null where id=%L',a),'23514','restore cannot exceed ten');
  perform pg_temp.post_check((select count(*) from public.post_attachments where post_id=p and deleted_at is null)=10,'exactly ten live attachments');
  for i in 2..6 loop
    perform pg_temp.post_actor(i);
    perform pg_temp.post_rows(format('select id from public.posts where class_id=%L',c),case when i in (3,4) then 3 else 0 end,'post read access actor '||i);
    perform pg_temp.post_rows(format('select id from public.post_attachments where post_id=%L',p),case when i in (3,4) then 11 else 0 end,'attachment read access actor '||i);
    perform pg_temp.post_sql(format('insert into public.posts(class_id,author_id,kind,title) values(%L,%L,''announcement'',''Forbidden'')',c,current_setting('post_test.u'||i)),'42501','non-owner cannot create actor '||i);
    perform pg_temp.post_rows(format('update public.posts set title=''Forbidden'' where id=%L',p),0,'non-owner cannot edit actor '||i);
    perform pg_temp.post_rows(format('update public.posts set deleted_at=now() where id=%L',p),0,'non-owner cannot soft delete actor '||i);
    perform pg_temp.post_rows(format('update public.classes set course=''Forbidden'' where id=%L',c),0,'non-owner cannot change class actor '||i);
  end loop;
  perform pg_temp.post_actor(1);
  perform pg_temp.post_sql(format('delete from public.posts where id=%L',p),'42501','physical delete denied');
  perform pg_temp.post_rows(format('update public.posts set deleted_at=now() where id=%L',p),1,'owner soft deletes post');
  perform pg_temp.post_check((select deleted_at is not null from public.posts where id=p),'soft delete retains tombstone');
  perform pg_temp.post_check((select count(*) from public.notifications where target_id=p)=2,'edits and soft delete do not notify again');
  -- Checklist 8: revoke an initially active student, then check reads again.
  update public.class_members set status='removed' where class_id=c and student_id=current_setting('post_test.u3')::uuid;
  perform pg_temp.post_actor(3);
  perform pg_temp.post_rows(format('select id from public.posts where class_id=%L',c),0,'removed former active student reads no posts (checklist 8)');
  perform pg_temp.post_rows(format('select id from public.post_attachments where post_id=%L',p),0,'removed student reads no attachments');
  perform pg_temp.post_actor(1);
  update public.classes set archived_at=now() where id=c;
  perform pg_temp.post_sql(base||'''announcement'',''Archived'',null,null)','42501','archived class refuses new posts');
  perform pg_temp.post_rows(format('update public.posts set title=''Archived edit'' where id=%L',p),0,'archived posts cannot be edited');
  perform pg_temp.post_check((select count(*) from public.posts where class_id=c)=3,'failed writes create no posts');
  perform pg_temp.post_check((select count(*) from public.notifications where class_id=c)=6,'failed writes create no inbox rows');
end $$;
select * from post_results order by step;
rollback;
