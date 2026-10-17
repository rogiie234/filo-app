-- Refuse unsubmit at or after the window boundary, including late turn-ins.
-- Preserve the existing verified-session, ownership and returned-grade guards.
begin;

create or replace function public.unsubmit(p_submission uuid) returns submissions
language plpgsql security definer set search_path = public as $$
declare s submissions;
begin
  if current_setting('role', true) = 'authenticated'
     and not public.current_user_ok() then
    raise exception 'OTP verification required' using errcode = '42501';
  end if;
  select * into s from submissions where id = p_submission and student_id = auth.uid();
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'turned_in' then raise exception 'This work is not turned in'; end if;
  if s.unsubmit_until is null or now() >= s.unsubmit_until then raise exception 'The unsubmit window has passed'; end if;
  if exists (select 1 from submission_grades g
              where g.submission_id = s.id and g.returned_at is not null) then
    raise exception 'A grade was already returned';
  end if;
  update submissions
     set status = 'draft', submitted_at = null, is_late = false, unsubmit_until = null
   where id = s.id returning * into s;
  return s;
end $$;

commit;
