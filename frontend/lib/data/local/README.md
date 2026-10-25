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
Google sign-in, verified-session/OTP gating and feature repositories are now
implemented separately; this account manager owns only cache isolation/lifetime.
Files live under application support in `databases/<user-id>.sqlite`.

Generate: `dart run build_runner build`.
Verify: `flutter test test/data/local/app_database_test.dart`.
Auth lifecycle: `flutter test test/data/local/auth_database_test.dart`.


Schema v3 adds `drive_backup_settings` and `drive_backup_jobs` through explicit
migration SQL in AppDatabase (including new installs). They are a dedicated
per-account Drive upload outbox; generated Drift table bindings are unchanged.
Settings hold enablement, Wi-Fi-only (default true), bound Google ID, stable
folder ID and selected-queue last-success. Jobs hold immutable private file
snapshots, content digest, stable remote ID, confirmed offset, status and timing.
Google tokens are not stored here; resumable session URLs use secure storage.
Backups run while foregrounded, resume on app reopen/reconnect and stop for
account switches. OFF pauses pending work and retains it; it never deletes Drive
copies. Verified completion removes the private queue snapshot, preserving the
user-selected source file. Completed content is deduplicated per Filo account.
No automatic full-library/background Android worker is included.

The commands above are reference owner checks, not a record that they were run.


M6 schema v4 adds generated Drift local_folders/local_files and indexes. Their
class IDs/source IDs are plain text, without cloud-cache FKs, so class eviction
retains downloaded files. Files live under application support/files/USER_ID;
folder display names are independent of physical IDs. file_settings stores the
storage notice/last-sync display; sync_payloads and sync_cursors preserve remote
JSON/full-precision server timestamps. outbox_schedule stores due times/claim
leases. Drive v3 bookkeeping remains in its dedicated tables, while all library
backup actions now enter the generic outbox and complete local_files.backed_up_at.
Existing schema v2/v3 databases upgrade without resetting cached/local data.
Generated bindings were regenerated, not hand-edited. No tests were run.

Drive v4 jobs also bind local_file_id uniquely (digest is verification data, not
library identity), preserving distinct files with identical contents. Legacy v3
job IDs/remote IDs remain intact through the table migration. Pending private
snapshots/session keys are cleaned on local deletion with safe account paths;
remote files remain. A previously verified session/device marker in secure
storage permits offline cache reopening; a new/unverified session cannot use it.


M9 schema v9 adds `results_snapshots(id,class_id,payload)` using explicit migration
SQL for upgrades and new accounts. Its class FK cascades on class removal; a delete
trigger removes a student snapshot's cache_results row. Upserts update snapshots
without replacing/deleting them. Generated Drift bindings remain unchanged.
Snapshots hold student quiz/current-session metadata, instructor monitoring/active
members, attempt details and persistent uncertain-write markers. Student released
scores/review stay in cache_results. Missing snapshots differ from successful empty
lists. Changes notify the cache_results watch dependency.

ResultsCache checks the verified account, role and class access before reads.
Instructor data is owner-only and offline reads are read-only. Confirmed access loss
evicts related snapshots; transport errors retain cache. Student refresh resolves
get_my_session before get_result and never reads protected exam tables directly.
Known replacements/unreleased results remove old eligibility. Background refresh
uses the same path, including legacy catalog-associated results. Grading/release/
second chances are never queued; unknown outcomes block further writes across
restart until monitoring reconciliation succeeds. Missing essay answer rows remain
visible but require a real answer ID to grade through grade_essay.

Owner checks from frontend: `flutter test test/features/results` and
`flutter test test/data/local/app_database_test.dart test/data/local/auth_database_test.dart`.
These commands have not been run by the assistant; runtime acceptance is pending.


M9-FE-01 owner failure correction (2026-10-25): the reported repository timeouts
came from refresh cleanup callbacks returning their own pending future, not evidence
of a SQLite migration failure. Both repository callbacks now return void. Mocked
HTTP responses include their request metadata required by the installed PostgREST
parser. The upgrade regression closes its unused setup database before opening
another AppDatabase. Owner reported 9 passed / 18 failed before these corrections;
the focused suite rerun and runtime acceptance remain pending. No assistant rerun.


The next owner results rerun reported 23 passed / 5 failed. Remaining corrections
are test-only: compare RPC record fields/maps deeply and retain provider listeners
while awaiting initial stream data. The previous transport/refresh/migration fixes
remain in place. No cache schema change; focused rerun and runtime acceptance pending.


Owner evidence (2026-10-25): `flutter test test/features/results --reporter expanded`
completed with 28 passed / 0 failed, including the v8 upgrade/cache regressions.
This supersedes the focused-suite rerun-pending notes above. No assistant rerun;
live DEV quiz, device/offline/write acceptance and other suites remain unverified.


M9-FE-01 additional owner evidence (2026-10-25):
`flutter test test/data/local/app_database_test.dart test/data/local/auth_database_test.dart`
completed with 5 passed / 0 failed (00:07 +5: All tests passed!). Together with the
separate results suite (28 passed / 0 failed), both requested automated checks are
accepted on owner evidence. No assistant rerun or implementation changes. Live DEV
quiz data with submitted/in-progress/not-started students and real device/offline/
write acceptance remain pending; no overall task or Q9-Q12 UI acceptance is inferred.


## M9-FE-02 through M9-FE-06 implementation (2026-10-25)

Student quiz details now link to cached released results with server-controlled review/pass state. Instructor Classwork exposes Results for published quizzes; closed quizzes open Results on tap and retain Edit in the menu. Monitoring includes active-roster summaries, provisional averages, search, filters, sorts, leaves and history. Attempt detail supports confirmed essay saves, existing score overrides, dirty-form navigation and read-only previous attempts. Release and second-chance confirmations require a connection; closing extension updates only closes_at in Philippine time. Unknown write outcomes require refresh before retry and are never queued. Blank/missing essays display No answer and zero without fabricating/saving answer rows.

Class sync caches authorized published quiz grades in results_snapshots (`grades:<class>`). Student totals include returned assignments and released current graded quizzes; instructor totals include saved assignment marks and current grading-complete quizzes. Monitoring averages separately include provisional current submitted attempts. An instructor must first load the existing assignment Gradebook snapshot online before opening that screen offline. No new schema/dependencies for this UI increment.

M9-FE-07 quiz-specific CSV and dark mode remain deferred. Existing Gradebook export follows its displayed mixed totals. Maintained tests cover calculations, roster filters/sorts, offline/enlarged-text rendering, override RPC parameters and closing validation. Tests, analysis, builds and live/device checks were not run; owner acceptance remains pending, including DEV availability of the existing override_points migration.


M9 results owner compile correction (2026-10-25): owner suite reported 30 passed with screen-suite compilation blocked by releasedLine receiving QuizMonitoring. Corrected the sole caller to pass data.quiz, matching its ResultJson signature. Existing instructor screen test checks the unreleased line. No assistant tests, analysis, builds or runtime checks; owner rerun pending.


## M9 results owner acceptance - 2026-10-25

Owner reported `flutter test test/features/results`: 36 passed, All tests passed, then explicitly approved all runtime checks. M9-FE-02 through M9-FE-06 runtime acceptance is recorded on owner evidence, including the requested results, grading, release/second-chance, offline and mixed-grade flows. This supersedes earlier pending labels for these tasks; no independent assistant verification is claimed. M9-FE-07 quiz-specific CSV and dark mode remain deferred. No production changes or new testing materials in this acceptance task.
