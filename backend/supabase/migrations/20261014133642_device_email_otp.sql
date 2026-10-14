-- Bind each OTP to the login session being verified.
alter table public.otp_codes
  add column session_id uuid;

-- Only successfully delivered codes may be verified.
alter table public.otp_codes
  add column delivery_status text not null default 'pending'
    check (delivery_status in ('pending', 'sent', 'failed'));

-- Look up recent OTP requests for resend enforcement.
create index otp_codes_user_created_idx
  on public.otp_codes (user_id, created_at desc);

-- Keep OTP records accessible only to the backend.
alter table public.otp_codes enable row level security;

revoke all on table public.otp_codes
  from anon, authenticated;

grant select, insert, update, delete
  on table public.otp_codes to service_role;