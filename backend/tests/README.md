# Join and approval dev SQL guide

Status: owner reported all 92 checks PASS on 2026-10-16; the assistant did not run tests. Run only on development project `fiobwfzmqcffbpixzvbq`.

1. Open that project's Supabase dashboard, then SQL Editor. Confirm the project reference and select the `postgres` role.
2. Confirm the dev database has the repository migrations, including `20261014160000_verified_session_gate.sql`. This script does not deploy or change functions.
3. Paste the entire `backend/tests/class_join_approval.sql` file into a new query and Run once. Keep BEGIN through ROLLBACK together. No IDs, Google accounts, JWTs or secrets need to be supplied.
4. Success means the entire query completes without any error and every returned result is PASS. The results include all nine requested scenarios, membership checks, notification payload/count checks, and inbox isolation. The final bulk state expects nine notifications: four instructor requests, four notifications for student 2 (two approvals, one decline, one removal), and one approval for student 3.
5. Send the PASS output or the first error with its context and your run date. Earlier PASS rows do not override a later error. If your session remains in an aborted transaction, run `ROLLBACK;` before rerunning the whole script.

Disposable Auth users, Auth sessions, verified sessions, profiles, class, memberships, notifications and temporary helpers are created in one transaction and rolled back. No fixture data should remain. RPCs run as authenticated users; postgres is used only for fixture setup and complete-effect assertions. Any external webhook side effects depend on dev configuration and are outside database rollback guarantees.

This verifies database behavior and RLS inbox visibility. It does not prove OTP login, app screens, push delivery or concurrent requests. The first owner-reported dev run passed all 92 checks; retain this guide for reruns. If a bug is found, add a new migration and rerun this script rather than editing an old migration.


## Lifecycle and security extension - 2026-10-16

Status: PREPARED, NOT EXECUTED. The earlier 92 PASS report covers only the original join/approval script. It does not accept this extension or the new migration.

1. On DEV, inspect migration history and the pending migration list. Apply `backend/supabase/migrations/20261016100000_class_lifecycle_access.sql` after the verified-session gate. This migration has not been deployed by the assistant. Preserve older migration files. If using migration tooling, inspect its dry run and stop if it proposes unrelated migrations or history changes. If applying through SQL Editor, run this entire new migration once as postgres and reconcile its migration-history record through the team's usual process.
2. Run the entire updated `backend/tests/class_join_approval.sql` in DEV SQL Editor as postgres, including BEGIN and ROLLBACK. No real accounts or IDs are needed. It retains the original assertions and adds lifecycle checks. Any error means FAIL; earlier PASS rows do not override it. Report the first error and context. Run `ROLLBACK;` separately if the transaction is aborted.
3. Require every output row to say PASS and the whole query to finish successfully. Added checks include archive/read-only/restore, wrong/null/case/space section refusal, exact section delete, deleted-class owner visibility and member hiding, recovery just before 14 days, refusal exactly at and after 14 days, removal/leave, retained work and grades, and rejoin approval. Boundaries use transaction `now()`; fixtures are backdated without waiting 14 days.
4. Checklist 1: another student's submissions, items, returned grades and exam sessions are hidden; exam/result RPCs reject another student's session. Own-work and own-result positive controls must also pass.
5. Checklist 4: the other instructor reads zero class/content/storage metadata rows; archive, restore, delete, recovery, removal and approval RPCs fail; direct class/post updates affect zero rows.
6. Checklist 8: removed students read zero class posts/attachments/quizzes/submissions/items/grades and material/submission storage metadata; exam/session/result RPCs are refused. Leaving has equivalent access checks. Instructor work retention must pass.

Phone/API checks owned by the tester:

- Use two instructors and two students to repeat archive, restore, remove, leave and delete/recover. After online refresh, confirm inaccessible classes close and disappear from member views. The owner can obtain deleted class metadata for recovery. Cached class rows must not reopen protected content after refresh.
- Download a material before removal/leave, then confirm that downloaded file still opens in airplane mode. SQL cannot verify device files.
- With fresh API requests, confirm removed/left/deleted-class members cannot obtain new material/submission download URLs. Confirm archived classes permit reads but refuse file upload, replacement and deletion. Existing signed URLs can remain usable until their expiration; local downloads are intentionally retained.
- Confirm archived posting, attachment edits, submission edits and quiz start/resume are blocked. Restore and confirm normal permitted actions work again. Approval while archived must fail.
- If permanent purge is included in acceptance, separately verify the deployed purge job removes expired class data and server files on DEV. This rollback script does not execute cron or prove object deletion. No retention worker or schedule was changed here.

The extension creates metadata-only `storage.objects` fixtures, not blobs, and rolls back all database fixtures. It does not prove Storage HTTP behavior, device sync, signed-URL expiry, concurrency, fresh migration replay, or scheduled cleanup. Completion remains pending your successful SQL run and applicable phone/API checks; do not mark security items 1, 4 or 8 passed from source review alone.


