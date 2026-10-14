-- =====================================================================
-- Filo migration 0001: enumerations and shared helpers
-- DRAFT: written without access to a live Supabase project.
-- Run the migrations in order on the DEV project first, fix any errors,
-- then repeat on prod.
-- =====================================================================

create type user_role         as enum ('student', 'instructor');
create type member_status     as enum ('pending', 'active', 'declined', 'removed', 'left');
create type post_kind         as enum ('announcement', 'material', 'assignment');
create type attachment_kind   as enum ('file', 'link');
create type item_kind         as enum ('file', 'link', 'text');
create type submission_status as enum ('draft', 'turned_in');
create type quiz_type         as enum ('quiz', 'exam');
create type quiz_status       as enum ('draft', 'published');
create type question_type     as enum ('multiple_choice', 'true_false', 'identification', 'essay');
create type session_status    as enum ('in_progress', 'submitted', 'auto_submitted', 'voided');
create type notification_type as enum (
  'announcement', 'material', 'assignment', 'quiz_published', 'grade_returned',
  'results_released', 'join_request', 'join_approved', 'join_declined',
  'link_report', 'second_chance', 'removed_from_class'
);
create type ai_kind           as enum ('generate_quiz', 'chat', 'summary', 'flashcards', 'practice_quiz');
create type ai_status         as enum ('started', 'success', 'failed');
create type join_result       as enum ('requested', 'not_found', 'already_member', 'already_pending', 'archived');

-- Keeps updated_at current. Attached to every synced table in 0006.
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Normalizes text for identification answers: trim, collapse spaces, lowercase.
create or replace function norm_text(t text) returns text
language sql immutable as $$
  select lower(regexp_replace(btrim(coalesce(t, '')), '\s+', ' ', 'g'));
$$;
