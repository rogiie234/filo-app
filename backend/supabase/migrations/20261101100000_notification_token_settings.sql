-- M12-BE-01: verified, account-scoped notification writes.
begin;

create function public.register_device_token(
  p_fcm_token text, p_device_hash text, p_platform text
) returns public.device_tokens
language plpgsql security definer set search_path = '' as $$
declare v_row public.device_tokens;
begin
  if not public.current_user_ok() or not exists (
    select 1 from public.profiles where id = auth.uid() and deleted_at is null
  ) then
    raise exception 'Verified active account required' using errcode = '42501';
  end if;
  if p_fcm_token is null or btrim(p_fcm_token) = '' or p_fcm_token <> btrim(p_fcm_token)
    or p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$'
    or p_platform is distinct from 'android' then
    raise exception 'Invalid device token, hash or platform' using errcode = '22023';
  end if;
  -- The unique token identifies the push destination across account switches.
  insert into public.device_tokens(user_id, fcm_token, device_hash, platform)
    values(auth.uid(), p_fcm_token, p_device_hash, p_platform)
    on conflict (fcm_token) do update set user_id = excluded.user_id,
      device_hash = excluded.device_hash, platform = excluded.platform
    returning * into v_row;
  return v_row;
end;
$$;

create function public.unregister_device_token(p_fcm_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.current_user_ok() or not exists (
    select 1 from public.profiles where id = auth.uid() and deleted_at is null
  ) then
    raise exception 'Verified active account required' using errcode = '42501';
  end if;
  if p_fcm_token is null or btrim(p_fcm_token) = '' or p_fcm_token <> btrim(p_fcm_token) then
    raise exception 'Invalid device token' using errcode = '22023';
  end if;
  delete from public.device_tokens where user_id = auth.uid() and fcm_token = p_fcm_token;
end;
$$;

create function public.set_notification_setting(
  p_type public.notification_type, p_class_id uuid, p_enabled boolean
) returns public.notification_settings
language plpgsql security definer set search_path = '' as $$
declare v_row public.notification_settings;
begin
  if not public.current_user_ok() or not exists (
    select 1 from public.profiles where id = auth.uid() and deleted_at is null
  ) then
    raise exception 'Verified active account required' using errcode = '42501';
  end if;
  if p_type is null or p_enabled is null
    or p_class_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'Invalid notification setting' using errcode = '22023';
  end if;
  if p_class_id is not null and not (
    public.is_class_owner(p_class_id) or public.is_class_member(p_class_id)
  ) then
    raise exception 'Class unavailable' using errcode = '42501';
  end if;
  insert into public.notification_settings(user_id, class_id, type, enabled)
    values(auth.uid(), p_class_id, p_type, p_enabled)
    on conflict (user_id, (coalesce(class_id, '00000000-0000-0000-0000-000000000000'::uuid)), type)
    do update set enabled = excluded.enabled
    returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.register_device_token(text, text, text),
  public.unregister_device_token(text),
  public.set_notification_setting(public.notification_type, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.register_device_token(text, text, text),
  public.unregister_device_token(text),
  public.set_notification_setting(public.notification_type, uuid, boolean)
  to authenticated;
revoke insert, update, delete on public.device_tokens, public.notification_settings
  from public, anon, authenticated;
grant select on public.device_tokens, public.notification_settings to authenticated;
commit;
