-- M12-BE-02. Owner applies on DEV; enable webhook separately after deployment.
begin;
alter table public.device_tokens add column registration_version uuid not null default gen_random_uuid();
create function public.rotate_token_registration() returns trigger
language plpgsql set search_path = '' as $$
begin new.registration_version := gen_random_uuid(); return new; end $$;
create trigger trg_token_registration_version before update on public.device_tokens
for each row execute function public.rotate_token_registration();
revoke all on function public.rotate_token_registration() from public, anon, authenticated;

create table public.push_deliveries (
  notification_id uuid not null references public.notifications(id) on delete cascade,
  token_id uuid not null,
  status text not null check (status in ('claimed','sent','invalid_token','failed')),
  error_code text check (error_code in ('provider','timeout','transport','cleanup','store')),
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  primary key(notification_id, token_id)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from public, anon, authenticated;
grant select, insert, update, delete on public.push_deliveries to service_role;

create function public.claim_push_delivery(p_notification uuid, p_token uuid,
  p_user uuid, p_version uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare n public.notifications; t public.device_tokens;
begin
  select * into n from public.notifications where id=p_notification;
  if not found or n.recipient_id<>p_user then return 'stale'; end if;
  select * into t from public.device_tokens where id=p_token and user_id=p_user
    and registration_version=p_version for update;
  if not found then return 'stale'; end if;
  if not exists(select 1 from public.profiles where id=p_user and deleted_at is null)
    then return 'stale'; end if;
  if exists(select 1 from public.notification_settings where user_id=p_user
    and type=n.type and not enabled and (class_id is null or class_id=n.class_id))
    then return 'muted'; end if;
  insert into public.push_deliveries(notification_id,token_id,status)
    values(p_notification,p_token,'claimed') on conflict do nothing;
  if not found then return 'duplicate'; end if;
  return 'claimed';
end $$;

create function public.delete_invalid_push_token(p_token uuid, p_user uuid, p_version uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  delete from public.device_tokens where id=p_token and user_id=p_user
    and registration_version=p_version;
  return found;
end $$;
revoke all on function public.claim_push_delivery(uuid,uuid,uuid,uuid),
  public.delete_invalid_push_token(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.claim_push_delivery(uuid,uuid,uuid,uuid),
  public.delete_invalid_push_token(uuid,uuid,uuid) to service_role;

-- pg_net runs after commit. Enabling the trigger is a separate owner setup action.
create function public.dispatch_notification_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare endpoint text; secret text;
begin
  select decrypted_secret into endpoint from vault.decrypted_secrets where name='push_webhook_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name='push_webhook_secret';
  if endpoint is null or endpoint !~ '^https://[a-z0-9]+[.]supabase[.]co/functions/v1/send-push$'
    or secret is null or length(secret)<32 then
    raise warning 'Push webhook configuration unavailable';
    return new;
  end if;
  perform net.http_post(url:=endpoint,
    headers:=jsonb_build_object('Content-Type','application/json','x-push-secret',secret),
    body:=jsonb_build_object('type','INSERT','schema','public','table','notifications',
      'record',jsonb_build_object('id',new.id),'old_record',null), timeout_milliseconds:=120000);
  return new;
exception when others then
  -- Inbox persistence must not depend on network/extension/configuration availability.
  raise warning 'Push webhook enqueue failed; inbox retained';
  return new;
end $$;
revoke all on function public.dispatch_notification_push() from public, anon, authenticated;
commit;
