# Account database

Source: `docs/MD Files/05-background-schema-document.md`, sections 10.1 and
10.2. Those sections list cache names and queue fields, not a complete SQLite
DDL. Cache columns, nullability, checks, keys and indexes follow cloud migrations
0002-0005. `cache_grades` maps to `submission_grades`. UUIDs and enums use TEXT;
Drift stores DateTime values as SQLite timestamps. Cloud-generated UUIDs and
join codes must come from the server. Cloud triggers and RLS do not run locally.

`cache_results` stores the released `get_result` RPC fields from migration 0006,
keyed by the requested `session_id`; `review` is nullable JSON text. It does not
copy the protected exam-session table. Future sync code must cache only the
current student's submissions, returned grades and released results, as required
by section 10.1, and respect the server's answer visibility rules.

Local choices where section 10.2 supplies no DDL: `table_name` is the sync-state
primary key, `last_synced_at` is nullable before an initial sync, outbox `id` is a
caller-supplied text primary key, `payload` is valid JSON text, `attempts` defaults
to zero and cannot be negative, `created_at` defaults to now, and `last_error` is
nullable. Callers supply `action_type` and `status`; no status values are invented.

`authUserIdProvider` emits the restored Supabase user ID and subsequent account
changes. `accountDatabaseProvider` opens the matching file, closes on logout and
switches files on account changes. `App` watches it, gates screens during opening,
and remounts screen state for a different account. Repositories should await
`ref.watch(accountDatabaseProvider.future)` and handle null as signed out.
Google sign-in remains a preview button; the lifecycle wiring reacts to Supabase
sessions but does not implement OAuth, OTP, server sync or cached screen queries.
Files live under application support in `databases/<user-id>.sqlite`.

Generate: `dart run build_runner build`.
Verify: `flutter test test/data/local/app_database_test.dart`.
Auth lifecycle: `flutter test test/data/local/auth_database_test.dart`.
