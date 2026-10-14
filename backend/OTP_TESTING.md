# Device OTP integration

Work branch: `otp-session-integration`, based on `main`.

## Development setup

1. Apply `supabase/migrations/20261014160000_verified_session_gate.sql` to DEV.
   It replaces the manually pasted device-check function. Apply the whole file
   once in a transaction (`BEGIN` before it; `COMMIT` after it).
2. Enable Google in Supabase Authentication and configure the Google web OAuth
   client. Google's authorized redirect URI is the Supabase Auth callback shown
   in the provider settings, not the Android callback.
3. Add `com.filo.filo://login-callback/` under Authentication > URL Configuration
   > Redirect URLs in Supabase.
4. Ensure `send-otp` and `verify-otp` are deployed with their existing config and
   SMTP/HMAC secrets. These functions validate bearer tokens themselves.
5. Run ALL of `supabase/tests/unverified_session.sql` in DEV's SQL Editor.
   It requires an Auth session, populates every app table, checks unverified reads
   and callable definer functions, and tests wrong/correct OTP and device trust.
   All changes are rolled back. On any error, run `ROLLBACK;` separately.
   Its hash fixture tests the procedure, not actual email delivery or HMAC.

## Phone test

From `frontend`, use the existing ignored `.env.dev.json` (ENV, SUPABASE_URL,
SUPABASE_ANON_KEY):

```powershell
flutter run -d <phone-id> --dart-define-from-file=.env.dev.json
```

1. Continue with Google. Complete browser sign-in and return to Filo.
2. Check `Session ID present: true` on the debug session screen. No tokens,
   OTPs or device secrets are printed.
3. On a new device, use the debug profile/class read check BEFORE OTP.
   Both counts must be zero, or the request must be denied.
4. Send code and verify the emailed six-digit code. The screen changes to Device
   verified only after server confirmation. Confirm both security records in SQL.
5. Sign out and sign in again: the same device must skip OTP.
6. To simulate a new installation, clear this DEV app's storage in Android
   Settings. This removes cached account data and the device secret. Do this only
   when losing test app data is acceptable. Sign in again: OTP must be required.

The signed-in screen is an integration surface. Classroom screens remain sample
previews; real class/profile repositories and onboarding are separate work.
The account database opens only for a server-verified user. Verification loss,
logout and account changes close the previous account database.

## Remaining project verification

DEV migration and populated SQL tests must be run against Supabase. Google token,
SMTP delivery, OTP success and trusted-device re-login require the phone test.
Leave the Schema's real-token Verify item pending until the phone confirms it.

Future protected tables/functions need the verification gate too. Private Storage
policies are gated. Public bucket URLs and previously issued signed URLs need
separate consideration if storage settings change.
