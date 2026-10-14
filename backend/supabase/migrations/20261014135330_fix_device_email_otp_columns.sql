alter table public.otp_codes
  add column if not exists session_id uuid;

alter table public.otp_codes
  add column if not exists delivery_status text
    not null default 'pending'
    check (delivery_status in ('pending', 'sent', 'failed'));

create index if not exists otp_codes_user_created_idx
  on public.otp_codes (user_id, created_at desc);

alter table public.otp_codes enable row level security;

revoke all on table public.otp_codes
  from anon, authenticated;

grant select, insert, update, delete
  on table public.otp_codes to service_role;