-- =====================================================================
-- Filo migration 0005: notifications, AI usage log, indexes
-- =====================================================================

-- In-app inbox. A database webhook on INSERT calls the send-push Edge Function.
create table notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles(id) on delete cascade,
  class_id     uuid references classes(id) on delete cascade,
  type         notification_type not null,
  title        text not null,
  body         text,
  target_type  text,      -- 'post', 'quiz', 'class', 'class_members', ...
  target_id    uuid,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);

-- Hidden monitoring record. No questions, answers, or file text are stored.
-- Rows older than 30 days are deleted by a scheduled job (0009).
create table ai_usage_log (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null,
  kind        ai_kind not null,
  status      ai_status not null default 'started',
  error_code  text,
  created_at  timestamptz not null default now(),
  finished_at timestamptz
);

-- ---------- Indexes ----------
create index idx_classes_owner          on classes (owner_id) where deleted_at is null;
create index idx_members_student        on class_members (student_id, status);
create index idx_members_class          on class_members (class_id, status);
create index idx_posts_class            on posts (class_id, created_at desc);
create index idx_posts_due              on posts (class_id, due_at) where kind = 'assignment';
create index idx_attachments_post       on post_attachments (post_id);
create index idx_submissions_post       on submissions (post_id, status);
create index idx_submissions_student    on submissions (student_id);
create index idx_items_submission       on submission_items (submission_id);
create index idx_quizzes_class          on quizzes (class_id, status);
create index idx_questions_quiz         on questions (quiz_id, position);
create index idx_options_question       on question_options (question_id, position);
create index idx_sessions_quiz          on exam_sessions (quiz_id);
create index idx_sessions_student       on exam_sessions (student_id);
create index idx_sessions_open          on exam_sessions (deadline_at) where status = 'in_progress';
create index idx_answers_session        on exam_answers (session_id);
create index idx_leave_session          on leave_events (session_id);
create index idx_bank_owner             on bank_questions (owner_id) where deleted_at is null;
create index idx_notifications_inbox    on notifications (recipient_id, created_at desc);
create index idx_notifications_unread   on notifications (recipient_id) where read_at is null;
create index idx_ai_log_user            on ai_usage_log (user_id, created_at desc);
create index idx_trusted_devices_user   on trusted_devices (user_id);
create index idx_otp_user               on otp_codes (user_id, created_at desc);
