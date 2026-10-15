-- =====================================================================
-- Filo migration 0009: scheduled jobs
-- Run this AFTER enabling pg_cron (Dashboard > Database > Extensions).
-- Verify pg_cron is available on your plan.
-- =====================================================================

-- Every minute: submit expired exam sessions, then release ready results.
select cron.schedule(
  'filo-finalize-exams', '* * * * *',
  $$ select public.finalize_expired_sessions() $$);

-- Daily cleanup.
select cron.schedule(
  'filo-purge-ai-log', '15 3 * * *',
  $$ delete from public.ai_usage_log where created_at < now() - interval '30 days' $$);

select cron.schedule(
  'filo-purge-otp', '30 3 * * *',
  $$ delete from public.otp_codes where expires_at < now() - interval '1 day' $$);

select cron.schedule(
  'filo-purge-old-verified-sessions', '45 3 * * *',
  $$ delete from public.verified_sessions where verified_at < now() - interval '90 days' $$);

-- NOT scheduled here: permanent deletion of classes older than 14 days and of
-- soft-deleted attachments. Storage files must be removed through the Storage
-- API, so this is done by the purge-deleted Edge Function (run daily from a
-- Supabase scheduled function or pg_cron plus pg_net). See Section 7.3 of the
-- Background Schema Document.
