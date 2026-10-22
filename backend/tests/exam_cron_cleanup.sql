-- M8-BE-02 unattended proof, CLEANUP. DEV, postgres. Run only AFTER saving results.
-- Narrow reserved IDs plus markers; refuse mismatched or expanded fixture scope.
begin;
set local search_path=public;
select set_config('request.jwt.claims','{}',true);
do $$
declare v_owner uuid:='8b020000-0000-4000-8000-000000000001';
  v_student uuid:='8b020000-0000-4000-8000-000000000002';
  v_class uuid:='8b020000-0000-4000-8000-000000000003';
begin
  if not exists(select 1 from classes c join profiles p on p.id=c.owner_id
    where c.id=v_class and c.owner_id=v_owner and c.course='M8-BE-02 CRON PROOF ONLY'
      and c.section='M8B-CRON' and p.display_name='M8-BE-02 CRON PROOF ONLY')
    or not exists(select 1 from profiles where id=v_student and display_name='M8-BE-02 CRON PROOF ONLY') then
    raise exception 'Proof markers absent or mismatched; no cleanup performed';
  end if;
  if exists(select 1 from classes where owner_id=v_owner and id<>v_class)
    or exists(select 1 from class_members where student_id in (v_student,v_owner) and class_id<>v_class) then
    raise exception 'Proof users have unrelated classes/memberships; no cleanup performed';
  end if;
  if exists(select 1 from quizzes where class_id=v_class and
      (id<>'8b020000-0000-4000-8000-000000000004' or title<>'M8-BE-02 CRON PROOF ONLY' or author_id<>v_owner))
    or exists(select 1 from posts where class_id=v_class)
    or exists(select 1 from class_members where class_id=v_class and student_id<>v_student)
    or exists(select 1 from questions q join quizzes z on z.id=q.quiz_id where z.class_id=v_class
      and q.id<>'8b020000-0000-4000-8000-000000000005')
    or exists(select 1 from exam_sessions s join quizzes z on z.id=s.quiz_id where z.class_id=v_class
      and (s.id<>'8b020000-0000-4000-8000-000000000006' or s.student_id<>v_student)) then
    raise exception 'Proof class contains unrelated content; no cleanup performed';
  end if;
  delete from notifications where class_id=v_class;
  delete from classes where id=v_class;
  delete from profiles where id in (v_owner,v_student);
  delete from auth.users where id in (v_owner,v_student);
end $$;
select not exists(select 1 from public.classes where id='8b020000-0000-4000-8000-000000000003')
  and not exists(select 1 from public.exam_sessions where id='8b020000-0000-4000-8000-000000000006')
  and not exists(select 1 from auth.users where id in
    ('8b020000-0000-4000-8000-000000000001','8b020000-0000-4000-8000-000000000002')) as fixtures_removed;
commit;