### First lifecycle run failure reported by owner

The first run stopped at `archived exam resume refused`. The old assertion hid whether the RPC succeeded or returned a different SQLSTATE, so the screenshot alone does not establish the cause or deployed migration state. The helper now reports the actual SQLSTATE/message (or SUCCESS), and a preflight checks for the lifecycle write guard and archived get_exam definition. Run ROLLBACK separately, confirm the new migration was applied successfully on the same DEV database, then paste the latest complete script and rerun. If it fails, send the full new error. No assistant SQL execution or new database defect is claimed from this result.


### Corrective result migration - 2026-10-16

Owner confirmed the lifecycle migration succeeded, then the updated test failed at the own released result positive control with SQLSTATE 42702 (`q.id` ambiguous). The new get_result membership guard reused its PL/pgSQL row variable q as a SQL alias. Apply the complete `20261016110000_fix_class_result_alias.sql` on the same DEV database after running ROLLBACK separately. Do not rerun or edit the applied lifecycle migration. The correction renames only the guard query alias, preserving the access check and RPC signature. Rerun the entire latest class_join_approval.sql afterward. Fix prepared by source review; no assistant execution, deployment or passing result is claimed.


## Owner-reported lifecycle SQL acceptance - 2026-10-16

Owner supplied complete CSV with 244 sequential result rows, all PASS, after the corrective get_result alias migration. This supersedes the pending SQL run and earlier failure status. Covers original join/approval checks, archive/read-only/restore, exact section deletion, deleted-class owner/member visibility, recovery before 14 days and refusal at/after the boundary, removal/leave, retained work, rejoin approval, and SQL security checklist items 1, 4 and 8 access controls.

Evidence is owner-reported execution following the same DEV run instructions; CSV does not independently identify the database, attest final rollback, or reconcile migration history. The assistant did not run SQL tests. Checklist 8's device download-retention portion remains pending a phone check; UI refresh, Storage HTTP/signed URLs, concurrency and scheduled purge remain outside this SQL evidence. Backend SQL acceptance is complete on supplied evidence; do not describe phone or scheduled cleanup acceptance as complete.

## M7 quizzes and question bank - owner DEV execution (2026-10-20)

Status: PREPARED, NOT RUN. M7-SA-01 retains the bank and blocks deletion after a start. No M7 backend or checklist acceptance yet. These instructions apply only to DEV `fiobwfzmqcffbpixzvbq`.

### Apply the two migrations

1. Open the DEV Supabase dashboard. Check the project reference in its URL is `fiobwfzmqcffbpixzvbq`, then SQL Editor, with role `postgres`.
2. Confirm earlier repository migrations are present, including verified-session gate, class lifecycle/get_result alias correction and later migrations through `20261018130000_sync_pull_support.sql`. Inspect migration history/pending changes first; stop if deployment tooling proposes unrelated migrations or history repairs. Do not rerun already applied migrations.
3. Open `backend/supabase/migrations/20261020100000_quiz_publish_security.sql`. Paste the ENTIRE file into a new DEV query and Run once. Require successful completion. If it errors, capture the first error/context, run `ROLLBACK;` separately, and stop before the next migration.
4. Repeat with the ENTIRE `20261020110000_atomic_questions_and_bank.sql`. Require successful completion. Never edit/reapply an applied migration to fix a bug: use a new migration.
5. If you applied using SQL Editor, record/reconcile these versions through the project's normal migration-history process. A successful SQL Editor run does not itself prove the migration ledger is registered. If either version is already registered, inspect rather than blindly reapplying its trigger-creation statements.

### Run rollback-only assertions

1. Paste the ENTIRE `backend/tests/quizzes.sql` into a new DEV query as `postgres`. Run once, keeping BEGIN through ROLLBACK together.
2. Save/send both result sets: individual test rows and final `passed / failed / overall / failures`. Require every row PASS, `failed=0`, `overall=PASS`, and `failures=[]`. Any uncaught error means failure even if earlier rows passed. On abort, issue `ROLLBACK;` separately before retrying the whole file.
3. Run the ENTIRE `backend/tests/question_bank.sql` the same way. Both scripts create disposable Auth users/sessions/verified sessions, profiles and content in one transaction; fixtures and temporary functions are rolled back. No real accounts, JWTs or IDs need to be supplied.
4. Send complete outputs or the first error with its context, which migration was applied, and the run date. Fixes will be separate migrations; rerun the affected scripts after applying them.

