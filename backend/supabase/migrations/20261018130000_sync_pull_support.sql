-- M6 incremental pull support. Prepared only; owner applies on DEV.
begin;
-- Read marks change after creation, so created_at cannot sync this table.
alter table public.notifications add column updated_at timestamptz not null default now();
create trigger trg_notifications_updated before update on public.notifications
for each row execute function public.set_updated_at();
-- Defaults alone permit explicit timestamps on broadly granted INSERTs.
-- Keep existing UPDATE triggers; enforce server time on INSERT as well.
create trigger trg_profiles_insert_time before insert on public.profiles
for each row execute function public.set_updated_at();
create index if not exists idx_profiles_sync on public.profiles (updated_at, id);
create trigger trg_device_tokens_insert_time before insert on public.device_tokens
for each row execute function public.set_updated_at();
create index if not exists idx_device_tokens_sync on public.device_tokens (updated_at, id);
create trigger trg_notification_settings_insert_time before insert on public.notification_settings
for each row execute function public.set_updated_at();
create index if not exists idx_notification_settings_sync on public.notification_settings (updated_at, id);
create trigger trg_classes_insert_time before insert on public.classes
for each row execute function public.set_updated_at();
create index if not exists idx_classes_sync on public.classes (updated_at, id);
create trigger trg_class_members_insert_time before insert on public.class_members
for each row execute function public.set_updated_at();
create index if not exists idx_class_members_sync on public.class_members (updated_at, id);
create trigger trg_posts_insert_time before insert on public.posts
for each row execute function public.set_updated_at();
create index if not exists idx_posts_sync on public.posts (updated_at, id);
create trigger trg_post_attachments_insert_time before insert on public.post_attachments
for each row execute function public.set_updated_at();
create index if not exists idx_post_attachments_sync on public.post_attachments (updated_at, id);
create trigger trg_submissions_insert_time before insert on public.submissions
for each row execute function public.set_updated_at();
create index if not exists idx_submissions_sync on public.submissions (updated_at, id);
create trigger trg_submission_items_insert_time before insert on public.submission_items
for each row execute function public.set_updated_at();
create index if not exists idx_submission_items_sync on public.submission_items (updated_at, id);
create trigger trg_submission_grades_insert_time before insert on public.submission_grades
for each row execute function public.set_updated_at();
create index if not exists idx_submission_grades_sync on public.submission_grades (updated_at, submission_id);
create trigger trg_quizzes_insert_time before insert on public.quizzes
for each row execute function public.set_updated_at();
create index if not exists idx_quizzes_sync on public.quizzes (updated_at, id);
create trigger trg_questions_insert_time before insert on public.questions
for each row execute function public.set_updated_at();
create index if not exists idx_questions_sync on public.questions (updated_at, id);
create trigger trg_exam_sessions_insert_time before insert on public.exam_sessions
for each row execute function public.set_updated_at();
create index if not exists idx_exam_sessions_sync on public.exam_sessions (updated_at, id);
create trigger trg_exam_answers_insert_time before insert on public.exam_answers
for each row execute function public.set_updated_at();
create index if not exists idx_exam_answers_sync on public.exam_answers (updated_at, id);
create trigger trg_bank_questions_insert_time before insert on public.bank_questions
for each row execute function public.set_updated_at();
create index if not exists idx_bank_questions_sync on public.bank_questions (updated_at, id);
create trigger trg_notifications_insert_time before insert on public.notifications
for each row execute function public.set_updated_at();
create index if not exists idx_notifications_sync on public.notifications (updated_at, id);

-- Active students need the class tombstone to evict cached class content.
-- Former students still learn revocation through their own membership row.
drop policy classes_select on public.classes;
create policy classes_select on public.classes for select to authenticated
using (public.current_user_ok() and (owner_id = auth.uid() or exists (
  select 1 from public.class_members m
  where m.class_id = classes.id and m.student_id = auth.uid()
    and (m.status = 'active' or (m.status = 'pending' and classes.deleted_at is null))
)));
commit;
