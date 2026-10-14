-- =====================================================================
-- Filo migration 0007: Row Level Security, column permissions, function permissions
-- DRAFT: untested. After running, work through the security checklist in the
-- Background Schema Document (Section 6.3) with a student and an instructor.
-- NOTE: Supabase grants broad default privileges on new tables. This file
-- first removes them, then grants back only what the app needs. Re-run the
-- relevant parts if you add tables later.
-- =====================================================================

-- ---------- Enable RLS on every table ----------
alter table profiles              enable row level security;
alter table trusted_devices       enable row level security;
alter table otp_codes             enable row level security;
alter table verified_sessions     enable row level security;
alter table device_tokens         enable row level security;
alter table notification_settings enable row level security;
alter table classes               enable row level security;
alter table class_members         enable row level security;
alter table posts                 enable row level security;
alter table post_attachments      enable row level security;
alter table submissions           enable row level security;
alter table submission_items      enable row level security;
alter table submission_grades     enable row level security;
alter table quizzes               enable row level security;
alter table questions             enable row level security;
alter table question_options      enable row level security;
alter table answer_keys           enable row level security;
alter table exam_sessions         enable row level security;
alter table exam_answers          enable row level security;
alter table leave_events          enable row level security;
alter table second_chances        enable row level security;
alter table bank_questions        enable row level security;
alter table notifications         enable row level security;
alter table ai_usage_log          enable row level security;

-- ---------- Reset table privileges ----------
revoke all on all tables in schema public from anon;
revoke insert, update, delete on all tables in schema public from authenticated;
-- Server-only tables: no client access at all.
revoke all on trusted_devices, otp_codes, verified_sessions, ai_usage_log, leave_events
  from authenticated;

-- ---------- profiles ----------
create policy profiles_select on profiles for select to authenticated
  using (current_user_ok() and shares_class_with(id));
create policy profiles_insert on profiles for insert to authenticated
  with check (current_user_ok() and id = auth.uid() and deleted_at is null);
create policy profiles_update on profiles for update to authenticated
  using (current_user_ok() and id = auth.uid())
  with check (id = auth.uid());
grant insert (id, role, display_name, email, school, google_photo_url, privacy_accepted_at, privacy_version)
  on profiles to authenticated;
grant update (display_name, school, avatar_path, privacy_accepted_at, privacy_version)
  on profiles to authenticated;     -- role and deleted_at can never be changed by the app

-- ---------- device_tokens and notification_settings (own rows) ----------
create policy device_tokens_own on device_tokens for all to authenticated
  using (current_user_ok() and user_id = auth.uid())
  with check (current_user_ok() and user_id = auth.uid());
grant insert, update, delete on device_tokens to authenticated;

create policy notif_settings_own on notification_settings for all to authenticated
  using (current_user_ok() and user_id = auth.uid())
  with check (current_user_ok() and user_id = auth.uid());
grant insert, update, delete on notification_settings to authenticated;

-- ---------- notifications ----------
create policy notifications_select on notifications for select to authenticated
  using (current_user_ok() and recipient_id = auth.uid());
create policy notifications_update on notifications for update to authenticated
  using (current_user_ok() and recipient_id = auth.uid())
  with check (recipient_id = auth.uid());
create policy notifications_delete on notifications for delete to authenticated
  using (current_user_ok() and recipient_id = auth.uid());
grant update (read_at) on notifications to authenticated;
grant delete on notifications to authenticated;

-- ---------- classes ----------
create policy classes_select on classes for select to authenticated
  using (current_user_ok() and (
    owner_id = auth.uid()
    or exists (select 1 from class_members m
                where m.class_id = classes.id and m.student_id = auth.uid()
                  and m.status in ('pending', 'active'))));
create policy classes_insert on classes for insert to authenticated
  with check (current_user_ok() and owner_id = auth.uid() and my_role() = 'instructor');
create policy classes_update on classes for update to authenticated
  using (current_user_ok() and owner_id = auth.uid() and deleted_at is null)
  with check (owner_id = auth.uid());
grant insert (owner_id, course, section, school_year, banner_color, banner_path)
  on classes to authenticated;
grant update (course, section, school_year, banner_color, banner_path)
  on classes to authenticated;   -- join_code, owner, archive, and delete go through functions

-- ---------- class_members (read only; changes go through functions) ----------
create policy members_select on class_members for select to authenticated
  using (current_user_ok() and (student_id = auth.uid() or is_class_owner(class_id)));

-- ---------- posts ----------
create policy posts_select on posts for select to authenticated
  using (current_user_ok() and (is_class_owner(class_id) or is_class_member(class_id)));
create policy posts_insert on posts for insert to authenticated
  with check (current_user_ok() and author_id = auth.uid()
              and is_class_owner(class_id) and class_is_open(class_id));
create policy posts_update on posts for update to authenticated
  using (current_user_ok() and is_class_owner(class_id) and class_is_open(class_id))
  with check (is_class_owner(class_id));
grant insert (class_id, author_id, kind, title, body, points, due_at, accept_late, allow_files, max_files)
  on posts to authenticated;
grant update (title, body, points, due_at, accept_late, allow_files, max_files, deleted_at)
  on posts to authenticated;

-- ---------- post_attachments ----------
create policy attachments_select on post_attachments for select to authenticated
  using (current_user_ok() and can_see_post(post_id));
create policy attachments_insert on post_attachments for insert to authenticated
  with check (current_user_ok() and owns_post(post_id));
create policy attachments_update on post_attachments for update to authenticated
  using (current_user_ok() and owns_post(post_id))
  with check (owns_post(post_id));
