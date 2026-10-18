-- M5-SA-01 accepted by owner 2026-10-18. New migration; no applied edits.
-- A timestamp-free turned_in row represents instructor-scored missing work.
begin;
create or replace function public.grade_missing(p_post uuid,p_student uuid,p_score integer,p_feedback text default null)
returns public.submission_grades
language plpgsql security definer set search_path = public as $$
declare p posts; s submissions;
begin
 if not public.current_user_ok() then
  raise exception 'OTP verification required' using errcode='42501';
 end if;
 select * into p from posts where id=p_post;
 if not found or p.kind<>'assignment' or p.deleted_at is not null then raise exception 'Assignment not found'; end if;
 if not is_class_owner(p.class_id) then raise exception 'Not allowed'; end if;
 if not class_is_open(p.class_id) then raise exception 'This class is archived'; end if;
 if p.due_at is null or now()<=p.due_at then raise exception 'Assignment is not past due'; end if;
 if p_score is null or p_score<0 or p_score>p.points then raise exception 'Score must be between 0 and %',p.points; end if;
 if not exists(select 1 from class_members where class_id=p.class_id and student_id=p_student and status in ('active','left','removed')) then
  raise exception 'Student is not a member or former member';
 end if;
 -- Unique post/student key coordinates simultaneous start_submission calls.
 insert into submissions(post_id,student_id) values(p_post,p_student)
 on conflict(post_id,student_id) do nothing;
 select * into strict s from submissions where post_id=p_post and student_id=p_student for update;
 if s.status<>'draft' then raise exception 'Student already has turned-in work'; end if;
 -- Same submission -> assignment lock order as turn_in/save_grade.
 select * into p from posts where id=p_post for share;
 if p.deleted_at is not null or p.kind<>'assignment' or p.due_at is null or now()<=p.due_at then
  raise exception 'Assignment is not available for missing-work scoring';
 end if;
 if not is_class_owner(p.class_id) or not class_is_open(p.class_id) then raise exception 'Not allowed'; end if;
 -- Discard unfinished item metadata, never publish private draft contents as work.
 -- No Storage API calls in SQL: unreferenced draft blobs remain for class purge.
 delete from submission_items where submission_id=s.id;
 update submissions set status='turned_in',submitted_at=null,unsubmit_until=null,
  is_late=false,private_comment=null where id=s.id;
 return public.save_grade(s.id,p_score,p_feedback);
end $$;
revoke all on function public.grade_missing(uuid,uuid,integer,text) from public,anon;
grant execute on function public.grade_missing(uuid,uuid,integer,text) to authenticated,service_role;
commit;
