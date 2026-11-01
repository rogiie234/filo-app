-- OWNER DEV SETUP, not a rollback test. Run inspection first, then enable block.
-- Inspect every custom trigger/function; do not create another hook if an existing
-- custom wrapper already sends pushes. Never print tgargs (may contain secrets).
select t.tgname, t.tgenabled, p.proname
from pg_trigger t join pg_proc p on p.oid=t.tgfoid
where t.tgrelid='public.notifications'::regclass and not t.tgisinternal;

-- Run only after inspecting the above, deploying send-push, and setting Vault secrets.
begin;
do $$
begin
  if exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
    where t.tgrelid='public.notifications'::regclass and not t.tgisinternal
      and (p.proname in ('http_request','dispatch_notification_push')
        or t.tgname='trg_notification_push')) then
    raise exception 'Existing webhook trigger found; inspect instead of duplicating it';
  end if;
  if to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    raise exception 'Enable pg_net first';
  end if;
  if not exists(select 1 from vault.decrypted_secrets where name='push_webhook_url'
      and decrypted_secret ~ '^https://[a-z0-9]+[.]supabase[.]co/functions/v1/send-push$')
    or not exists(select 1 from vault.decrypted_secrets where name='push_webhook_secret'
      and length(decrypted_secret)>=32) then
    raise exception 'Configure push_webhook_url and push_webhook_secret in Vault first';
  end if;
end $$;
create trigger trg_notification_push after insert on public.notifications
for each row execute function public.dispatch_notification_push();
commit;