Expected coverage: missing/invalid schedules and keys/options, essay publication, publish-twice inbox count/payload, totals/essay changes and moves, content/settings/deletion lock guards, role isolation, archived/deleted states, direct protected-column refusal, student table isolation before/during/after an attempt, permitted exam/result RPCs, all four atomic-save types, strict limits/invalid edits, option replacement/type changes, complete/invalid reorder, and snapshot equality on failure. A deliberate key-trigger failure checks rollback after question/options have already been written. Bank checks include ownership, instructor role, limits, soft deletion and independent copies.

These scripts simulate authenticated accounts using claims; they do not exercise real Google/OTP login, HTTP/PostgREST, mobile screens, offline UI, external webhook/push delivery or concurrent sessions. Database rollback does not reverse external webhook effects if the dev environment has such hooks configured. Checklist 5 evidence covers quiz status/release/protected fields only, not all account/class fields.

### Check concurrency using two tabs

Use maintained `backend/tests/quiz_concurrency.sql`. **Do not run the whole file.** It commits narrowly named fixture accounts/class so two sessions can see them. It is deliberately separate from the rollback scripts.

1. Open two DEV SQL Editor tabs, both `postgres`. In either tab, select only section 1 SETUP, from BEGIN through COMMIT, and run once. Setup refuses existing fixture IDs instead of overwriting them.
2. For each numbered section 2–6, copy/select its A block (BEGIN through COMMIT) into tab A. Run it, then immediately run that section's B block in tab B while A is inside its 15-second sleep. The wait is part of the owner-run regression, not an assistant test.
3. B should wait for A to commit. Expected results are printed in each section: duplicate publish succeeds with one notification; start-before-save refuses the save; save-before-start exposes the committed edit; delete-before-start refuses start; start-before-delete refuses deletion. After each expected B error, run `ROLLBACK;` separately in tab B. If B does not wait, timing was missed: clean up, set up again and repeat the full sequence. A timeout/unexpected error is not PASS.
4. Run section 7 inspection SELECTs as postgres after both tabs finish. Require `must_be_one=1`, `must_be_zero=0`, and the expected quiz lock/deletion states. Capture A/B outputs and inspections; do not infer concurrency success from the rollback scripts.
5. Always run section 7 CLEANUP BEGIN..COMMIT as postgres after recording results, including after a failed case. It checks the dedicated class identity before deleting only that fixture class/users/profiles. If setup failed on a collision/provenance mismatch, inspect first; do not bypass the guard or delete unrelated records. Setup can be rerun only after cleanup succeeds.

Retry/offline contract for future screens: these authoring RPCs are online-only. Invalid/locked/access errors require correction or refresh, not automatic repeat writes. On `40P01` or `40001`, PostgreSQL has aborted the transaction: refetch and retry the entire RPC. On connection loss/uncertain response, refetch before retrying an empty-ID new save to avoid duplicate questions; do not retry individual option/key writes. Publishing can be retried without extra inbox rows. Mobile behavior remains a separate frontend acceptance task.


### M7 first quiz run: start failure diagnostic

Owner screenshot reports `P0001: Quiz not found` in `start_exam(uuid)` at the direct student-start assignment. This is a failed run, not quiz acceptance. The screenshot does not expose preceding per-case failures or prove the installed function definitions/migration history. Updated quizzes.sql catches this start failure, records SQLSTATE/message/context plus quiz schedule/status/deletion, student membership and earlier FAIL details, and returns the final summaries. Dependent during/after checks are explicitly marked incomplete/FAIL rather than bypassed or accepted. No application policy or migration is changed on this evidence alone.

Run `ROLLBACK;` separately, replace the SQL Editor contents with the ENTIRE latest backend/tests/quizzes.sql, and run as postgres. Send all FAIL rows and the start diagnostic detail, plus the final summary. Do not rerun applied migrations or move on to concurrency acceptance while failures remain. Script modification was source-reviewed only; assistant did not execute it.


### M7 correction after 193 PASS / 9 FAIL

The owner-reported failed summary is not acceptance. Source found lifecycle checks cannot resolve a question already removed during FK child cascade. New `20261020120000_quiz_question_delete_cascade.sql` deletes keys/options inside the existing question BEFORE DELETE guard, preserving authorization/class/lock protections and atomic rollback. No applied file is edited.

1. In the backend terminal run `npx.cmd supabase db push --dry-run`. If the two initial M7 migrations are already applied, expect ONLY `20261020120000_quiz_question_delete_cascade.sql`. Stop on unrelated pending migrations/history differences.
2. Run `npx.cmd supabase db push`, then `npx.cmd supabase migration list --linked`; require successful application and matching local/remote correction version. If either initial M7 migration is still pending, apply all three in chronological order.
3. In DEV SQL Editor as postgres, run `ROLLBACK;` separately. Replace all query text with the ENTIRE latest backend/tests/quizzes.sql and run. Expect all rows PASS and failed=0, including new per-type checks that question/options/key disappear together. Original delete assertions are retained.
4. Send all FAIL details and final summary; do not accept a partial run. Then run the entire question_bank.sql if quizzes pass. Concurrency acceptance stays separate. No assistant execution/deployment is claimed.


