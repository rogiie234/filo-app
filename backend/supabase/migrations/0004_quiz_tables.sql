-- =====================================================================
-- Filo migration 0004: quizzes, questions, exam sessions
-- Quiz and Exam share one engine. The type is a label; the app applies
-- different default settings (exam: show_correct_answers off).
-- =====================================================================

create table quizzes (
  id                  uuid primary key default gen_random_uuid(),
  class_id            uuid not null references classes(id) on delete cascade,
  author_id           uuid not null references profiles(id),
  type                quiz_type not null default 'quiz',
  title               text not null check (char_length(title) between 1 and 120),
  instructions        text check (instructions is null or char_length(instructions) <= 5000),
  time_limit_minutes  integer not null default 30 check (time_limit_minutes between 1 and 600),
  opens_at            timestamptz,
  closes_at           timestamptz,
  shuffle_questions   boolean not null default true,
  shuffle_options     boolean not null default true,
  show_correct_answers boolean not null default true,
  passing_percent     integer check (passing_percent is null or passing_percent between 0 and 100),
  status              quiz_status not null default 'draft',
  published_at        timestamptz,
  results_released_at timestamptz,
  total_points        integer not null default 0,     -- kept up to date by a trigger
  has_essay           boolean not null default false, -- kept up to date by a trigger
  locked_at           timestamptz,                    -- set when the first student starts
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint quiz_window check (opens_at is null or closes_at is null or closes_at > opens_at)
);

create table questions (
  id           uuid primary key default gen_random_uuid(),
  quiz_id      uuid not null references quizzes(id) on delete cascade,
  position     integer not null default 0,
  type         question_type not null,
  prompt       text not null check (char_length(prompt) between 1 and 1000),
  points       integer not null default 1 check (points between 1 and 1000),
  explanation  text check (explanation is null or char_length(explanation) <= 500),
  ai_generated boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Multiple choice options. 2 to 10 per question (checked when publishing).
create table question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references questions(id) on delete cascade,
  position    integer not null default 0,
  text        text not null check (char_length(text) between 1 and 500),
  created_at  timestamptz not null default now()
);

-- The correct answers. One row per non-essay question. Never readable by students.
create table answer_keys (
  question_id       uuid primary key references questions(id) on delete cascade,
  correct_option_id uuid references question_options(id) on delete set null,
  correct_boolean   boolean,
  accepted_answers  text[]
);

-- One attempt by one student.
create table exam_sessions (
  id               uuid primary key default gen_random_uuid(),
  quiz_id          uuid not null references quizzes(id) on delete cascade,
  student_id       uuid not null references profiles(id),
  attempt_no       integer not null default 1,
  status           session_status not null default 'in_progress',
  started_at       timestamptz not null default now(),   -- server time
  deadline_at      timestamptz not null,
  submitted_at     timestamptz,
  question_order   uuid[] not null default '{}',
  option_orders    jsonb not null default '{}'::jsonb,   -- question id -> ordered option ids
  auto_score       integer not null default 0,
  essay_score      integer not null default 0,
  total_score      integer generated always as (auto_score + essay_score) stored,
  grading_complete boolean not null default false,
  leave_count      integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
-- Only one non-voided attempt per student per quiz.
create unique index uq_active_session on exam_sessions (quiz_id, student_id) where status <> 'voided';

create table exam_answers (
  id             uuid primary key default gen_random_uuid(),
  session_id     uuid not null references exam_sessions(id) on delete cascade,
  question_id    uuid not null references questions(id) on delete cascade,
  option_id      uuid,
  bool_answer    boolean,
  text_answer    text check (text_answer is null or char_length(text_answer) <= 10000),
  answered_at    timestamptz not null default now(),
  is_correct     boolean,
  points_awarded integer check (points_awarded is null or points_awarded >= 0),
  feedback       text check (feedback is null or char_length(feedback) <= 2000),
  graded_by      uuid references profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (session_id, question_id)
);

-- One row per time the student left the app. The id is created on the phone,
-- so a retried upload of the same event is ignored instead of double counted.
create table leave_events (
  id          uuid primary key,
  session_id  uuid not null references exam_sessions(id) on delete cascade,
  student_id  uuid not null references profiles(id),
  left_at     timestamptz not null,
  received_at timestamptz not null default now()
);

-- Audit record for each granted retry.
create table second_chances (
  id                  uuid primary key default gen_random_uuid(),
  quiz_id             uuid not null references quizzes(id) on delete cascade,
  student_id          uuid not null references profiles(id),
  previous_session_id uuid references exam_sessions(id) on delete set null,
  reason              text not null check (char_length(reason) >= 10),
  proof_note          text check (proof_note is null or char_length(proof_note) <= 1000),
  granted_by          uuid not null references profiles(id),
  created_at          timestamptz not null default now()
);

-- Instructor's reusable questions. Copied into a quiz when used.
create table bank_questions (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references profiles(id),
  type           question_type not null,
  prompt         text not null check (char_length(prompt) between 1 and 1000),
  points         integer not null default 1 check (points between 1 and 1000),
  explanation    text check (explanation is null or char_length(explanation) <= 500),
  options        jsonb,   -- [{ "text": "...", "is_correct": true }, ...]
  answer         jsonb,   -- {"boolean": true} or {"accepted": ["..."]}
  source_class_id uuid references classes(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);
