-- Allow stable client-generated IDs for publication/attachment retry recovery.
-- Existing column grants exclude id; explicit IDs otherwise fail with 42501.
-- This permits INSERT only. IDs and ownership fields remain immutable on UPDATE.
-- Existing RLS still requires a verified owning instructor and an open class.
grant insert (id) on public.posts to authenticated;
grant insert (id) on public.post_attachments to authenticated;
