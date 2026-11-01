-- OWNER ONLY, DEV first, after migration and both Edge deployments.
-- Configure Edge ACCOUNT_DELETION_SECRET and Vault account_deletion_secret with the
-- same dedicated secret, plus Vault project_url. Never put secret values in this file.
-- Existing pg_cron / pg_net / Vault are prerequisites; no extensions are installed here.
begin;
create or replace function public.invoke_account_deletion_recovery() returns bigint
language plpgsql security definer set search_path = '' as $$
declare project_url text; recovery_secret text; request_id bigint;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets where name='project_url';
  select decrypted_secret into recovery_secret from vault.decrypted_secrets where name='account_deletion_secret';
  if nullif(project_url,'') is null or nullif(recovery_secret,'') is null then
    raise exception 'Configure Vault project_url and account_deletion_secret';
  end if;
  select net.http_post(url:=rtrim(project_url,'/')||'/functions/v1/process-account-deletions',
    headers:=jsonb_build_object('Content-Type','application/json','x-account-deletion-secret',recovery_secret),
    body:='{}'::jsonb,timeout_milliseconds:=120000) into request_id;
  return request_id;
end $$;
revoke all on function public.invoke_account_deletion_recovery() from public,anon,authenticated,service_role;
-- Fail setup before scheduling if the required Vault configuration is missing.
do $$
begin
  if not exists(select 1 from vault.decrypted_secrets where name='project_url' and nullif(decrypted_secret,'') is not null)
    or not exists(select 1 from vault.decrypted_secrets where name='account_deletion_secret' and nullif(decrypted_secret,'') is not null) then
    raise exception 'Configure Vault project_url and account_deletion_secret first';
  end if;
end $$;
select cron.schedule('filo-account-deletions','*/5 * * * *','select public.invoke_account_deletion_recovery()');
commit;
