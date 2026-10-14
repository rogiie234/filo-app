-- =====================================================================
-- Filo migration 0002: account and security tables
-- =====================================================================

-- One row per person. The id equals the Google login's auth id but has NO
-- foreign key, so the row can outlive the login when an account is deleted
-- (submissions and grades stay linked to a 'Deleted User').
create table profiles (
  id                  uuid primary key,
  role                user_role not null,
  display_name        text not null check (char_length(display_name) between 1 and 80),
  email               text,
  school              text check (school is null or char_length(school) <= 120),
  google_photo_url    text,
  avatar_path         text,                 -- uploaded photo in the avatars bucket
  privacy_accepted_at timestamptz,
  privacy_version     text,
  deleted_at          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Devices that passed the OTP step. Server only.
create table trusted_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  device_hash  text not null,
  label        text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (user_id, device_hash)
);

-- One-time email codes. Only a hash is stored. Server only.
create table otp_codes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_hash text not null,
  code_hash   text not null,
  expires_at  timestamptz not null,
  attempts    integer not null default 0 check (attempts >= 0),
  consumed_at timestamptz,
  created_at  timestamptz not null default now()
);

-- Login sessions that completed OTP. The session_id comes from the login
-- token's session_id claim. Server only.
create table verified_sessions (
  session_id  uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_hash text,
  verified_at timestamptz not null default now()
);

-- Push notification tokens.
create table device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fcm_token   text not null unique,
  device_hash text,
  platform    text not null default 'android',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Notification toggles. class_id null = applies to all classes.
-- No row means the type is on. The class foreign key is added in 0003.
create table notification_settings (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  class_id   uuid,
  type       notification_type not null,
  enabled    boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_notification_settings
  on notification_settings (user_id, coalesce(class_id, '00000000-0000-0000-0000-000000000000'::uuid), type);
