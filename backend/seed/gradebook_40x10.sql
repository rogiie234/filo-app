-- DEV SQL Editor, postgres, whole file. Synthetic accounts; rollback-only.
-- No real credentials/storage. EXPLAIN executes SELECTs under verified owner RLS.
-- Read Execution Time (<1000 ms target) and actual Index/Bitmap/Seq Scan nodes.
-- Small fixtures can correctly use sequential scans; do not disable seqscan.
-- Includes planning, buffers and natural plans; no performance claim until owner run.
begin;
do $$
declare owner_id uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid();
 c uuid:=gen_random_uuid(); u uuid; p uuid; s uuid; i integer; j integer;
begin
 insert into auth.users(id) values(owner_id);
 insert into auth.sessions(id,user_id) values(sid,owner_id);
 insert into profiles(id,role,display_name) values(owner_id,'instructor','Gradebook fixture owner');
 insert into verified_sessions(session_id,user_id) values(sid,owner_id);
 insert into classes(id,owner_id,course,section,school_year) values(c,owner_id,'Gradebook performance fixture','40 x 10','2026');
 perform set_config('gradebook.class',c::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'session_id',sid,'role','authenticated')::text,true);
 for i in 1..40 loop
  u:=gen_random_uuid();
  insert into auth.users(id) values(u);
  insert into profiles(id,role,display_name) values(u,'student','Gradebook fixture '||lpad(i::text,2,'0'));
  insert into class_members(class_id,student_id,status) values(c,u,'active');
 end loop;
 for j in 1..10 loop
  p:=gen_random_uuid();
  insert into posts(id,class_id,author_id,kind,title,points,due_at) values(p,c,owner_id,'assignment','Assignment '||j,100,now()-interval '1 day');
  for u in select student_id from class_members where class_id=c loop
   s:=gen_random_uuid();
   insert into submissions(id,post_id,student_id,status,submitted_at) values(s,p,u,'turned_in',now()-interval '2 days');
   insert into submission_grades(submission_id,score,graded_by,graded_at,returned_at) values(s,(j*7)%101,owner_id,now(),now());
  end loop;
 end loop;
end $$;
-- Transactional fixtures are not auto-analyzed before rollback.
analyze public.class_members;
analyze public.profiles;
analyze public.posts;
analyze public.submissions;
analyze public.submission_grades;
set local role authenticated;
explain (analyze, buffers, settings)
select m.student_id,m.status,p.display_name,p.avatar_path
from public.class_members m join public.profiles p on p.id=m.student_id
where m.class_id=current_setting('gradebook.class')::uuid and m.status in ('active','left','removed')
order by m.student_id;
explain (analyze, buffers, settings)
select id,title,points,due_at,created_at from public.posts
where class_id=current_setting('gradebook.class')::uuid and kind='assignment' and deleted_at is null
order by created_at desc,id;
explain (analyze, buffers, settings)
select s.id,s.post_id,s.student_id,s.status,s.submitted_at,s.is_late
from public.submissions s join public.posts p on p.id=s.post_id
where p.class_id=current_setting('gradebook.class')::uuid and p.kind='assignment'
 and p.deleted_at is null and s.status='turned_in';
explain (analyze, buffers, settings)
select g.submission_id,g.score,g.feedback,g.returned_at
from public.submission_grades g join public.submissions s on s.id=g.submission_id
join public.posts p on p.id=s.post_id
where p.class_id=current_setting('gradebook.class')::uuid and p.kind='assignment'
 and p.deleted_at is null and s.status='turned_in';
reset role;
-- Fixture dimensions must be 40, 10, 400, 400. Not a timing acceptance result.
select (select count(*) from class_members where class_id=c.id) members,
 (select count(*) from posts where class_id=c.id) assignments,
 (select count(*) from submissions s join posts p on p.id=s.post_id where p.class_id=c.id) submissions,
 (select count(*) from submission_grades g join submissions s on s.id=g.submission_id join posts p on p.id=s.post_id where p.class_id=c.id) grades
from classes c where c.id=current_setting('gradebook.class')::uuid;
rollback;
