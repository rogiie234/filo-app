-- =====================================================================
-- Filo migration 0003: classes, members, posts, attachments, submissions
-- =====================================================================

-- Join code: 6 characters, no look-alikes (I, L, O, 0, 1), stored uppercase.
-- SECURITY DEFINER so the uniqueness check sees every class, not only the caller's.
create or replace function generate_join_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from classes where join_code = code);
  end loop;
  return code;
end $$;

create table classes (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references profiles(id),
  course       text not null check (char_length(course) between 1 and 120),
  section      text not null check (char_length(section) between 1 and 60),
  school_year  text not null check (char_length(school_year) between 1 and 20),
  join_code    text not null unique default generate_join_code(),
  banner_color text,                       -- preset key, null = default banner
  banner_path  text,                       -- uploaded banner in the banners bucket
  archived_at  timestamptz,
  deleted_at   timestamptz,                -- soft delete, 14-day recovery
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Now that classes exists, link notification_settings to it.
alter table notification_settings
  add constraint notification_settings_class_fk
  foreign key (class_id) references classes(id) on delete cascade;

-- One row per student per class. Never deleted, so grades stay linked.
create table class_members (
  id           uuid primary key default gen_random_uuid(),
  class_id     uuid not null references classes(id) on delete cascade,
  student_id   uuid not null references profiles(id),
  status       member_status not null default 'pending',
  requested_at timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   uuid references profiles(id),
  left_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (class_id, student_id)
);

create table posts (
  id           uuid primary key default gen_random_uuid(),
  class_id     uuid not null references classes(id) on delete cascade,
  author_id    uuid not null references profiles(id),
  kind         post_kind not null,
  title        text not null check (char_length(title) between 1 and 120),
  body         text check (body is null or char_length(body) <= 5000),
  points       integer check (points is null or points >= 0),   -- whole numbers only
  due_at       timestamptz,
  accept_late  boolean not null default true,
  allow_files  boolean not null default true,
  max_files    integer not null default 5 check (max_files between 1 and 5),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  constraint posts_assignment_fields check (
    (kind = 'assignment' and points is not null and due_at is not null)
    or (kind <> 'assignment' and points is null and due_at is null)
  )
);

create table post_attachments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references posts(id) on delete cascade,
  kind         attachment_kind not null,
  name         text not null check (char_length(name) <= 255),
  storage_path text,
  url          text,
  mime_type    text,
  size_bytes   bigint check (size_bytes is null or size_bytes <= 26214400),
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  constraint attachment_shape check (
    (kind = 'file' and storage_path is not null and url is null)
    or (kind = 'link' and url is not null and storage_path is null)
  )
);

-- One turn-in package per student per assignment. Holds many items.
create table submissions (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references posts(id) on delete cascade,
  student_id      uuid not null references profiles(id),
  status          submission_status not null default 'draft',
  private_comment text check (private_comment is null or char_length(private_comment) <= 1000),
  submitted_at    timestamptz,
  is_late         boolean not null default false,
  unsubmit_until  timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (post_id, student_id)
);

create table submission_items (
  id            uuid primary key default gen_random_uuid(),
  submission_id uuid not null references submissions(id) on delete cascade,
  kind          item_kind not null,
  name          text check (name is null or char_length(name) <= 255),
  storage_path  text,
  url           text,
  text_content  text check (text_content is null or char_length(text_content) <= 10000),
  mime_type     text,
  size_bytes    bigint check (size_bytes is null or size_bytes <= 26214400),
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint item_shape check (
    (kind = 'file' and storage_path is not null and url is null and text_content is null)
    or (kind = 'link' and url is not null and storage_path is null and text_content is null)
    or (kind = 'text' and text_content is not null and storage_path is null and url is null)
  )
);

-- Kept apart from submissions so draft grades stay hidden from students.
create table submission_grades (
  submission_id uuid primary key references submissions(id) on delete cascade,
  score         integer check (score is null or score >= 0),    -- whole numbers only
  feedback      text check (feedback is null or char_length(feedback) <= 2000),
  graded_by     uuid references profiles(id),
  graded_at     timestamptz,
  returned_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
