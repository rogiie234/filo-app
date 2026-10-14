-- Reserve a new OTP before the Edge Function sends its email.
-- p_code_hash is calculated by the Edge Function.
create or replace function public.issue_device_otp(
  p_id uuid,
  p_user_id uuid,
  p_session_id uuid,
  p_device_hash text,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz;
  v_last_sent timestamptz;
  v_retry_after integer;
begin
  if p_id is null
     or p_user_id is null
     or p_session_id is null
     or nullif(trim(p_device_hash), '') is null
     or p_code_hash is null
     or p_code_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('error', 'INVALID_REQUEST');
  end if;

  -- Lock a stable row, including when no OTP exists yet.
  perform 1 from auth.users
  where id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('error', 'USER_NOT_FOUND');
  end if;

  v_now := clock_timestamp();

  select max(created_at) into v_last_sent
  from public.otp_codes
  where user_id = p_user_id;

  if v_last_sent is not null
     and v_last_sent + interval '60 seconds' > v_now then
    v_retry_after := ceil(extract(epoch from (
      v_last_sent + interval '60 seconds' - v_now
    )))::integer;

    return jsonb_build_object(
      'error', 'OTP_RESEND_TOO_SOON',
      'retry_after', v_retry_after
    );
  end if;

  -- A resend must not reset a locked challenge before it expires.
  if exists (
    select 1 from public.otp_codes
    where user_id = p_user_id
      and consumed_at is null
      and attempts >= 5
      and expires_at > v_now
  ) then
    return jsonb_build_object('error', 'OTP_LOCKED');
  end if;

  -- Invalidate earlier codes for this user.
  update public.otp_codes
  set consumed_at = v_now
  where user_id = p_user_id
    and consumed_at is null;

  insert into public.otp_codes (
    id, user_id, session_id, device_hash,
    code_hash, expires_at, attempts,
    created_at, delivery_status
  )
  values (
    p_id, p_user_id, p_session_id, p_device_hash,
    p_code_hash, v_now + interval '10 minutes', 0,
    v_now, 'pending'
  );

  return jsonb_build_object(
    'challenge_id', p_id,
    'expires_in', 600,
    'resend_after', 60
  );
end;
$$;


-- Record the SMTP result.
create or replace function public.finish_device_otp_delivery(
  p_id uuid,
  p_user_id uuid,
  p_sent boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_sent is null then
    return false;
  end if;

  perform 1 from auth.users
  where id = p_user_id
  for update;

  if not found then
    return false;
  end if;

  update public.otp_codes
  set delivery_status = case
        when p_sent then 'sent'
        else 'failed'
      end,
      consumed_at = case
        when p_sent then null
        else clock_timestamp()
      end
  where id = p_id
    and user_id = p_user_id
    and delivery_status = 'pending'
    and consumed_at is null
    and expires_at > clock_timestamp();

  return found;
end;
$$;


-- Verify and consume the OTP in one transaction.
create or replace function public.verify_device_otp(
  p_id uuid,
  p_user_id uuid,
  p_session_id uuid,
  p_device_hash text,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_otp public.otp_codes%rowtype;
  v_now timestamptz;
  v_attempts integer;
begin
  if p_id is null
     or p_user_id is null
     or p_session_id is null
     or nullif(trim(p_device_hash), '') is null
     or p_code_hash is null
     or p_code_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('error', 'INVALID_REQUEST');
  end if;

  perform 1 from auth.users
  where id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('error', 'OTP_WRONG');
  end if;

  select * into v_otp
  from public.otp_codes
  where id = p_id
    and user_id = p_user_id
    and session_id = p_session_id
    and device_hash = p_device_hash
  for update;

  if not found then
    return jsonb_build_object('error', 'OTP_WRONG');
  end if;

  v_now := clock_timestamp();

  if v_otp.consumed_at is not null then
    return jsonb_build_object('error', 'OTP_USED');
  end if;

  if v_otp.attempts >= 5 then
    return jsonb_build_object('error', 'OTP_LOCKED');
  end if;

  if v_otp.expires_at <= v_now then
    return jsonb_build_object('error', 'OTP_EXPIRED');
  end if;

  if v_otp.delivery_status <> 'sent' then
    return jsonb_build_object('error', 'OTP_NOT_READY');
  end if;

  if v_otp.code_hash <> p_code_hash then
    update public.otp_codes
    set attempts = attempts + 1
    where id = v_otp.id
    returning attempts into v_attempts;

    -- Return normally so the attempt increment is committed.
    return jsonb_build_object(
      'error', case
        when v_attempts >= 5 then 'OTP_LOCKED'
        else 'OTP_WRONG'
      end,
      'attempts_remaining', greatest(0, 5 - v_attempts)
    );
  end if;

  update public.otp_codes
  set consumed_at = v_now
  where id = v_otp.id;

  insert into public.trusted_devices (
    user_id, device_hash, last_seen_at
  )
  values (p_user_id, p_device_hash, v_now)
  on conflict (user_id, device_hash)
  do update set last_seen_at = excluded.last_seen_at;

  insert into public.verified_sessions (
    session_id, user_id, device_hash, verified_at
  )
  values (p_session_id, p_user_id, p_device_hash, v_now)
  on conflict (session_id)
  do update set
    device_hash = excluded.device_hash,
    verified_at = excluded.verified_at
  where public.verified_sessions.user_id = excluded.user_id;

  if not found then
    -- Roll back consumption and device registration on inconsistency.
    raise exception 'Session ownership mismatch';
  end if;

  return jsonb_build_object('verified', true);
end;
$$;


-- Only the backend service role may call these procedures.
revoke all on function public.issue_device_otp(
  uuid, uuid, uuid, text, text
) from public, anon, authenticated;

revoke all on function public.finish_device_otp_delivery(
  uuid, uuid, boolean
) from public, anon, authenticated;

revoke all on function public.verify_device_otp(
  uuid, uuid, uuid, text, text
) from public, anon, authenticated;

grant execute on function public.issue_device_otp(
  uuid, uuid, uuid, text, text
) to service_role;

grant execute on function public.finish_device_otp_delivery(
  uuid, uuid, boolean
) to service_role;

grant execute on function public.verify_device_otp(
  uuid, uuid, uuid, text, text
) to service_role;