## M7 owner-reported quiz SQL acceptance - 2026-10-20

Owner supplied the latest quiz summary: 215 passed, 0 failed, overall PASS, failures []. This supersedes the prior 193 PASS / 9 FAIL quiz run and pending quiz-script correction status. Accepted on owner-reported DEV execution: publishing validation/idempotency/inbox, totals and cascade deletion, content/settings/delete locks, atomic save/reorder and rollback checks, direct-table student isolation across attempt states, and the quiz portion of protected-column permissions (security checklist 2 and quiz-related portion of 5).

Evidence is the owner's summary after the corrective migration handoff; assistant did not execute SQL or independently inspect deployed definitions/migration history. This is acceptance of quizzes.sql coverage, not a claim that every M7 task is complete. question_bank.sql and selected two-session quiz_concurrency.sql checks remain pending, including setup/cleanup and both race orderings. Mobile/HTTP/push/offline acceptance remains outside this SQL evidence. No repeat quiz run is requested absent further changes or failures.


## M7 owner-reported question-bank SQL acceptance - 2026-10-20

Owner supplied question_bank.sql summary: 65 passed, 0 failed, overall PASS, failures []. Question-bank SQL coverage accepted on owner-reported DEV execution: verified instructor ownership/role isolation, all four stored shapes and copies through save_question, boundary validation, soft-deletion tombstones and independent quiz copies. M7-BE-03 accepted within this SQL scope. Combined owner-reported results: quizzes.sql 215 PASS/0 FAIL and question_bank.sql 65 PASS/0 FAIL.

This supersedes pending bank-script statements above. Planned selected-block two-session quiz_concurrency.sql checks remain pending, including fixture cleanup; broad M7 completion is not claimed yet. No repeat of passed quiz/bank scripts is requested absent new changes or defects. Assistant did not run tests, SQL, live checks, builds or static analysis; migration history, HTTP/mobile/push/offline and race behavior were not independently verified. No disposable materials created.


## M7 guided two-session outcomes and timed publication - 2026-10-21

Owner supplied guided results after bank acceptance: student-start-before-save refused with 22023; save-before-start returned both Committed edit and Original; delete-before-start refused start with Quiz not found; start-before-delete refused with 22023 A started quiz cannot be deleted. Final inspection rows all matched: publish notifications=1, blocked Late edit questions=0, deleted quiz attempts=0, retained started quiz attempts=1, and started quiz still locked/undeleted=1. First fixture cleanup returned set_config {} without reported error. These are owner-reported functional outcomes; screenshots alone did not establish simultaneous lock waits for all cases.

Owner then recreated dedicated fixtures for publication timing. Screenshot shows A using pg_sleep(30), and B's timed publication returning quiz a7be0001-0000-4000-8000-000000000011 with waited_seconds=29.3. This supports owner-run concurrent-publication serialization/lock-wait acceptance; elapsed duration includes the call, not a separately sampled pg_locks measurement. No new timing claims are made for start/save/delete orderings. Fresh timed-run notification count and fixture cleanup remain pending next owner query. No repeat of passed quiz/bank suites requested and no blanket concurrency stress, HTTP/mobile or deployment-ledger acceptance inferred.

Assistant recorded evidence only; no tests, SQL execution, builds, static analysis or live verification. No disposable materials created. Prior statements that all concurrency evidence is pending are superseded within the specific functional/timed-publication scope above.


## M7 backend acceptance and final fixture cleanup - 2026-10-21

Owner supplied final result: PASS: one notification; test fixtures removed. The provided query checks dedicated fixture provenance and exactly one quiz notification before deleting the fixture class/Auth users/profiles in a transaction. Accepted as owner-reported successful final check/cleanup, not independent remote inspection.

M7-BE-01, M7-BE-02 and M7-BE-03 are Complete ? accepted for the requested DEV SQL/backend scope on cumulative owner evidence: quizzes.sql 215 PASS/0 FAIL; question_bank.sql 65 PASS/0 FAIL; guided start/save/delete functional outcomes and all five stored-state checks matched; concurrent publishing call took 29.3 seconds while A held its transaction for 30 seconds; exactly one notification confirmed and fresh fixtures removed. SQL security checklist 2 and the quiz-related portion of 5 accepted. This supersedes earlier pending task/bank/publication cleanup statements.

Limits retained: start/save/delete lock-wait durations were not separately measured; no blanket concurrency stress, fresh full migration replay, HTTP/mobile/push/offline behavior or independent migration-ledger verification is claimed. Assistant did not execute tests, migrations, SQL/live checks, builds or static analysis. No additional owner tests requested for completed scope absent new changes/defects. Maintained regression scripts remain; no disposable materials created locally.