grant insert (post_id, kind, name, storage_path, url, mime_type, size_bytes, sort_order)
  on post_attachments to authenticated;
grant update (name, sort_order, deleted_at) on post_attachments to authenticated;

-- ---------- submissions (read only; changes go through functions) ----------
create policy submissions_select on submissions for select to authenticated
  using (current_user_ok() and (
    student_id = auth.uid()
    or (status = 'turned_in' and owns_post(post_id))));

-- ---------- submission_items ----------
create policy items_select on submission_items for select to authenticated
  using (current_user_ok() and can_see_submission(submission_id));
create policy items_insert on submission_items for insert to authenticated
  with check (current_user_ok() and own_draft_submission(submission_id));
create policy items_update on submission_items for update to authenticated
  using (current_user_ok() and own_draft_submission(submission_id))
  with check (own_draft_submission(submission_id));
grant insert (submission_id, kind, name, storage_path, url, text_content, mime_type, size_bytes, sort_order)
  on submission_items to authenticated;
grant update (deleted_at) on submission_items to authenticated;   -- soft delete only

-- ---------- submission_grades (students see only returned grades) ----------
create policy grades_select on submission_grades for select to authenticated
  using (current_user_ok() and (
    is_class_owner(submission_class(submission_id))
    or (returned_at is not null and submission_student(submission_id) = auth.uid())));

-- ---------- quizzes ----------
create policy quizzes_select on quizzes for select to authenticated
  using (current_user_ok() and (
    is_class_owner(class_id)
    or (status = 'published' and is_class_member(class_id))));
create policy quizzes_insert on quizzes for insert to authenticated
  with check (current_user_ok() and author_id = auth.uid()
              and is_class_owner(class_id) and class_is_open(class_id));
create policy quizzes_update on quizzes for update to authenticated
  using (current_user_ok() and is_class_owner(class_id))
  with check (is_class_owner(class_id));
grant insert (class_id, author_id, type, title, instructions, time_limit_minutes, opens_at,
              closes_at, shuffle_questions, shuffle_options, show_correct_answers, passing_percent)
  on quizzes to authenticated;
grant update (type, title, instructions, time_limit_minutes, opens_at, closes_at,
              shuffle_questions, shuffle_options, show_correct_answers, passing_percent, deleted_at)
  on quizzes to authenticated;   -- status and release fields change only through functions

-- ---------- questions, options, answer keys (instructor only) ----------
create policy questions_owner on questions for all to authenticated
  using (current_user_ok() and is_quiz_owner(quiz_id))
  with check (current_user_ok() and is_quiz_owner(quiz_id));
grant insert, update, delete on questions to authenticated;

create policy options_owner on question_options for all to authenticated
  using (current_user_ok() and is_question_owner(question_id))
  with check (current_user_ok() and is_question_owner(question_id));
grant insert, update, delete on question_options to authenticated;

create policy keys_owner on answer_keys for all to authenticated
  using (current_user_ok() and is_question_owner(question_id))
  with check (current_user_ok() and is_question_owner(question_id));
grant insert, update, delete on answer_keys to authenticated;

-- ---------- exam_sessions, exam_answers, second_chances (instructor read only) ----------
create policy sessions_owner_select on exam_sessions for select to authenticated
  using (current_user_ok() and is_quiz_owner(quiz_id));
create policy answers_owner_select on exam_answers for select to authenticated
  using (current_user_ok() and is_quiz_owner(session_quiz(session_id)));
create policy second_chances_owner_select on second_chances for select to authenticated
  using (current_user_ok() and is_quiz_owner(quiz_id));
-- leave_events, trusted_devices, otp_codes, verified_sessions, ai_usage_log: no policies = server only.

-- ---------- bank_questions (own rows) ----------
create policy bank_own on bank_questions for all to authenticated
  using (current_user_ok() and owner_id = auth.uid())
  with check (current_user_ok() and owner_id = auth.uid());
grant insert, update, delete on bank_questions to authenticated;

-- ---------- Function permissions ----------
-- Remove default execute rights, then grant only what the app may call.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.sig);
  end loop;
end $$;

-- Helper checks used inside policies.
grant execute on function
  current_user_ok(), is_session_verified(), my_role(), is_class_owner(uuid), is_class_member(uuid),
  has_class_link(uuid), class_is_open(uuid), shares_class_with(uuid), is_quiz_owner(uuid),
  is_question_owner(uuid), owns_post(uuid), can_see_post(uuid), submission_student(uuid),
  submission_class(uuid), own_draft_submission(uuid), can_see_submission(uuid), session_quiz(uuid),
  generate_join_code()    -- used as the default value of classes.join_code
  to authenticated;

-- Functions the app calls.
grant execute on function
  request_join(text), decide_join(uuid, boolean), approve_all_pending(uuid),
  remove_member(uuid, uuid), leave_class(uuid), archive_class(uuid), restore_class(uuid),
  delete_class(uuid, text), restore_deleted_class(uuid), owned_class_count(),
  start_submission(uuid), turn_in(uuid, text), unsubmit(uuid),
  save_grade(uuid, integer, text), return_grades(uuid[]), return_all_graded(uuid),
  publish_quiz(uuid), start_exam(uuid), get_exam(uuid),
  save_answer(uuid, uuid, uuid, boolean, text), log_leave(uuid, uuid, timestamptz),
  submit_exam(uuid), get_my_session(uuid), get_result(uuid),
  grade_essay(uuid, integer, text), release_results(uuid),
  grant_second_chance(uuid, uuid, text, text)
  to authenticated;

-- Everything else (notify, finalize_*, begin_ai_request, ...) is for the server only.
grant execute on all functions in schema public to service_role;
