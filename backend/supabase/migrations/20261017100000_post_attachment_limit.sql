-- Serialize additions/restores on the parent; include UPDATE restores in the cap.
-- Parent row lock is shared by all attachment writers for this post.
create or replace function public.enforce_attachment_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is not null then return new; end if;
  perform 1 from public.posts where id = new.post_id for update;
  if (select count(*) from public.post_attachments
      where post_id = new.post_id and deleted_at is null and id <> new.id) >= 10 then
    raise exception 'A post can have at most 10 attachments' using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function public.enforce_attachment_limit() from public, anon, authenticated;
drop trigger trg_attachment_limit on public.post_attachments;
create trigger trg_attachment_limit before insert or update of deleted_at, post_id
on public.post_attachments for each row execute function public.enforce_attachment_limit();
