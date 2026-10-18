-- Maintained pull templates; NOT executed by the assistant.
-- PREPARE is per connection. Execute with an ordinary verified authenticated
-- role/JWT context, never postgres/service_role for permission acceptance.
-- First page: lower=last completed watermark, cursor_time=lower, cursor_id=NULL.
-- Later pages: keep lower fixed, use last row's full timestamp and primary key.
-- Preserve PostgreSQL timestamp precision. Do not filter deleted_at.

prepare pull_profiles(timestamptz,timestamptz,uuid) as
select * from public.profiles
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_profiles('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_device_tokens(timestamptz,timestamptz,uuid) as
select * from public.device_tokens
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_device_tokens('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_notification_settings(timestamptz,timestamptz,uuid) as
select * from public.notification_settings
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_notification_settings('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_classes(timestamptz,timestamptz,uuid) as
select * from public.classes
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_classes('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_class_members(timestamptz,timestamptz,uuid) as
select * from public.class_members
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_class_members('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_posts(timestamptz,timestamptz,uuid) as
select * from public.posts
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_posts('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_post_attachments(timestamptz,timestamptz,uuid) as
select * from public.post_attachments
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_post_attachments('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_submissions(timestamptz,timestamptz,uuid) as
select * from public.submissions
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_submissions('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_submission_items(timestamptz,timestamptz,uuid) as
select * from public.submission_items
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_submission_items('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_submission_grades(timestamptz,timestamptz,uuid) as
select * from public.submission_grades
where updated_at >= $1
  and ($3 is null or (updated_at, submission_id) > ($2, $3))
order by updated_at asc, submission_id asc limit 200;
-- execute pull_submission_grades('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_quizzes(timestamptz,timestamptz,uuid) as
select * from public.quizzes
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_quizzes('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_questions(timestamptz,timestamptz,uuid) as
select * from public.questions
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_questions('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_exam_sessions(timestamptz,timestamptz,uuid) as
select * from public.exam_sessions
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_exam_sessions('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_exam_answers(timestamptz,timestamptz,uuid) as
select * from public.exam_answers
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_exam_answers('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_bank_questions(timestamptz,timestamptz,uuid) as
select * from public.bank_questions
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_bank_questions('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);

prepare pull_notifications(timestamptz,timestamptz,uuid) as
select * from public.notifications
where updated_at >= $1
  and ($3 is null or (updated_at, id) > ($2, $3))
order by updated_at asc, id asc limit 200;
-- execute pull_notifications('1970-01-01T00:00:00Z','1970-01-01T00:00:00Z',null);
