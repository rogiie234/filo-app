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

## M8-BE-01 exam regression — 2026-10-22

Status: COMPLETE ? owner-reported DEV result on 2026-10-22: 178 PASS, 0 FAIL, overall PASS, failures []. Exam security checklist items 2 and 3 accepted for this SQL scope. Assistant did not execute the script or independently inspect migration history.

1. Use DEV `fiobwfzmqcffbpixzvbq` only. In SQL Editor select postgres. Confirm the repository prerequisites are installed, especially the verified-session gate, class lifecycle access, and all three M7 migrations. Inspect migration history; do not apply unrelated pending changes or infer deployment from local files.
2. Apply `backend/supabase/migrations/20261022100000_exam_answer_text_limit.sql`. It replaces only `save_answer`, preserving its signature, permissions, caller checks, grace period and upsert. Identification/essay text above 10,000 characters now raises SQLSTATE `22001`, message `Answer must be at most 10000 characters`, instead of silently truncating. Reconcile migration history through the team's normal process if using SQL Editor.
3. Run the entire `backend/tests/exams.sql`, from BEGIN through ROLLBACK, as one query. No fixture IDs, accounts or secrets are needed. The script does not install migrations. Preflight failure or any uncaught error means FAIL. After an aborted transaction, run `ROLLBACK;` separately before rerunning.
4. Require every labelled result and the final overall result to be PASS with failed=0. Send the final summary, first failing row with SQLSTATE/message/context (or uncaught error), run date, and applied migration state. Earlier PASS rows never override a later failure.
5. Expected coverage: start eligibility and idempotent resume; normal/closing-capped deadlines; persisted shuffle permutations and repeated retrieval; whole-JSON key/value privacy checks and field allowlists; all four answer types, overwrites and foreign-input refusal; 10,000/10,001 Unicode-character boundary; saves before expiry, 10/15/16 seconds after it; direct-table isolation before/during/after exams and after release; unreleased/released score gates and cross-student refusal. Clock cases update fixture deadline_at using transaction-stable now(); they never sleep.
6. After a full PASS, record owner-reported DEV evidence in decisions.md and accept checklist 2 (direct question/option/key reads denied throughout) and checklist 3 for exams (scores inaccessible before release). Assignment-grade acceptance is outside this script.

Fixtures include temporary Auth users/sessions, verified sessions, profiles, classes, memberships, quizzes, questions, options, keys, attempts, answers, leave events and helpers. All database changes roll back; the maintained script stays in version control. External database webhooks, if configured, are outside rollback guarantees. This is authenticated-role SQL/RLS simulation, not HTTP transport, device/offline recovery, concurrency, cron, release scheduling or essay-grading acceptance. A failed save must preserve the prior answer; a legitimate retry within the window overwrites the same row, and a retry after grace or submission is refused. No assistant SQL, tests, static analysis or builds were run.

Owner acceptance evidence ? 2026-10-22: `passed,failed,overall,failures` / `178,0,PASS,[]`. This supersedes the prepared/pending status for M8-BE-01. No individual result rows or migration ledger were supplied; acceptance is based on the owner-reported aggregate. No additional rerun required absent changes or new defects.

## M8-BE-02 submit, leave events and time-out — 2026-10-22

Status: COMPLETE for backend SQL/cron scope on owner evidence, 2026-10-22: 294 PASS/0 FAIL/overall PASS, unattended cron PASS (auto_submitted, score 7, submitted_at=deadline_at, successful_cron_after_expiry=true), and cleanup fixtures_removed=true. First WAIT inspection was followed by PASS. App recovery integration and the maintained Dart test remain unverified. Assistant did not execute SQL or independently inspect DEV migration history.

### Rollback regression (owner)

Run the entire updated `backend/tests/exams.sql`, BEGIN through ROLLBACK. It keeps the original checks and adds normal/late/repeated/foreign submission, grading (weighted expected score 18), blank and normalized identification, ungraded essay/unanswered question, unreleased score privacy, privileged-helper denials, leave retries/counts and exact +60-second boundary, expiry worker +10/+15/+16-second cases, and verified caller-scoped recovery/isolation. Leave count must be 0, 1, 1, 2, 2, 3, 3 through the labelled sequence. Both normal and auto submission retries must preserve the stored session and answer snapshot.

No sleeps: transaction-stable now() and fixture deadline changes make the clock cases deterministic. The script lists real overdue sessions at the start, then refuses to call the global worker if unrelated overdue sessions still exist. If blocked, ROLLBACK and resolve the reported DEV work separately; never delete unrelated attempts or remove the guard to get a PASS. The worker also evaluates global result release; its database effects roll back with the test, while configured external webhooks are outside rollback guarantees.

Every row and final overall must be PASS, failed=0. Any FAIL, preflight refusal or uncaught error blocks acceptance; send the first SQLSTATE/message/context or aggregate and run date. After abort, ROLLBACK separately before retrying. The previous 178 PASS is not the new expected total; use the script's current summary rather than a guessed count.

### Unattended scheduler proof (owner)

The maintained proof is deliberately split into three files so inspection cannot perform setup or cleanup:

1. Run `backend/tests/exam_cron_setup.sql` once as postgres after deploying the task migration. It commits two reserved, marked fixture users and a class/quiz/question/attempt/answer. Deadline is 30 seconds after setup; expected score is 7. Save its session ID, deadline, eligible_after and inspect_after timestamps. Reserved IDs prevent accidental overwrite/repeated setup.
2. Close the app. Do not call submit, finalization, recovery, result or session RPCs for the proof users. Wait until the printed inspect_after timestamp (deadline plus two minutes), then run the whole `backend/tests/exam_cron_inspect.sql` in a fresh query. It only reads tables. PASS requires auto_submitted, submitted_at=deadline_at, score/points=7, grading_complete, correct answer, and a successful matching cron run after deadline+15 seconds. WAIT permits another read-only inspection; FAIL requires checking job history rather than manually finalizing the fixture. Cron starts once per minute, not exactly at each session's deadline. Share the PASS/proof row and relevant job history, or the failure/history if it does not finish.
3. After saving evidence, run `backend/tests/exam_cron_cleanup.sql`. It validates reserved IDs, markers and fixture scope, deletes only those fixtures, and must return fixtures_removed=true. Do not delete the active production-style job or its job history. If cleanup refuses, report the error rather than broadening the deletes.

### Recovery fallback and owner app checks

The new `finalize_accessible_exams()` RPC returns void and requires a verified account. It finalizes only expired own attempts with current membership, or attempts in classes owned by the instructor, in accessible open classes. It also checks result release only for accessible quizzes. The global worker and grading helpers remain server-only. SyncCoordinator calls the scoped RPC before pulling results/instructor sessions; existing online startup, resume, reconnect and periodic sync invoke it. Recovery errors do not block other pulls, remain visible in sync status, and retry next sync. Never display a submission success just because the request was sent.

If cron is unavailable, this is deferred recovery on the next online visit; it cannot submit while all apps are closed. The owner explicitly selected accepting that limitation. Record extension failure plus scoped SQL and app results as FALLBACK ACCEPTED (deferred), not unattended PASS. No alternative scheduler or new results screen was added.

Owner app checklist: on reopen/reconnect, an own overdue attempt finalizes and shows released results only when eligible; a peer's attempt stays untouched; instructor sync finalizes only owned-class attempts; offline/recoverable failure retains retry status while other cached content still refreshes; the next successful sync clears the expiry error without changing a finished attempt. A maintained sync regression covers failure isolation and next-sync retry, but has not been run. No assistant SQL, tests, static analysis, builds, app/device or live API checks were run. All SQL files are lasting regression coverage; no disposable files were created.

## M9-BE-01 — Exam essay grading and results (2026-10-25)

Status: COMPLETE for M9-BE-01 backend SQL scope on owner-reported DEV evidence, 2026-10-25: 169 passed, 0 failed, overall PASS, failures []. Results-related security checklist items 2 and 3 accepted. This supersedes the prepared/pending status; no assistant SQL rerun or independent remote inspection is claimed. No corrective migration was required. Existing RPC signatures and feedback truncation remain unchanged. Frontend/device/offline acceptance is outside this SQL result.

1. Open DEV project `fiobwfzmqcffbpixzvbq`, SQL Editor, postgres role. Confirm repository migrations through `20261024100000_exam_answer_batches.sql` are applied, including verified-session, class-access/get_result alias and quiz publication migrations. Inspect history; do not rerun applied migrations or deploy unrelated pending changes.
2. Run the entire `backend/tests/exam_results.sql`, from BEGIN through ROLLBACK. It uses synthetic verified identities and two instructor-owned classes. RPCs and direct reads run as authenticated with the selected identity; privileged setup/inspection is kept separate. The M9-BE-02 extension calls the global finalization worker only after refusing unrelated overdue attempts; it never disables triggers. The worker also evaluates global release readiness inside the rollback transaction. Database fixtures roll back; configured external webhook effects are not covered by database rollback guarantees.
3. Expect every named row PASS, failed=0, overall=PASS, failures=[]. Checks include grading limits/refusals with unchanged snapshots, zero/full/regraded totals, two answered essays plus blank/whitespace/missing essays, exact/oversized Unicode feedback, release guards, metadata/result score gating, all review answer types in saved order, threshold/null/rounding cases, direct-table privacy, instructor isolation, and manual/automatic release notification uniqueness. Feedback above 2,000 characters is intentionally truncated, not rejected. Threshold/review setting variations are privileged fixture changes, not instructor edit permissions.
4. Save and share the complete rows and summary with run date/project. Any FAIL or uncaught SQL error blocks acceptance. After an abort, run `ROLLBACK;` separately, then rerun the entire latest file after correction. A disconnected editor or missing output proves nothing; reconnect, clear any aborted transaction, and rerun. There is no app offline/device claim in this SQL task.
5. After a complete passing DEV run, record owner evidence in docs/decisions.md and mark results checklist 2 (direct questions/options/keys remain hidden even after release; review only through the authorized RPC) and 3 (no score before release) accepted. Do not infer acceptance from prior M8 results or source inspection. If a defect is exposed, add a new corrective migration, document any API behavior change, and rerun the complete script. Frontend results-screen integration remains outside this task.


## M9-BE-02 release and second-chance regression ? 2026-10-25

Status: SQL PASS on owner-reported DEV evidence, 2026-10-25: 231 passed, 0 failed, overall PASS, failures []. COMPLETE for backend SQL/cron scope on owner evidence: unattended release/inbox PASS and fixtures_removed=true. M9-BE-01 acceptance remains historical. No demonstrated production defect or corrective migration from source inspection; add a new migration if DEV exposes a defect. RPC signatures and permissions are unchanged.

1. Use DEV `fiobwfzmqcffbpixzvbq`, SQL Editor postgres, with repository migrations through `20261024100000_exam_answer_batches.sql`. Inspect migration history first; apply only a task corrective migration if one is supplied, never unrelated pending work.
2. Run the WHOLE updated `backend/tests/exam_results.sql`, BEGIN through ROLLBACK. Require all named rows PASS and final `failed=0`, `overall=PASS`, `failures=[]`. Added M9B labels cover active-roster/open/closed/voided release, pending/removed nonparticipants, complete refusal snapshots, early close/start refusal, second-chance audit/inbox/history/privacy, in-progress and submitted resets, and attempt-2 normal/closing-capped fresh deadlines. Existing last-essay grading tests require immediate release at transaction now().
3. The deterministic worker case moves only its own fixture deadline beyond the 15-second grace. If unrelated overdue attempts are reported, run `ROLLBACK;` and resolve that DEV work separately. Never remove the guard or delete unrelated attempts. The global worker evaluates other release-ready quizzes too; database effects roll back, external webhook effects may not. This check proves worker behavior, not unattended scheduling.
4. For unattended release proof, run `backend/tests/exam_cron_setup.sql` once. It commits reserved synthetic fixtures so cron can see them. Keep apps closed and do not call session/result/submit/recovery/finalization RPCs for the proof identities. After the printed `inspect_after`, run `backend/tests/exam_cron_inspect.sql` in a fresh query. PASS now requires auto-submission/scoring, a successful one-minute cron run after grace, a release timestamp after expiry, and exactly one correctly targeted results inbox row. WAIT means repeat read-only inspection later; FAIL requires evidence and a fix, never manual finalization. Missing cron leaves this task pending, even if fallback behavior was accepted historically.
5. Save the SQL summary and cron proof/job history, then run `backend/tests/exam_cron_cleanup.sql`; expect `fixtures_removed=true`. Cleanup refuses unexpected scope: report that refusal instead of broadening deletes. These three maintained cron scripts are reused; setup/cleanup and reserved IDs are unchanged.
6. Share run date/project, migration state, complete SQL results, cron evidence and cleanup output. Any FAIL, uncaught error, disconnect or absent summary leaves acceptance pending. After an aborted transaction, run `ROLLBACK;` separately before a full retry; after a connection loss during cron setup, inspect reserved fixtures before trying setup again. Record actual owner evidence in `docs/decisions.md`; do not replace prepared status with PASS based on source review. Frontend/offline/device and concurrency behavior remain outside this SQL proof.

Assistant ran no SQL, tests, live checks, static analysis or builds. Maintained scripts remain in version control; no disposable test materials were created.


### M9-BE-02 fixture identity correction ? 2026-10-25

Owner DEV run stopped with SQLSTATE 42501, Quiz is inaccessible or read-only, in lock_quiz_content during m9_rule_quiz question insertion. The shared fixture builder inherited the prior authenticated actor's JWT claims; privileged postgres setup does not bypass the guard's explicit auth.uid ownership check. The helper now selects verified fixture owner u1 for construction and restores the prior claims before returning. Every helper caller receives this correction; real RPC refusal/success calls retain authenticated role/actor selection and production security guards are unchanged. This is a regression-script defect, not evidence requiring a production migration. No assistant SQL/tests/analysis/build/live execution; complete owner rerun and unattended release proof remain pending. Run ROLLBACK separately after the aborted query, then run the entire latest exam_results.sql. Expect all named rows PASS, failed=0, overall=PASS, failures=[]. No disposable materials or Git mutations.


## M9-BE-02 owner-reported SQL PASS - 2026-10-25

Owner supplied exam_results.sql summary: passed=231, failed=0, overall=PASS, failures=[]. Records successful DEV SQL regression after the fixture-identity correction, on owner aggregate evidence only. Supersedes SQL prepared/rerun-pending status above for the maintained suite's release/second-chance cases, including refusal snapshots, guarded deterministic finalization, audit/inbox and replacement-attempt checks. No per-case artifacts, independent remote migration inspection or assistant execution inferred. No SQL rerun requested absent a new defect/change.

M9-BE-02 remains PENDING unattended release proof and fixture cleanup: owner must supply the updated exam_cron_inspect.sql PASS/proof and exam_cron_cleanup.sql fixtures_removed=true. Prior M8 scheduler evidence does not accept the added release/inbox predicates. No production migration/API/frontend changes, tests/analysis/build/live checks, disposable materials or Git mutations in this evidence-only update. Ignored decisions.md stays local; canonical Graphify freshness remains blocked by existing semantic-source mismatches.


## M9-BE-02 owner unattended release PASS - 2026-10-25

Owner supplied unattended_overall=PASS for reserved session 8b020000-0000-4000-8000-000000000006: auto_submitted, attempt_no=1, auto_score=total_score=points_awarded=7, essay_score=0, is_correct=true, grading_complete=true, submitted_at=deadline_at (2026-10-25 04:41:31.422484 UTC). Results released at 2026-10-25 04:42:00.014760 UTC (12:42:00.014760 Philippine time); successful_cron_after_expiry=true and correct_release_inbox=true. Establishes owner-reported unattended finalization/release/inbox acceptance for the maintained proof, alongside SQL regression 231 PASS/0 FAIL. Initial NO FIXTURE preceded successful setup and does not represent a release failure.

Only committed-fixture cleanup remains pending: run maintained backend/tests/exam_cron_cleanup.sql as DEV postgres and supply fixtures_removed=true. Do not rerun passing regression or cron setup absent a new defect. This supersedes prior unattended-pending statements, without claiming cleanup, independent DEV inspection, migration-ledger verification, broader concurrency, frontend or device/offline acceptance. Evidence-only documentation update; no assistant tests/SQL/live/analysis/build checks, disposable local materials, staging, commit or push. Existing Graphify semantic mismatches still block canonical publication.


## M9-BE-02 COMPLETE - owner cleanup accepted, 2026-10-25

Owner supplied fixtures_removed=true from the maintained DEV cron cleanup. M9-BE-02 is COMPLETE for requested backend SQL/cron scope on owner evidence: exam_results.sql 231 PASS, 0 FAIL, overall PASS, failures []; unattended_overall PASS with auto-submission, score7, completed grading, deadline-preserving submitted_at, successful cron after expiry, released results and correct release inbox; committed proof fixtures removed. Supersedes all earlier prepared/pending SQL/cron/cleanup statements for this task. No repeat tests requested absent a new change or defect.

Only demonstrated defect was fixture JWT identity inheritance, fixed in the maintained SQL helper with owner-scoped construction/restored claims and a regression assertion. No production correction/migration, public API or frontend change required. Acceptance is owner-reported, not assistant runtime execution or independent remote migration verification; broader concurrency/mobile/offline scope is not inferred. No disposable local files created or retained, staging, commit or push. Ignored decisions.md stays local; Git handoff includes only backend/tests/exam_results.sql, backend/tests/exam_cron_inspect.sql and backend/tests/README.md. Graphify workspace artifacts sit outside the app Git repository; prior semantic-source mismatches still block canonical publication.

## M9-BE-03 release wait - prepared 2026-10-25

M9-SA-01 acceptance confirmed by owner. Owner reports successful DEV migration 20261024110000 and results SQL 249 PASS / 0 FAIL, overall PASS, failures [] (2026-10-25). Owner-reported unattended HOLD PASS, final PASS and fixtures_removed=true accepted; M9-BE-03 complete for requested backend DEV scope. Do not rerun cron setup or the passing proof absent a new defect. Do not rerun the passing SQL suite absent a new change or defect. Earlier M9-BE-02 PASS records are historical: the cron proof now includes a 10-minute hold and supersedes its two-minute final-release instruction.

1. In DEV `fiobwfzmqcffbpixzvbq`, inspect migration history. Apply only `20261024110000_exam_release_wait.sql` after the existing migrations through `20261024100000`. Never edit an applied migration or deploy unrelated pending work.
2. Run the entire updated `backend/tests/exam_results.sql` as SQL Editor postgres, BEGIN through ROLLBACK. Expect every named row PASS, `failed=0`, `overall=PASS`, `failures=[]`. M9C checks cover an unchanged unreleased snapshot, one microsecond before and exactly at the wait boundary, ignored voided timestamps, replacement-attempt blocking/new wait, last-essay grading during the wait, score privacy, and missing timestamps. Existing cases retain closing/manual bypass, progress/grading refusals and repeated-release inbox checks. Synthetic timestamps avoid sleeping inside the rollback transaction.
3. Run `backend/tests/exam_cron_setup.sql` once and save the printed times. It commits reserved fixtures for the real minute job. Keep apps closed and do not call submission, result, recovery or worker RPCs for these identities. After `inspect_after` (about two minutes), run `backend/tests/exam_cron_inspect.sql` in a fresh query before `release_eligible_at`. Expect `HOLD PASS`, auto-submitted/scored/graded state, null release timestamp and no results inbox row. Save this early observation: a later PASS alone cannot prove the hold was observed.
4. After `release_inspect_after` (about twelve minutes), run the read-only inspect again. Expect final `PASS`, release at/after `release_eligible_at`, `successful_cron_after_wait=true`, and `correct_release_inbox=true`. Compare release time against eligibility and job history: with a healthy minute job, expect the next successful tick, normally less than a minute later. Inspect again to confirm the timestamp and unique notification remain unchanged. WAIT means inspect later; FAIL or unavailable cron leaves acceptance pending. Never manually finalize to make the proof pass.
5. Save both observations and job history, then run `backend/tests/exam_cron_cleanup.sql`. Expect `fixtures_removed=true`. On cleanup refusal, report the mismatch without broadening deletion. After SQL abort, run `ROLLBACK;` separately before retrying the complete suite. If setup disconnects, inspect the reserved IDs before rerunning; setup refuses existing fixtures. These are backend checks with apps closed; frontend offline behavior is unchanged and not accepted by this proof.
6. Share the DEV migration state, SQL summary, HOLD PASS, final PASS with timings/job history, and cleanup output. Record actual owner evidence before marking M9-BE-03 complete. No assistant SQL, test, build, static analysis or live verification was run.

### M9-BE-03 unattended acceptance - 2026-10-25

Owner supplied HOLD PASS then unattended PASS on 2026-10-25: reserved session 8b020000-0000-4000-8000-000000000006 auto_submitted, score7, grading complete, submitted_at=deadline_at=2026-10-25T05:04:15.765408Z. Early observation had null release and no inbox with successful expiry cron. Eligibility was 05:14:15.765408Z; release occurred 05:15:00.057649Z (13:15:00.057649 Philippine time), 44.292241 seconds after eligibility, with successful_cron_after_wait=true and correct_release_inbox=true. Confirms owner-reported unattended hold and release on the next minute tick; initial WAIT preceded finalization and was followed by HOLD PASS. Together with applied migration and SQL249PASS/0FAIL, only guarded fixture cleanup remains pending. No assistant execution or independent remote verification. Run only `backend/tests/exam_cron_cleanup.sql` next as DEV postgres; expect `fixtures_removed=true`.

### M9-BE-03 COMPLETE - 2026-10-25

M9-BE-03 COMPLETE for requested backend DEV scope on owner evidence (2026-10-25): migration 20261024110000 applied successfully; results SQL 249 PASS / 0 FAIL, overall PASS, failures []; unattended HOLD PASS before eligibility followed by release PASS 44.292241 seconds after eligibility with successful cron and correct unique inbox; guarded cleanup fixtures_removed=true. Supersedes all earlier pending migration/SQL/cron/cleanup statements for this task. No repeat checks needed absent a change or defect; no assistant test/SQL/live execution or independent remote verification, broader frontend/device/offline/concurrency acceptance not inferred. Earlier run instructions are retained for future regression, not a request to rerun passing checks. No disposable testing materials created or retained.


## M9-BE-04 score override - prepared 2026-10-25

M9-SA-01 acceptance for overrides confirmed by owner. Implementation prepared; migration, SQL and concurrency
acceptance remain pending. No assistant tests/SQL/live verification/static analysis/builds were run.

1. From `filo-app/backend`, inspect DEV migration history with `supabase migration list --linked`.
   Confirm the linked project is DEV `fiobwfzmqcffbpixzvbq`, all earlier repository migrations are applied,
   and the only pending migration is `20261025100000_exam_score_override.sql`. Then run
   `supabase db push --linked`. Stop if unrelated migrations are pending; do not apply them with this task.
   Expect this new version applied successfully; never edit an applied migration.
2. As DEV SQL Editor postgres, run the WHOLE maintained `backend/tests/exam_results.sql`, BEGIN through
   ROLLBACK. Expect every named row PASS, failed=0, overall=PASS, failures=[]. M9D adds all four types on
   unanswered rows, existing response preservation, zero/partial/full points, Unicode 2000/2001 limits,
   null/negative/excessive/fractional integer input, progress/voided/wrong-quiz refusals, other instructor/student/
   anonymous/unverified denial, retry uniqueness, automatic regrade persistence and unchanged refusal snapshots.
   Existing grade_essay tests still expect truncation; only override_points rejects oversized feedback.
3. Inspect M9D release assertions: pending essays block release, last essay overrides complete grading without
   bypassing the accepted hold, release occurs at eligibility, already-released corrections update get_result.score
   and preserve the release timestamp/inbox count. The suite uses rollback fixtures and synthetic time; do not
   rerun the committed unattended cron setup solely for this migration. Its global-worker guard still applies.
4. Concurrency needs two independent DEV SQL connections and a dedicated disposable submitted fixture containing
   a non-essay answer. Record its session/question UUIDs plus its verified owner's user/auth-session UUIDs.
   Use only that owner's fixture. In connection A run the following, replacing all four UUID placeholders:

   ```sql
   begin;
   select set_config('request.jwt.claims',jsonb_build_object(
     'sub','OWNER_USER_UUID','session_id','OWNER_AUTH_SESSION_UUID','role','authenticated')::text,true);
   set local role authenticated;
   select public.override_points('SESSION_UUID','QUESTION_UUID',1,'Concurrent correction');
   -- Leave the transaction open; use a question worth at least one point.
   ```

   In connection B (postgres), run `begin; select public.grade_session('SESSION_UUID');`.
   Expect it to wait. In A run `commit;`; expect B to finish, then run `commit;` in B.
   Inspect as postgres with:

   ```sql
   select points_awarded, is_correct, feedback, graded_by
     from public.exam_answers where session_id='SESSION_UUID' and question_id='QUESTION_UUID';
   select auto_score, essay_score, total_score, grading_complete
     from public.exam_sessions where id='SESSION_UUID';
   ```

   Expect one manual answer with points=1, the recorded owner/feedback, and totals matching all answers.
   Repeat in reverse order: A (postgres) begins and calls grade_session, B begins with the same owner claims/role
   and calls override_points. B waits until A commits; after B commits the override and totals must be correct.
   Repeat two simultaneous overrides to different questions of the same attempt; the second waits, then totals
   include both corrections. No deadlock, lost mark or stale totals is acceptable. Remove only these dedicated
   fixtures using their established fixture cleanup; never delete real attempts or broaden cleanup scope.
5. Send an authenticated Supabase RPC request with JSON p_points=1.5 (not a SQL cast) and the same fixture IDs.
   Expect rejection and unchanged stored points/feedback/totals. The integer SQL signature rejects fractional
   integer text in the maintained suite; SQL casts like `1.5::integer` round before the function receives input.
6. For transport recovery, use the dedicated fixture to send the same valid override twice, including once after
   a simulated lost response. Expect one answer, the intended points, accurate totals and no repeated release
   notification. On network failure do not display confirmed success; retry/re-read when connected. No frontend
   override UI is implemented by this backend task, so app offline acceptance remains blocked on that feature.
7. Share migration state, the full SQL summary and two-connection observations. Any FAIL, missing output or
   disconnect leaves acceptance pending. After SQL abort run `ROLLBACK;` separately, correct the cause, then rerun
   the complete suite. On uncertain commit outcome read the dedicated attempt before retrying. Maintained fixtures
   roll back; external webhook effects are not guaranteed to roll back. No disposable guide/script files are needed.


### M9-BE-04 owner-reported SQL PASS - 2026-10-25

Owner supplied results summary: passed=299, failed=0, overall=PASS, failures=[]. Records owner-reported SQL regression acceptance for the updated maintained exam_results.sql, including M9D override cases. Supersedes SQL-run-pending wording above; no passing SQL rerun requested absent a new change or defect. Migration application/ledger confirmation, separate two-connection concurrency and fractional JSON/transport-retry checks have not been supplied; overall task acceptance remains pending those owner checks. No assistant tests, SQL, live verification, static analysis or builds, and no frontend/offline acceptance inferred.


### M9-BE-04 owner migration ledger confirmed - 2026-10-25

Owner supplied successful `npx.cmd supabase migration list --linked` output showing local and remote versions matched through 20261025100000 (2026-10-25 10:00:00 UTC), including all prior listed migrations. Records owner-supplied linked migration ledger evidence for the score override migration; no assistant remote inspection. Together with SQL299PASS/0FAIL overallPASS failures[], migration and maintained SQL acceptance are recorded. Separate two-connection concurrency and fractional JSON/transport-retry evidence remain pending; do not rerun the passing SQL suite absent a change or defect. No assistant tests, SQL, live checks, analysis/builds or Git mutations.


### M9-BE-04 COMPLETE - owner DEV evidence, 2026-10-25

Requested backend DEV scope accepted on owner evidence: linked migration ledger matched through 20261025100000; maintained results SQL299PASS/0FAIL overallPASS failures[]; override-first grading call elapsed19.09s and reverse-order override elapsed19.03s, consistent with session serialization. Both orderings retained points1/is_correct=false, the owning instructor graded_by and correct feedback; auto_score1/essay_score0/total_score1 matched independent sums. Owner showed both identical valid HTTP calls succeeded; subsequent fractional JSON p_points1.5 returned HTTP400, followed by answer points1/is_correct=false/feedback HTTP retry check and unchanged total1. The HTTP response body was empty, so no exact SQLSTATE/error-message attribution is claimed. Repeated HTTP calls prove identical retry behavior, not an independently observed dropped response. Supersedes prior pending migration/SQL/concurrency/HTTP acceptance wording for requested scope; do not rerun passing checks absent a change or defect.

No assistant tests/SQL/live verification/static analysis/builds. No frontend override UI/offline integration, broader load/concurrency or independent remote inspection claimed. No disposable materials created, staged, committed or pushed; owner-created app test attempt is retained without deletion. Background Schema and decisions remain ignored local docs; Graphify artifacts are outside app Git, and prior canonical semantic-source blockers remain.


## M10-BE-02: AI limits and atomic flag

Status 2026-10-27: implementation and maintained checks prepared; **Not run**. Owner DEV
execution/acceptance pending. Carry M10-BE-01 accepted evidence only within the QA register's
scope. No credentials or question/source content should be pasted into evidence.

1. In `filo-app/backend`, inspect the linked project and migration ledger before applying:

   ```powershell
   npx.cmd supabase migration list --linked
   npx.cmd supabase db push --linked --dry-run
   # Continue only when the target is DEV fiobwfzmqcffbpixzvbq and pending changes are intended.
   npx.cmd supabase db push --linked
   npx.cmd supabase migration list --linked
   npx.cmd supabase functions deploy ai-generate-quiz --project-ref fiobwfzmqcffbpixzvbq
   ```

   Expect local/remote `20261027100000` to match. Apply migration before updated app caller.
   Never reset DEV or edit an applied file to correct a failure; use a later migration.
2. Run WHOLE `ai_requests.sql` as postgres in the DEV SQL editor. Expect overall PASS, zero
   failed, failures `[]`, then ROLLBACK (fixtures removed). Any uncaught error is a failure;
   run `ROLLBACK;` separately before correcting/rerunning. This exercises service-role RPCs,
   anonymous/verified student/verified instructor denials, all flag shapes, full late-failure
   rollback and the actual existing cron command with strict 30-day boundary. No scheduled
   execution, actual HTTP authentication or concurrent transactions are claimed by this suite.
3. Run maintained mocked checks (no live API/provider calls):

   ```powershell
   # From filo-app/backend
   deno test --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts
   # From filo-app/frontend
   flutter test test/features/assessments/quiz_save_ai_test.dart
   ```

   Expect zero failures, including one save RPC carrying the flag, no question PATCH, success
   and unexpected-failure finalization/retry, and an overlapping mocked refusal that neither
   starts a provider call nor finishes the active row. Existing mock coverage is regression
   evidence only; it does not substitute for DEV row inspection or real database locks.
4. In DEV, use a fresh verified instructor token, owned active class and unlocked quiz. The
   values below are private local placeholders; use neutral synthetic source text only:

   ```powershell
   $aiHeaders = @{ Authorization = 'Bearer <fresh-verified-instructor-token>'; apikey = '<DEV-publishable-or-anon-key>' }
   $aiBody = @{
     class_id = '<owned-active-class-uuid>'; quiz_id = '<unlocked-quiz-uuid>'
     texts = @(@{ file_name = 'fixture.txt'; text = 'Plants use sunlight for photosynthesis.' })
     counts = @{ multiple_choice = 0; true_false = 0; identification = 0; essay = 1 }
     difficulty = 'easy'
   } | ConvertTo-Json -Depth 6
   $aiUrl = 'https://fiobwfzmqcffbpixzvbq.supabase.co/functions/v1/ai-generate-quiz'
   try {
     foreach ($aiMode in @('sample','AI_BUSY','AI_TIMEOUT','AI_BAD_OUTPUT','unexpected')) {
       npx.cmd supabase secrets set --project-ref fiobwfzmqcffbpixzvbq "AI_TEST_MODE=$aiMode"
       if ($LASTEXITCODE -ne 0) { throw 'Setting DEV simulation failed' }
       $aiSince = (Get-Date).ToUniversalTime().ToString('o')
       Write-Output "mode=$aiMode since=$aiSince"
       try {
         $aiResponse = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $aiUrl -Headers $aiHeaders -ContentType 'application/json' -Body $aiBody
         Write-Output "HTTP=$($aiResponse.StatusCode)"
       } catch {
         $aiHttpResponse = $_.Exception.Response
         if ($aiHttpResponse) {
           Write-Output "HTTP=$([int]$aiHttpResponse.StatusCode)"
           $aiErrorText = $_.ErrorDetails.Message
           if ([string]::IsNullOrWhiteSpace($aiErrorText)) {
             if ($aiHttpResponse.PSObject.Methods.Name -contains 'GetResponseStream') {
               $aiReader = New-Object System.IO.StreamReader($aiHttpResponse.GetResponseStream())
               try { $aiErrorText = $aiReader.ReadToEnd() } finally { $aiReader.Dispose() }
             } elseif ($aiHttpResponse.Content) {
               $aiErrorText = $aiHttpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
             }
           }
           $aiErrorCode = 'BODY_UNAVAILABLE'
           if (![string]::IsNullOrWhiteSpace($aiErrorText)) {
             try { $aiErrorCode = ($aiErrorText | ConvertFrom-Json -ErrorAction Stop).error.code }
             catch { $aiErrorCode = 'NON_JSON_RESPONSE' }
           }
           Write-Output "code=$aiErrorCode"
           if ([int]$aiHttpResponse.StatusCode -in @(401,403)) {
             throw 'Authorization blocked: resolve token/session/role/ownership before simulations'
           }
         } else { throw }
       }
       # Inspect the matching DEV row before continuing; do not print generated/source content.
       Read-Host 'Record matching row status/code/finished_at, then press Enter'
     }
   } finally {
     npx.cmd supabase secrets set --project-ref fiobwfzmqcffbpixzvbq AI_TEST_MODE=off
     if ($LASTEXITCODE -ne 0) { Write-Error 'AI_TEST_MODE reset failed; restore off before leaving DEV' }
   }
   ```

   Expect sample 200/success/null error; AI_BUSY 503/failed/AI_BUSY; AI_TIMEOUT
   504/failed/AI_TIMEOUT; AI_BAD_OUTPUT 502/failed/AI_BAD_OUTPUT; unexpected
   503/failed/AI_UNAVAILABLE. Every acquired row needs nonnull finished_at. Sample returns
   deterministic DEV questions, not a provider success. All modes still require authorization.
   Inspect using the recorded UTC start and the actual instructor UUID (postgres only):

   ```sql
   select id,user_id,kind,status,error_code,created_at,finished_at
   from public.ai_usage_log
   where user_id='<instructor-uuid>' and created_at >= '<recorded-UTC-start>'::timestamptz
   order by created_at,id;
   ```

   Expect exactly one matching acquired row per sequential request. Capture metadata only.
   If both finalization attempts fail, the response is AI_UNAVAILABLE and the row may remain
   started; this is a failure to record, not a terminal-row Pass. Inspect before retrying.
5. Open two independent DEV SQL sessions and run labeled A/B blocks from `ai_concurrency.sql`
   while A sleeps. Expect A ID, B waiting then NULL, and only_one_acquired=true. Run C afterward;
   expect a successful finished row and fixtures_removed=true. Do not run the whole file.
   This is the deterministic database race check, separate from the mocked handler overlap.
6. With the test switch off and provider configured, launch two HTTP requests for the same
   instructor at once. Reuse the local variables from step 4 and run in PowerShell:

   ```powershell
   $aiJobs = @()
   try {
     $aiConcurrentSince = (Get-Date).ToUniversalTime().ToString('o')
     foreach ($aiNumber in 1..2) {
       $aiJobs += Start-Job -ArgumentList $aiUrl,$aiHeaders,$aiBody -ScriptBlock {
         param($url,$headers,$body)
         try {
           $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Headers $headers -ContentType 'application/json' -Body $body
           [pscustomobject]@{ status = [int]$response.StatusCode; code = $null }
         } catch {
           if (!$_.Exception.Response) { throw }
           $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
           [pscustomobject]@{ status = [int]$_.Exception.Response.StatusCode; code = $errorBody.error.code }
         }
       }
     }
     $aiJobs | Wait-Job | Receive-Job
     Write-Output "Inspect rows since $aiConcurrentSince"
   } finally {
     $aiJobs | Remove-Job
   }
   ```

   Expect one acquired generation and one 409/AI_IN_PROGRESS, with one new usage row. The
   accepted request may return a real provider error; record its finished status separately.
   If both complete sequentially there was no demonstrated overlap: record inconclusive,
   rather than declaring a locking failure or Pass. Never persist test-switch changes in prod.
   Repeat with a second verified instructor and their own class/quiz while the first user's
   request is pending; expect independent acquisition, subject to the shared provider quota.
7. Run only SETUP in `ai_cleanup_job.sql`. Capture active job/schedule/timezone and committed
   tagged fixtures. Wait for the next daily 03:15 cron tick (default GMT means 11:15 Manila),
   then run INSPECT. Expect old_removed/recent_retained/scheduled_success all true and successful
   job details after setup. A manual DELETE or rollback suite cannot establish scheduler Pass.
   If job-run history is unavailable, retain this evidence gap. Run CLEANUP and expect
   fixtures_removed=true. Do not reschedule the shared daily job merely to shorten this check.
8. For save integration, use the RPC with true/false/omitted flags and refetch questions as the
   owning instructor. Expect the documented stored flag and sticky true on edits. The SQL suite
   covers all four question shapes through the existing contract's shared save path; prior M7
   type-specific evidence remains scoped there. The AI-generation UI is unfinished: use RPC
   plus the caller mock for this task; do not mark a complete generation-to-badge UI flow Pass.
   With network disconnected, generation/saving must not report confirmed success; reconnect,
   refetch uncertain creates before retrying, and expect finished requests to release the AI
   slot immediately. After SQL abort ROLLBACK; after uncertain HTTP inspect row metadata first.
9. Send migration ledger, full SQL summary, mocked summaries, per-mode metadata, concurrency
   observations, cron details and fixture-cleanup booleans. Keep tokens and source/output bodies
   private. Record gaps and owner sign-off separately in decisions and QA acceptance register.


## M10-BE-02 owner DEV results - 2026-10-28

Owner supplied SQL summary: 76 passed, 1 failed, overall FAIL; sole reported failure
`log has no app policies`. This assertion currently requires zero pg_policy rows, not merely
absence of policies permitting app access. Existing local migrations declare no log policies;
actual DEV policy names/roles/expressions are not supplied. Root cause remains unresolved:
do not weaken the assertion, remove unknown policies, or infer an app data leak without those
definitions. Other SQL checks passed on owner aggregate evidence, including role denials;
full per-case output not supplied. Preserve the overall failure until resolved.

Owner terminal attachment confirms ai-generate-quiz deployment to DEV fiobwfzmqcffbpixzvbq,
Deno 17 PASS / 0 FAIL, and focused Flutter quiz_save_ai_test 8 PASS / 0 FAIL. These focused
suites are accepted within the supplied run scope; no rerun requested without relevant changes.
Migration ledger not supplied; live simulations, real concurrency, scheduled-cleanup evidence,
fixture cleanup and overall owner acceptance remain pending. No assistant tests or live checks.
Evidence: owner SQL summary in conversation and attachment d258d435-25a6-438f-b993-cd1364140814/
Pasted text.txt. No credentials or question/source content retained. No implementation changes
or disposable testing materials; read-only DEV policy inspection is the next owner action.


## M10-BE-02 restrictive policy assertion correction - 2026-10-28

Owner supplied DEV policy definition: require_verified_session, RESTRICTIVE, authenticated,
ALL, USING current_user_ok(), WITH CHECK current_user_ok(). This matches migration
20261014160000_verified_session_gate, whose dynamic loop adds this restrictive gate to public
tables, including ai_usage_log. Earlier statements implying no policies exist are superseded:
there are no granting/permissive log policies in the supplied definition. A restrictive gate
cannot independently grant access; removing it would remove an intended session restriction.

Corrected only ai_requests.sql's overly broad zero-policy assertion to require no permissive
access policies. RLS-enabled, app privilege revocations, anonymous/student/instructor read/write
and RPC-denial checks, and service-role success checks remain unchanged. No production defect
or new migration is required for this test correction; applied files and DEV policies untouched.
Historical owner SQL76PASS1FAIL remains recorded; corrected SQL owner rerun pending, not Pass.
Prior Deno17PASS and Flutter8PASS remain accepted; no rerun requested because neither changed.
No assistant tests, static analysis, builds, SQL/live verification, deployment or secrets changes.
Live simulations, real concurrency, scheduled cleanup, migration ledger and overall acceptance
remain pending. No disposable materials or Git mutations.


## M10-BE-02 owner corrected SQL PASS - 2026-10-28

Owner supplied corrected ai_requests.sql summary: 77 passed, 0 failed, overall PASS,
failures []. Accept this maintained SQL suite within its owner-run DEV scope. Supersedes
SQL76PASS1FAIL and corrected-SQL-rerun-pending status; preserve that historical false-positive
failure and the restrictive-policy correction above. Source commit/build and full per-case
output were not supplied. Covers the script's atomic AI flags/backward compatibility/late
rollback, sequential in-flight/stale recovery, finalization, role denials, log metadata/RLS/
no-permissive-policy assertion and actual cleanup command under rollback. Does not prove
real concurrent sessions, deployed HTTP simulation branches or scheduled cron execution.

Prior owner Deno17PASS0FAIL, Flutter8PASS0FAIL and DEV function deployment remain accepted
within recorded scope; no repeat tests requested absent relevant changes. Migration ledger,
live success/error/unexpected simulations, real concurrency, scheduled-cleanup/committed
fixture removal evidence and overall explicit owner acceptance remain pending. No assistant
tests, SQL/live checks, static analysis, builds, deployments, secrets or production changes.
Evidence source: owner summary pasted in conversation on 2026-10-28; target DEV project
fiobwfzmqcffbpixzvbq per ongoing run context. No separate overall owner sign-off supplied.
No disposable materials or Git mutations; evidence-only documentation update.


## M10-BE-02 owner single-row finalization and cleanup - 2026-10-28

Owner screenshot shows only_one_acquired=true. Follow-up metadata shows one row with status
success, error_code null, created_at 2026-10-27 16:11:38.569491 UTC and finished_at
2026-10-27 16:12:48.206997 UTC. Owner reports fixtures_removed=true. Accept single-row
observation, successful finalization and dedicated concurrency-fixture cleanup within this
DEV run. No need to repeat those evidenced checks. Evidence: owner screenshot and pasted
metadata/cleanup result in conversation; build/commit unknown. Times above are database UTC;
record date follows Manila conversation date. No source/answer content or credentials retained.

Actual overlap remains unconfirmed: owner has not yet confirmed B started while A was running
and waited; screenshot and one-row count also permit sequential invocation. Do not mark real
concurrent-lock contention Pass from these outputs alone. Ask for timing confirmation rather
than immediately requesting a rerun. Prior SQL77PASS, Deno17PASS, Flutter8PASS and deployment
remain scoped accepted. Live simulation rows, scheduled cleanup, migration ledger and overall
explicit owner acceptance remain pending. No assistant tests/live checks, implementation or
policy changes, disposable materials or Git mutations.


## M10-BE-02 owner DB concurrency PASS - 2026-10-28

Owner explicitly confirmed B started while A was still running and waited before returning.
Combined with the supplied only_one_acquired=true screenshot, one successfully finalized row
and fixtures_removed=true, accept the two-session database concurrency check as Pass - owner
reported. Supersedes prior overlap/timing-unconfirmed status; no rerun required. Exact wait
duration/backend PIDs were not supplied; no broader load or concurrent deployed HTTP proof
is inferred. No overall task sign-off is inferred from this scoped yes confirmation.

Prior SQL77PASS0FAIL, Deno17PASS0FAIL, Flutter8PASS0FAIL, deployment, successful finalization
and dedicated concurrency-fixture cleanup remain accepted within recorded scope. Migration
ledger, latest deployed live simulations (including unexpected failure), scheduled 30-day
cleanup/its dedicated fixtures, HTTP overlap if required and overall acceptance remain pending.
Evidence: owner yes to explicit overlap/wait question, linked to preceding screenshot and
metadata outputs in conversation. DEV target fiobwfzmqcffbpixzvbq, build/commit unknown.
No assistant execution, implementation changes, disposable materials or Git mutations.


## M10-BE-02 live simulation attempt blocked by authorization - 2026-10-28

Owner transcript shows batch start 2026-10-27T16:25:00.3782821Z, five HTTP403 responses
(sample, AI_BUSY, AI_TIMEOUT, AI_BAD_OUTPUT, unexpected), and final successful secrets reset
AI_TEST_MODE=off. Each catch also raised ConvertFrom-Json on null ErrorDetails.Message;
exact backend error codes are therefore not evidenced. Treat simulation scenarios as blocked/
not established, not Pass. Do not attribute the 403 to a particular prerequisite without
checking token/session/profile/class/quiz. No usage-row output supplied for this batch.

Owner supplied cron_timezone=GMT. Existing daily03:15 schedule corresponds to11:15AM Manila;
timezone alone does not establish job active/schedule, fixture setup or actual scheduled deletion.
Prior SQL77PASS/Deno17PASS/Flutter8PASS/DB-concurrency/finalization/fixture cleanup evidence
remains accepted within recorded scope. Ledger, live simulation rows, scheduled-cleanup evidence
and overall acceptance remain pending.

Corrected README PowerShell catch to read response stream/content when ErrorDetails is absent,
skip null/non-JSON parsing and stop on401/403 while retaining finally reset. No app/migration
changes, assistant tests/static analysis/builds/live verification/deployment or secret changes.
Evidence: owner attachment7bc0f414-c4a5-4e7e-9fad-c84ee838d785/Pasted text.txt and timezone output.
Only sanitized results retained; no credentials/source/output bodies copied into project docs.
No disposable materials/Git mutations. Next owner action: validate token via auth/user endpoint.


## M10-BE-02 owner five live HTTP simulations PASS - 2026-10-28

Owner exact curl diagnostic first confirmed Auth200, valid bearer format, email present,
matching subject, valid session UUID,3003seconds until expiry and correct function URL.
Subsequent batch started2026-10-27T16:42:12.7761422Z and returned:
sample200; AI_BUSY503/AI_BUSY; AI_TIMEOUT504/AI_TIMEOUT; AI_BAD_OUTPUT502/AI_BAD_OUTPUT;
unexpected503/AI_UNAVAILABLE. All five HTTP simulation outcomes accepted on owner evidence.
Final AI_TEST_MODE=off secrets command succeeded. Supersedes earlier denied simulation status
within this new run only; historical401/403 attempts and expiry evidence retained.

Matching usage rows not yet supplied: terminal status/error_code/finished_at for this batch
remain pending and must not be inferred from HTTP success. Earlier scoped SQL77/Deno17/
Flutter8/DB concurrency/finalization/fixture-cleanup passes retained, no repeat requested.
Evidence: owner pasted curl diagnostic and batch transcript in conversation; target DEV
fiobwfzmqcffbpixzvbq, build/commit unknown. GMT scheduled-cleanup fixture/run evidence,
migration ledger and overall owner acceptance remain pending. No credentials/source/output
content retained. No assistant tests/live checks, code changes, disposable materials or Git
mutations. Next owner action: read-only query for this batch's five log rows.


## M10-BE-02 owner live simulation finalization PASS - 2026-10-28

Owner supplied exactly five usage rows matching the accepted16:42:12.7761422UTC batch:
success/null created16:42:19.596010 finished16:42:19.671916;
failed/AI_BUSY created16:42:25.784059 finished16:42:25.848125;
failed/AI_TIMEOUT created16:42:32.313968 finished16:42:32.362580;
failed/AI_BAD_OUTPUT created16:42:38.935563 finished16:42:39.047663;
failed/AI_UNAVAILABLE created16:42:46.451577 finished16:42:46.520999.
All times2026-10-27 UTC; every finished_at populated and after created_at. Combined with
preceding five expected HTTP outcomes, accept sample and all four simulated failure-path
finalizations, including ordinary unexpected exception. Supersedes live-log-rows-pending
within this run. Prior final switch-off reset remains evidenced; no simulation rerun needed.

Evidence: owner pasted five metadata rows in conversation on2026-10-28; DEV target
fiobwfzmqcffbpixzvbq, deployed build/commit unknown. No source/question/answer content retained.
Prior SQL77/Deno17/Flutter8/DB concurrency and dedicated concurrency-fixture cleanup remain
scoped accepted. Remaining: migration-ledger confirmation, actual scheduled30-day cleanup
with its committed fixture retention/deletion/job details and subsequent fixture cleanup,
and explicit overall owner acceptance. No concurrent deployed-HTTP claim inferred from DB
concurrency. No assistant tests/live checks, implementation/disposable materials/Git mutations.


## M10-BE-02 owner migration ledger matched - 2026-10-28

Owner supplied successful npx.cmd supabase migration list --linked output: every displayed
local/remote version matches through20261027100000, including the task migration. Migration
ledger confirmation accepted on owner DEV evidence; supersedes pending-ledger statements.
No independent remote inspection or source-checksum proof inferred. Prior scoped SQL77PASS,
Deno17PASS, Flutter8PASS, database concurrency/finalization/fixture cleanup and five HTTP/log
simulation passes retained; test switch last evidenced off. No rerun needed.

Remaining runtime check: actual scheduled30-day purge of committed old fixture, retention of
recent fixture, successful job details after setup and final cron-fixture cleanup. TimezoneGMT
confirmed; daily03:15 is11:15Manila. Explicit overall owner acceptance remains separate and
pending. No deployed-HTTP concurrency/load evidence inferred from the DB race. No assistant
tests/live checks, implementation/disposable materials/Git mutations or credentials recorded.
Evidence: owner migration-list output pasted in conversation, DEV project per current run
fiobwfzmqcffbpixzvbq; source commit/build unknown.


## M10-BE-02 owner cron fixture collision - 2026-10-28

Owner screenshot reports P0001 Fixture collision: inspect existing rows before continuing,
from cleanup script SETUP guard. Screenshot shows CLEANUP text in editor but does not prove
which selection was run; likely SETUP included again, execution selection unknown. Existing
reserved fixture user/IDs detected; scheduled deletion/retention still not evidenced. Do not
infer data corruption, cron failure or successful cleanup. Preserve existing fixtures until
read-only inspection. Roll back aborted transaction if present; run only inspection query,
never repeat SETUP or delete fixtures before collecting scheduler evidence. Prior scoped
passes and ledger match retained; no repeats requested. No assistant execution/implementation
changes/disposable materials/Git mutations. Evidence: owner screenshot in conversation.


## M10-BE-02 owner cron fixtures waiting for next tick - 2026-10-28

Owner read-only inspection: checked_at2026-10-27 16:48:51.354638UTC,
fixture_setup_at2026-10-27 16:21:56.119014UTC, old_removed=false,
recent_retained=true, scheduled_success=false. This confirms committed recent fixture exists
and old fixture remains before the next scheduled tick; it is not a scheduler failure or Pass.
With recorded GMT timezone and daily03:15 schedule, first scheduled run after setup is
2026-10-28 03:15UTC / October28 11:15AM Manila. Inspect shortly after that tick, without
rerunning SETUP or deleting fixtures. Preserve historical SETUP collision and all prior scoped
passes. Actual scheduled old-row deletion/recent retention/post-setup job success and final
fixture cleanup remain pending; explicit overall acceptance also pending. No assistant execution,
production changes, disposable materials or Git mutations. Evidence: owner inspection CSV.


## M10-BE-02 COMPLETE / PASS - owner accepted, 2026-10-28

Overall task status: PASS - owner accepted, with an explicit outstanding-check exception.
Owner requested immediate completion/acceptance instead of waiting for the daily cron tick,
then clarified that the task should also be marked Pass. Record this as explicit overall owner
acceptance and waiver of the remaining scheduled-run evidence requirement, not fabricated
scheduled-cleanup execution. Supersedes earlier overall pending statements within this task.

Evidenced owner results retained: migration ledger matched through20261027100000; SQL77PASS/
0FAIL; Deno17PASS/0FAIL; Flutter8PASS/0FAIL; two-session DB concurrency, finalization and its
fixture cleanup; all five live HTTP simulations and matching terminal usage rows; test switch
off reset. Historical failed assertions, authorization/expiry attempts and SETUP collision
remain preserved. Shared-key protection is per-user in-flight control, not a global quota.

Scheduled30-day cleanup execution: WAIVED BY OWNER / NOT OBSERVED, not runtime Pass.
Actual cleanup command passed under rollback in SQL suite; GMT/daily03:15 schedule recorded.
Last pre-tick inspection old_removed=false, recent_retained=true, scheduled_success=false is
expected before first post-setup tick, not a failure. No post-tick success is claimed. Dedicated
cron fixtures still exist per last evidence; their removal is optional housekeeping after the
waived check, not a reopened task acceptance gate. Owner can report later issues for follow-up.
Maintained SQL scripts/tests are lasting regression materials, not disposable files. No
assistant SQL/live execution/deployment/tests/static analysis/builds, no staging/commit/push.
No credentials/private question content retained. Unrelated changes preserved.

## Q3 staged AI quality regression (2026-10-28)

From filo-app/backend:

```powershell
deno test --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts supabase/functions/ai-generate-quiz/quality_test.ts
```

34 tests passed/0failed on assistant execution explicitly requested by owner. Includes prior
request/auth/DEV/finalization/concurrency/transport coverage and synthetic flawed-question
fixtures: missing/ambiguous solver answers, duplicate facts, glued words, unsupported absolutes,
skewed positions, deterministic balanced shuffle, exact evidence/lexical alignment, acronym
variants, essay rubric sums, failed-only retry/drop/spare, malformed verifier, deadline/partial
counts and key-blind payload/log privacy. These are maintained regression fixtures, not
copied private lesson files. Earlier30/1 run found acronym extraction bug, now fixed.

Owner DEV follow-up: set AI_TEST_MODE=off, deploy ai-generate-quiz, use fresh verified instructor
and owned unlocked quiz. Same11-question Easy/Medium requests should return only verified
questions, code-balanced MC options, source evidence and essay sample/rubric; partial response
must report actual missing counts. An unsupported provider schema/error must remain sanitized,
not fallback to unverified questions. Inspect quality_stats fixed counters, never private
payloads. Do not use sample mode to score quality. Deadline110s unchanged; clean3 calls,
up to13 with bounded repairs/spares, quota/latency may increase. No live performance promise.
Regeneration uses same pipeline for one selected type; existing prompts remain avoidance data.
Teacher-side metadata not added to student delivery or persistence schemas. No tests of the
live provider/deployed revision performed; five-file review and runtime acceptance pending.
Q3 contextual-answer follow-up: focused suites now35PASS/0FAIL after adding the regression
for acronym-expansion questions accepting their own stem acronym. Same test command above.

### Q3 independent cognitive/distractor review and contextual variants - 2026-10-28

Owner follow-up response exposed direct recall despite intended Medium, weak alternatives,
acronym echo/reverse variants and overlong source expansion prefixes. Shared variants now use
shortest matching source suffix; full-name questions exclude supplied acronym, acronym questions
exclude expansions. The existing blind batch additionally classifies cognitive_level and
plausible_options internally. No requested difficulty or source/key sent to reviewer. Code
requires recall forEasy, interpretation forMedium, multistep forHard and plausible MC options;
fixed verifier_difficulty/verifier_distractors errors use existing repair/drop path. These
model judgments can misclassify; no guarantee of calibrated difficulty. No public fields,
extra calls, dependencies or migration. Local/not deployed;37 focused testsPASS/0FAIL.
Previous35/34 evidence retained, no live/provider acceptance. See quality report for output.
### Q3.1 run diagnostics - 2026-10-28

quality_stats additionally logs pipeline_revision:"Q3.1" and trusted difficulty:"easy"|"medium"|
"hard" so future owner trials can identify current cognitive/distractor verifier code and
actual request setting. No source, personal IDs, keys, provider payloads or public response
fields added. Existing numeric/fixed-rule counters unchanged. New regression and focused
suites38PASS/0FAIL; local/not deployed. Marker cannot establish earlier deployment provenance.
### Q3.2 task-oriented blueprint - 2026-10-28

Owner DEV67 Medium partial outcome exposed heavy recall rejection and two recall survivors.
Blueprint adds required internal assessment_task:string(1–1000 chars), separate from fact,
with concrete learner action/scenario/inference. Medium/Hard planning must apply/interpret/
compare rather than paraphrase definitions or copied review questions. Generator executes
planned task and may construct neutral hypothetical examples whose rules/answers follow
from supplied source; no invented personal/domain facts. This does not relax source grounding.
Task is planner/generator data only, not in blind payload or public response. Internal schema/
fixtures/type helper updated; no request API, metadata persistence, student delivery, provider
call/budget or verifier/retry change. MarkerQ3.2, local/not deployed.40 focused testsPASS/0FAIL,
including required-task/data-flow and mocked scenario Medium acceptance. Not live improvement.
See quality report for preserved partial result and one bounded owner Medium trial.
### Q3.2 owner DEV68 trial limitation - 2026-10-28

Owner Q3.2/medium run returned2of11 with9missing; stats7calls/18question retries/20difficulty
mismatches,6near-duplicate-option hits,1glued-word hit. Surviving TF still source recall;
MC designer context still primarily definition recognition. Requested Medium quality target
FAILED, despite honest partial counts and40PASS mocked test evidence. No guarantee from blind
classifier; do not equate filtering/test Pass with sound quiz generation. Preserve failed
trial in ai-quality-check.md. No extra tuning/model switch/retry-budget increase made; proposed
next investigation is fixed human-labelled difficulty calibration, not another blind reroll.
## Accepted C1 verifier calibration runner

Maintained tests/ai_calibration.ts reuses current production blindReviewRequest and reads the
owner-accepted docs/ai-quality-calibration.md (normalized frozen hash checked). No fixture
question copy, new dependencies, production mode or API endpoint. --check is offline; --live
makes exactly one Gemini batch call/no retry, using local GEMINI_API_KEY and exact approved
GEMINI_MODEL. Instructor tokens are not used. Do not paste API keys into chat/Git/history.

From backend, offline check:

```powershell
deno run --allow-read=../docs/ai-quality-calibration.md --config supabase/functions/ai-generate-quiz/deno.json tests/ai_calibration.ts --check
```

After setting the private key and approved model in process environment, owner live command:

```powershell
deno run --allow-read=../docs/ai-quality-calibration.md --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_calibration.ts --live
```

Expect10items scored against locally held labels/keys. Review solving, level agreement and
false accepts/rejects separately; synthetic essay/ID solver answers permit manual review of
lexical matching limitations. HTTP/error is not calibration Pass; stop rather than silently
retrying. No latency/cost claims, no independent holdout claim if later used to tune prompts.
No live call by assistant. User must have accepted reference locally (docs Git-ignored);
missing/changed file fails closed; do not bypass hash or force-add ignored docs.

Focused offline regression command:

```powershell
deno test --allow-read=../docs/ai-quality-calibration.md --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts supabase/functions/ai-generate-quiz/quality_test.ts tests/ai_calibration_test.ts
```

43passed/0failed on authorized assistant execution; all HTTP mocked. No deployment required
for local runner; production shared request builder was extracted without behavior changes.
### Q3.3 targeted Medium repair - 2026-10-28

Local implementation only; owner execution pending. Medium generation now requires a
scenario-dependent decision (initial condition plus change/goal/action and consequence),
not a profession prefix or longer definition. Failed-objective repairs receive the previous
parsed question and observed blind cognitive label when available, rather than error names
alone; they may rebuild the task for the same fact. This private repair context goes only to
generation, never the blind reviewer or logs. Invalid provider objects are not forwarded.
The same failure-only two-retry limit, call/deadline bounds and public response remain.
Option similarity now preserves distinctions in numeric/ordinal/negation markers instead
of discarding them through word-set overlap; exact/cosmetic duplicates still fail and the
unchanged blind solver still rejects semantic ambiguity/weak alternatives. This is a lexical
heuristic, not proof that differing numbers make options valid. Statistics marker Q3.3.
Two maintained regressions cover repair context/blind isolation and option distinctions.
No tests/static analysis/builds/live calls/deployment run for this change; owner checks next.
No dependency, endpoint, schema/auth change, extra provider call or disposable fixture added.
C1 frozen reference and previous accepted evidence unchanged. This does not resolve the
five-file report or establish that Medium now succeeds; preserve DEV68 failure until rerun.

### Q3.4 shared difficulty criteria and directional diagnostics - 2026-10-28

Local implementation, owner execution pending. One shared cognitiveCriteria instruction is
used by generation/blueprint and blind review: recall/recognition, one-rule application,
and two dependent inferences. Decorative scenarios and longer explanations do not establish
Medium/Hard. Medium planning now prefers actionable source rules, concrete conditions and
one inference over glossary facts/repeating worked examples. Failed repairs include the
fixed difficulty_direction (too_easy/too_hard/null); guidance adds real application for too
easy and removes dependent steps for too hard without reverting to definitions.
The existing exact-level rejection gate, source/key/distractor checks, public JSON, deadline,
call path and two retries per objective remain. No extra model call or dependency added.
The observed TF giveaway 'guaranteed' is now checked alongside existing absolute words.

quality_stats revision Q3.4 adds difficulty_mismatches.too_easy and .too_hard, each containing
four question-type integer counters. These count repeated difficulty-rejection attempts,
not unique questions or model accuracy. Only validated verdicts with matching answer keys
that reach verifier_difficulty contribute; malformed verdicts/answer failures do not acquire
a fabricated difficulty direction. Existing counters retained. No source/stems/answers,
IDs, explanations, raw rationales or credentials added to logs. Repair context stays private
in memory/generation payload; blind data remains IDs/types/stems/options only. Unknown
labels still fail malformed validation; helper does not classify them as too easy.

Three maintained mocked regression tests added for direction mapping, shared criteria and
blind isolation/absolute check, plus per-type counters/bounded rejection/repair direction
for both too-easy and too-hard paths. Existing clean-run and repair tests extended. No tests,
static analysis, builds, live calls or deployments executed under owner-only testing policy.
Run the focused command already documented in tests/README.md before any further deployment
or live trial. Expected: zero failures; on missing/changed C1 stop, never bypass its hash.
Frozen C1 content/keys unchanged, but blind instructions changed: prior live C1 agreement
is historical evidence only, not a Q3.4 runtime Pass. No benchmark answers injected into
prompts. Prompt agreement and mocked verdicts cannot prove semantic classification; source-
relative example reuse is not visible to a source-blind reviewer. Instructor review remains
required. DEV70 failure/44-pass1-fail history and five-file/photo gaps preserved. No new
runtime/whole-task acceptance or success/latency/cost claim. No disposable materials created.

## Q4 structured application pipeline - 2026-10-28

Maintained regressions updated for structured source/application plans, independent review,
one bounded source audit, component repairs and private diagnostics. NOT RUN; previous48PASS
and C1 live evidence do not verify Q4. Frozen C1 content/hash unchanged. All test HTTP mocked.
No assistant tests, static checks, builds, live calls or deployment. From backend run:

```powershell
deno test --allow-read=../docs/ai-quality-calibration.md --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts supabase/functions/ai-generate-quiz/quality_test.ts supabase/functions/ai-generate-quiz/structural_test.ts tests/ai_calibration_test.ts
```

Expected zero failures. Missing/changed C1: stop, do not bypass hash. Retain any error and stop
before deployment/live calls. Coverage includes source resolution/Unicode, invalid references,
plan contrasts/dependencies, key/scenario binding, independent simultaneous failures, blind/
audit payload isolation, source alternatives/unresolved outcomes, accepted-duplicate protection,
bounded attempts, callback errors/mutation, bounded traces and resolved-path/Git/permission
checks with mocked filesystem, plus mocked provider success/error capture. No tests write
private artifacts or contact AI. Semantic quality/provider schema compatibility remain unverified.

Future private diagnostic runner (documentation only; no new live trial requested):
backend/tests/ai_quality_trace.ts accepts the existing generation request JSON and process
GEMINI_API_KEY/GEMINI_MODEL. No Supabase token/DB/deployment required. Owner creates input and
existing folder outside Git; output must be unused and outside the workspace, with no Git
ancestor. Resolved parent/symlinks and createNew checked before paid work. File0600 requested
where supported; Windows ACLs remain owner controlled.500events/4MiB captured with truncation
count; sanitized errors/attempt history saved. No headers/credentials/whole source dumps.
HTTP400 structured error.message is now retained only as a private provider_error event
(at most2048 characters after redaction). Exact supplied key, URL-encoded key, URLs and
common Bearer/Google-key/JWT patterns are masked. No headers, raw body or error.details
retained; source excerpts/unrecognized sensitive text may still appear in the message,
so keep the trace private. Hosted handlers supply no observer; public errors/logs unchanged.
The previous failed trace cannot be recovered retroactively. This does not fix the
unidentified provider rejection or authorize another live call. One mocked regression
covers redaction, bounds, unchanged public error/logs, observer failure and no retry.
Selected lesson/question content is private: keep outside Git; do not share full traces publicly.
Hosted handlers install no observer; this cannot recover past hosted rejected questions or
verify remote auth/model/config parity. No trace/request/temp files created by implementation.

```powershell
deno run --allow-read --allow-write='C:\Users\Dell\Downloads\FiloQualityPrivate\q4-trace-01.json' --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --input 'C:\Users\Dell\Downloads\FiloQualityPrivate\request.json' --trace 'C:\Users\Dell\Downloads\FiloQualityPrivate\q4-trace-01.json'
```

This optional command makes real AI calls; do not execute before the separate owner live
trial decision. No automatic provider retries; one audit per request inside existing slot/
call/deadline bounds. Local command prints counts/status only. Source/audit checks are still
fallible model assessments and lexical coverage, not proof of semantic validity or auto-grading.
Full current contracts are in local docs/ai-prompts.md. Five-file/photo evaluation remains open.

Q4 nested-schema compatibility adjustment: nested plan array maxima are enforced in
parsePlan rather than sent as maxItems in planSchema. Outer batch counts and all existing
parser/semantic limits remain. New mocked boundary regression NOT RUN. From backend:

```powershell
deno test --filter "provider plan schema simplifies" --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/structural_test.ts
```

Expected1pass/0fail; no API key/network generation. On failure stop, retain output. This
does not establish actual provider acceptance; no new live trial requested at this step.

## Q4.1 JSON-mode compatibility - 2026-10-28

Owner isolation: exact blueprint instructions/source with tiny object schema returned200;
full schema returned400. Schema-dependent rejection confirmed, exact offending feature
unknown. Q4.1 sends JSON mode without provider decoder schema, appends the full output
contract to system instructions, and keeps source/question data separate. Existing local
parsers/validators remain authoritative. No automatic400fallback, extra calls or retries.
Shared modelRequest is used by generation and C1 runner; frozen C1/hash unchanged. Trace
and stats revision Q4.1. Original nested plan bounds restored in full instruction contract;
the unsuccessful Q4 nested-maxItems workaround is superseded. Public output unchanged.

Tests/fixtures updated for all3stages, instruction/data isolation, retained plan bounds,
and C1 request parity. NOT RUN. Owner next runs the four-suite Q4 command above, expected
zero failures; retain any error and stop. No key/realAI/deployment needed. No live command
requested yet. Existing malformed/provider/error/timeout tests still apply. JSON mode
removes constrained-decoder shape guarantees; malformed model output must be rejected by
the same local checks, never silently accepted or repaired beyond existing limits.

Q4.1 rejected-output diagnostics: owner live attempt reached blueprint_shape (one call,
no questions); old trace lacked provider output, so exact reason is unknown. Optional
observer now records successful HTTP status and provider_response metadata: purpose,
finish reason, parse outcome/shape and up to65536characters of redacted non-thought text.
Missing-candidate/block metadata and decoding failures distinguished. No full HTTP envelope,
headers or thought parts retained; no hosted observer/public-log change. Existing collector
caps apply; text may contain private lesson/questions, keep outside Git. This does not
recover the old response or change parsing/validation/repair/call budgets. One new mocked
regression covers object wrapper, incomplete response, malformed JSON, truncation,
credential/thought exclusion, blocked/invalid envelopes and one call per attempt. NOT RUN.

```powershell
deno test --filter "private traces preserve rejected blueprint" --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/structural_test.ts
```

Expected1pass/0fail, no realAI. Stop on failure; no paid rerun requested in this step.

## Q4.2 shallow transport envelope/planner separation - 2026-10-28

Current provider wire: shallow schema for outer object containing only items array; strict
modelItems unwrap before pipeline. Full nested contracts remain in system instructions and
local validators. This supersedes Q4.1 schema-free mode. No raw brace/prefix repair. Planner
gets shared source/cognitive rules plus planning-only instructions; question rules reserved
for construction. Mixed question fields rejected in blueprint. Stats/traces Q4.2.
Fixtures/C1 transport updated; frozen reference unchanged. New maintained regressions cover
extra-brace rejection/no retry, exact envelope decoding and mixed-stage rejection. Existing
provider/quality/trace/privacy/budget checks apply. NOT RUN; run the four-suite command above.
Expected zero failures; stop/send any failure, no AI key/real call required. No live rerun
requested until this check. Provider acceptance and field-level/semantic quality unverified.
Keep old private trace; there is no Supabase log for a direct local Gemini call. No disposable
files created; maintained tests retained. Original five-file/photo evaluation remains open.

## Q4.3 encoded-item transport - 2026-10-28

Owner Q4.2 live trace returned only one type field, not a usable blueprint. Q4.3 wire schema
uses items array of JSON-encoded strings, replacing shallow object items. Shared modelItems
decodes objects without dropping positions/fields; invalid inner JSON/non-objects become
null and fail stage validation. Old object-item wire/extra outer keys/non-string items
rejected. Full decoded-array contract/local checks and all stage/call/time budgets remain.
C1/fixtures aligned, frozen reference unchanged. No calls/retries added. Stats/private
traces Q4.3; invalid_items metadata distinguishes bad inner JSON. Token escaping may add
cost; no savings/quality claim. Tests updated for nested/escaped roundtrip, positional
failure preservation, envelope rejection, three-stage/C1 parity. NOT RUN; owner runs
four-suite command above, expected zero failures. No paid rerun requested at this step.
Keep all historical failed traces private; no disposable files created.


## Q4.4 flat typed AI transport - 2026-10-28

Internal provider contract replaces JSON-encoded items with flat typed records. Shared
wire.ts reconstructs existing planning/question/review/audit records; production and C1
use the same boundary. Local field/index/array checks preserve rejected positions and
all downstream source/semantic checks. Public JSON and call/retry/time budgets unchanged.
Maintained wire_test.ts covers primitive schema shape, Easy/Medium/Hard reconstruction,
malformed/legacy records, invalid indices, question variants, aligned arrays, review and
audit mapping. Fixtures and caller assertions updated. Implementation NOT RUN; provider
compatibility and live quality pending. No new private files or disposable scripts.

Owner offline command (from backend; no Gemini key or instructor token required):

```powershell
deno test --allow-read=../docs/ai-quality-calibration.md --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts supabase/functions/ai-generate-quiz/quality_test.ts supabase/functions/ai-generate-quiz/structural_test.ts supabase/functions/ai-generate-quiz/wire_test.ts tests/ai_calibration_test.ts
```

Expected zero failures, including mocked provider/offline/error and bounded-retry cases.
Stop on failures; supply the error without credentials/private source. No live rerun or
deployment requested yet; passing mocks do not establish provider/schema compatibility.


## Q4.4 owner offline checks passed - 2026-10-28

Owner supplied `ok | 72 passed | 0 failed (807ms)` following the five-suite offline
command. Evidence source: owner PowerShell result in chat; local Q4.4 working tree,
exact commit/Deno version not supplied. Scoped result: offline regression PASS;
not real-provider/schema compatibility, deployed runtime or manual question quality.
No assistant execution or repeat offline run needed. Explicit whole-task acceptance
not supplied. Historical Q4.3 live failure and prior accepted scores remain unchanged.
Next diagnostic is one owner-run local Medium trial using the existing private request
and approved model/key; keep a new private trace, stop on failure and do not manually
repeat or raise retry limits. This uses real paid AI calls within existing budgets.
No deployment or instructor access token is needed for the direct local script.
Original five-file/photo evaluation remains incomplete. No disposable files created.


## Q4.4 owner live Medium timeout - 2026-10-28

Owner reported AI_TIMEOUT, returned0/missing11, calls2/retries0, blueprint_invalid4,
blueprint_duplicate1, no verifier disagreements/audits/difficulty judgments. Trial failed;
no quality score. Prior72PASS offline result remains scoped, not contradicted as offline
coverage and not promoted to live success. No explicit whole-task acceptance.

Read-only inspection of the existing private trace confirms blueprint HTTP200/STOP,
15524 characters, not truncated,13 parsed records and zero wire-invalid items. Eight
plans accepted before spare handling, four rejected, one duplicate. Rejected slots0,1,9,10
quote facts present in the original lesson but not fully contained in their selected
source spans: two cross an adjacent-span boundary; two cite the preceding span instead
of the containing span. This is confirmed source-reference mismatch, not evidence that
the underlying lesson facts are invented. The deterministic evidence gate correctly
withheld these plans; it must not silently rewrite references or weaken grounding.

The second invocation is question generation in the current sequential flow. No second
provider response/status appears; execution ended AI_TIMEOUT. Code caps each call at45s
and overall local run at110s. Exact elapsed per-stage time, whether the call cap or
remaining overall budget fired, and provider-side cause are not established by this
trace. Verifier never ran; zero difficulty mismatches do not mean Medium quality passed.

Next engineering focus: sentence-aligned/stable source units with explicit supporting
rule references, plus bounded stage timing and generation-payload inspection (currently
repeats application plans). Avoid increasing retry/time limits or another wording-only
rerun. Any payload optimization must retain candidate-to-plan binding, repairs and
source validation. No code change or new paid diagnostic in this evidence step.
Original five-file/photo evaluation remains incomplete. Assistant ran no tests/static
analysis/build/API/deployment; no disposable/private content copied into repository.


## Q4.5 sentence-aware grounding and retained-plan rendering - 2026-10-28

Local implementation NOT RUN. Supersedes Q4.4 generation wire behavior; preserves the
Q4.4 live timeout/citation failures and scoped owner72PASS offline evidence. No new
quality score or whole-task acceptance. Original five-file/photo evaluation remains open.

sourceSpans now packs complete sentences at boundaries within the existing400 UTF-16
unit cap. It uses explicit English-locale Intl.Segmenter sentence segmentation on the
existing normalized text; language/abbreviation detection is heuristic, not a guarantee.
Unusually long sentences retain bounded word/Unicode-safe fallback. IDs/offsets are
code-assigned and deterministic for the same input/runtime, not stable across revisions;
keep historical traces unchanged and never resolve old citations against new chunking.
Ordered adjacent same-file reference rules/evidence caps and exact quoted-fact checks
remain. Wrong preceding-span citations still fail; no automatic reference relocation.

Initial generation omits repeated application fields from its response. Code reuses the
validated plan by exact objective_id, then runs the same plan/source/key/scenario and
question checks. Generation input omits each objective's duplicate evidence text while
retaining source spans, rules and plans. Stem-only/options-only repairs retain plans;
repairs requiring scenario changes or a full rebuild return the full flat plan. Mixed
batches enforce this per objective ID, rejecting unknown IDs, unsolicited replacements
and missing repair plans. Existing options/stem-only merge protections are retained.
An unsolicited plan during an options-only repair is rejected rather than quietly used;
it can consume the existing retry budget. Fixtures/tests now model compact responses.

provider_timing emits only fixed-purpose/numeric/status metadata: elapsed_ms,
request_bytes (serialized UTF-8 request), response_bytes (decoded successful response
body re-encoded as UTF-8; null when unavailable/incomplete), HTTP status, remaining_ms,
limit_ms, outcome and timeout_scope. Scope identifies the enforced overall-deadline or
45-second call limit, not the provider's root cause. response_received means transport
completed, not that output passed quality checks. Timing excludes verifier reasoning;
it includes the local request serialization and response processing for that call.
Metadata is logged normally and copied to the optional private observer; no source,
question text, headers or key included. Existing private raw capture remains private.

Public response, blind input isolation, model choice and all call/retry/time budgets
are unchanged. No additional AI calls/dependencies/endpoints/database changes. Smaller
requests/responses are intended to reduce repeated text; latency/cost improvement is
unmeasured and no timeout cure is claimed. Frozen C1 reference remains unchanged.

Maintained tests cover sentence packing/long multilingual Unicode fallback, wrong
citations despite a real source fact, code-owned initial plans/unsolicited replacement,
mixed retained/full-repair decoding, and timing on success/provider/offline/expired
deadline. Existing repair/fixture expectations updated. No assistant tests/static
analysis/build/live API/deployment. Owner runs the existing five-suite offline command;
expected zero failures, stop and report any failure. No paid rerun until reviewed.
No disposable materials created or private content copied into repository.


## Q4.5 owner offline failure and focused test-fixture correction - 2026-10-28

Owner supplied75PASS/2FAIL in1s: retained initial-plan replacement and options-only
replacement regressions in structural_test.ts. This is a failed Q4.5 offline run;
not acceptance. Exact assertion stacks were not supplied. Source inspection identifies
an interfering fixture path: plan_invalid activates a same-type spare whose fact changes,
while the single-MC synthetic fixture still renders SELECT; the objective alignment gate
can correctly reject that mismatched question. These two regressions were intended to
check plan replacement/repair, not spare-topic generation.

Both cases now restrict their synthetic blueprint to one objective, retain the attack,
and assert no spare substitution. Initial case checks a required full-plan repair and
original correct answer after rejection; options-only case checks second-attempt
plan_invalid, bounded third render, original stem/key. Dedicated spare-objective tests
remain. No production code, validator, retry limit, reference or provider contract changed.
Tests NOT RUN by assistant; owner should rerun structural_test.ts only first, preserving
the other75 scoped results. No live trial/deployment/new private/disposable materials.
Full error details are needed if a case still fails. Whole-task/live/five-file/photo
acceptance remains pending; earlier failures preserved.


## Q4.5 owner structural correction checks PASS - 2026-10-28

Owner supplied21PASS/0FAIL(117ms) after the focused structural_test.ts rerun. This
supersedes the two failing test-case outcomes after their fixture-only correction,
without deleting the earlier75PASS/2FAIL run. Other reported offline passes retained
within scope; no combined77PASS runtime result invented. Local Q4.5, exact commit/Deno
version not supplied. Production code unchanged since prior run. No full-suite repeat
needed on this evidence. Explicit whole-task acceptance not supplied.

Next check is one owner-run local Q4.5 Medium trace using the same authorized input and
approved model/key, with a new private filename. This is a paid provider trial within
existing budgets. Inspect status, counts and provider_timing; returned questions still
need source/difficulty review. Stop on failure, preserve old traces and do not manually
repeat/increase limits/deploy. No assistant tests/API/static checks/build/deployment or
disposable materials. Live quality and original five-file/photo evaluation remain open.


## Q4.5 live Medium failed at per-call generation limit - 2026-10-28

Owner result AI_TIMEOUT,0returned/11missing,calls2/retries0,blueprint_invalid5;
no verifier disagreements/audits or difficulty judgments. Timings measured in this run:
blueprint11142ms/request16191bytes/response13654bytes/HTTP200; generation45003ms/
request27358bytes/no captured status or response body; remaining overall53835ms.
Configured45-second call limit fired, not overall110-second deadline. Provider root
cause remains unknown; timing includes local serialization/processing, not pure model
latency. No new quality score, live acceptance or latency-improvement claim.

Read-only saved trace inspection: blueprint STOP/parsed object,13records,zero wire-
invalid items,11955 text characters. Eight plans accepted; five rejected. Four rejected
records declare Easy with zero application steps despite requested Medium. Current wire
blueprint difficulty enum allows all3labels while downstream validation correctly
requires the requested one. This is a confirmed overly broad provider contract; retain
that requested difficulty constraint at the boundary rather than relabel bad plans.
The fifth rejected record declares Medium and passed wire shape; its precise downstream
rejection cause is unresolved. All five quoted fact strings occur in the full source;
this alone does not prove their selected references support them. One MC spare used;
not enough valid same-type plans remained for all requested types. No verifier ran;
zero difficulty_mismatches is not Medium quality evidence.

Next proposal, not implemented: preserve requested difficulty enum/code-owned slot
constraints and finer deterministic blueprint rejection reasons; design bounded smaller
generation batches within existing total action/call/time budgets, without silently
adding calls or claiming lower cost. Batch size benefit is a hypothesis, not measured.
Do not increase deadlines/retries or run another identical paid trial. Keep all traces
private. Prior offline passes/failures retain scope; original five-file/photo and whole-
task acceptance remain open. No code changes/assistant tests/static checks/build/API/
deployment/disposable materials or private source/question content copied in this step.


## Q4.6 constrained blueprint and bounded generation batches - 2026-10-28

Local implementation, NOT RUN. The Q4.5 live per-call timeout and earlier scoped offline
results remain historical evidence; no Q4.6 runtime/quality acceptance or score inferred.
Original five-file/photo evaluation and explicit whole-task acceptance remain pending.

The blueprint provider schema now preserves the internal requested difficulty enum and
active question-type enum instead of broadening them to all values. Local wire validation
still rejects violations; downstream validation still checks requested type order and
difficulty. Nothing relabels Easy plans as Medium. Unknown source/plan content remains
untrusted. Frozen C1 reference and shared verifier/audit contracts unchanged.

checkBlueprint keeps existing acceptance conditions and returns fixed rejection reasons:
item shape/extra fields, type, difficulty, objective/fact bounds, invalid source refs,
unsupported full-source fact, fact absent from selected refs, invalid plan/step count,
TF outcome and identification-answer bounds. blueprint_invalid aggregate remains; specific
rule counts can overlap on one item. Duplicate plans also produce a private rejection
event. Null items already rejected by the wire report item shape; their original values
remain available only in the existing bounded private provider capture, not ordinary logs.
No generated text is introduced into ordinary logging or the QA register.

Generation now uses serial batches of at most4 pending slots per round. Each batch is
constructed, checked and blindly verified before the next starts; duplicate/set checks
still compare against accepted earlier batches. Repairs/spares keep their existing slot
action counts. Before starting a batch the pipeline reserves capacity for generation and
verification under the unchanged13-call total and checks the existing remaining-time
guard. No unverified generation consumes a lone remaining call. Time/action/call exhaustion
leaves accurate missing counts and retains only work already verified through the normal
return path. Existing provider exceptions (including AI_TIMEOUT) still abort with the
existing error; no new partial-success fallback hides provider failure.

For an otherwise valid11-question run this is planned1blueprint+3generation+3verification
calls=7 before repairs/audit, versus the prior3 base calls.20questions need5batches/11base
calls. Total limit13, rounds/slot action limit3, one source audit,45-second per-call and
110-second local overall deadline remain unchanged. Batching spends more base calls and
repeats instructions/source, so cost may increase and fewer repairs may fit. Smaller
outputs may help timeouts but latency/cost/provider benefit is unmeasured. Existing
provider_timing plus private generation_batch events identify progress without changing
public questions/dropped_by_type/missing_by_type or introducing endpoints/DB/dependencies.

Maintained synthetic tests cover enum preservation/no relabel, distinct rejection reasons,
nine-question4/4/1 batch order, verification before the next render,13-call shared budget,
no unverified final generation and no late batch with verified work retained. Existing
four-question/single-slot tests keep their small-run behavior. No assistant tests/static
analysis/build/API/deployment. Owner runs the five-suite offline command, expecting zero
failures; stop and share full assertion details on failure. No paid trial until reviewed.
No disposable files created; prior private traces remain outside Git unchanged.


## Q4.6 owner type-check failure; narrowing correction - 2026-10-28

Owner five-suite command stopped before execution with two TS2345 errors at Objective
construction: value.objective and value.fact remained unknown after helper extraction.
No tests ran/passed in this attempt. Added explicit existing validText guards at the
construction boundary so TypeScript narrows both strings; helper rejection semantics,
provider/batch/budget/public behavior unchanged. No unchecked casts or --no-check bypass.
Assistant did not run tests/static checks/build/API; correction awaits owner rerun of the
same checked five-suite command. Historical results retained; live quality/five-file/photo
and whole-task acceptance remain pending. No disposable files created.


## Q4.6 owner offline82PASS - 2026-10-28

Owner supplied82PASS/0FAIL820ms after the checked five-suite rerun. Evidence: owner
console in chat, local Q4.6 working tree; exact commit/Deno version not supplied. Scoped
offline regression PASS; earlier TS2345 failure preserved and superseded for this run.
No repeat offline suite needed or live/provider/quality acceptance inferred. Explicit
whole-task acceptance absent; original five-file/photo evaluation remains incomplete.
Next check: one owner-run paid local Medium trial with existing authorized request,
approved model/key and new private q46 trace, within current budgets. Capture timing,
quality_stats and actual returned/missing counts; stop on failure, no automatic/manual
rerun or limit increase/deployment. Returned questions still require manual source and
difficulty review. No assistant tests/static checks/build/API/code/deployment/disposable
materials or private content created in this evidence step.


## Q4.6 live failed: adapter/type-contract defects exposed - 2026-10-28

Owner result AI_BAD_OUTPUT,0returned/11missing,calls13/retries18,call_budget1; no source
audits. Retries18 counts slot retries, not18extra provider calls. All13captured provider
calls HTTP200; no timeouts in this run. Generation call elapsed times3822..8458ms;
blueprint11660ms; remaining overall24579ms at last call. These are single-run local
call timings, not a general latency/success-rate claim. Total call budget correctly
stopped execution. Prior offline82PASS retained within mocked scope, not live acceptance.

Read-only private trace: blueprint13decoded/zero wire-invalid items,one rejected essay
plan because exact fact is absent from selected refs (blueprint_fact_refs). All18MC
attempt records (6slots x3attempts) rejected by local wire decoding: missing distractor
categories/misconceptions/reasons, with unrelated essay fields also present. Typed array
items declare type-specific fields optional at provider level although decoder requires
MC metadata and forbids cross-type fields. Plan reconstruction never happened for those
rows; candidate loop then reports plan_invalid for missing decoded candidates. This
misclassification triggers plan rebuilds rather than a targeted response-shape repair.
It does not establish18semantically bad application plans or18wrong MC answers.

All3TF blind reviews of one slot emit2option judgments, although non-MC review contract
requires none; this causes verifier_malformed alongside recall/zero-inference/no-condition
judgments. Two ID reviews also report recall/zero inference despite the Medium request.
Scenario omission and unsupported absolute checks also fire. Verifier difficulty remains
an assessment requiring calibration/review, not proof the generator is incorrect. No MC
question was independently verified. No final question quality score is available.

Next proposal, not implemented: homogeneous question-type generation/review contracts
with required applicable fields and no unrelated fields; distinct wire-shape vs genuine
plan failures; synthetic regressions matching the observed key/array shapes. Review
homogeneous batching's base-call cost under13total before changing it. Keep source/key/
difficulty checks and limits; do not infer missing metadata or accept malformed rows.
No identical paid rerun/limit increase/deployment. No code changes or assistant tests/
static checks/build/API/disposable files. Private trace kept outsideGit; no private text
copied into repo. Live acceptance/whole-task and original five-file/photo remain open.


## Q4.7 type-specific generation/review contracts - 2026-10-28

Local implementation NOT RUN. Preserves Q4.6 live failure, earlier82PASS mocked scope,
and original five-file/photo/whole-task gaps. No quality score/runtime acceptance.

Generation batches now group by question type, at most4slots each. The provider schema
uses that type's exact enum and declares only applicable answer fields, all required.
MC requires correct_answer and all4aligned distractor arrays; essay fields cannot appear
in an MC schema. TF/ID/essay have their own required keys. Local decoder also binds type
to objective ID and retains all strict array/value/source/plan/quality checks. No absent
metadata is inferred and no unrelated field is silently accepted. Legacy mixed internal
schema inspection remains supported; production generation uses homogeneous batches.

Homogeneous non-MC blind-review/source-audit internal schemas specify zero option
reviews. Their provider contracts omit option judgment arrays entirely; the adapter
reconstructs the empty internal list because these checks are inapplicable. It does not
invent answer, cognitive level, inference count, conditions or support. Unexpected option
fields are rejected. MC still requires all option judgments. Mixed C1 calibration keeps
its existing per-record option-array contract in the same adapter and frozen reference;
no new calibration call/reference edit. Blind key/source isolation remains unchanged.

Missing/undecodable/duplicate candidate rows now report candidate_wire instead of
plan_invalid. Formatting/shape-only failures request format repair using the validated
plan, without selecting a spare. Genuine invalid plans still fail as before. A malformed
repair cannot erase earlier unresolved semantic findings; private candidate trace marks
carried_findings separately. Aggregate failure occurrences may include carried findings,
not additional verifier judgments; difficulty_mismatches counts actual review results.
No output key flip or acceptance is inferred from solver agreement/disagreement.

The11-question6MC/2TF/2ID/1essay mix uses5typed batches, thus11base calls before repairs/
audit (Q4.6 planned7); a four-type4-question fixture uses9. The13-call/3-slot-action/one-
audit/45-second-call/110-second-local-total limits and generation+verification reservation
remain. Homogeneous batching can increase cost and leave less repair capacity. Larger
mixed requests may exhaust the unchanged budget and return accurate missing counts on
the normal return path; existing provider exceptions remain errors. No completion/latency
or cost improvement is claimed. Public response/endpoints/DB/dependencies unchanged.

Maintained synthetic regressions reproduce missing MC metadata/unrelated essay keys and
TF two-option judgments; assert required provider fields, non-MC omission/reconstruction,
wire-error classification/format-only retry/no spare and preservation of known difficulty
findings. Existing generation order/count/audit fixtures updated for typed batches;
C1 reference unchanged. No assistant tests/static checks/build/API/deployment. Owner runs
the checked five-suite command expecting0failures, supplies full errors on failure; no
paid rerun/deployment until reviewed. No disposable or private materials created/copied.


## Q4.7 owner offline86PASS - 2026-10-28

Owner supplied86PASS/0FAIL1s following the checked five-suite command. Local Q4.7 working
tree, exact commit/Deno version not supplied; evidence owner console in chat. Scoped
offline regression PASS, no repeat suite needed. No live completion/schema/quality or
whole-task acceptance inferred; original five-file/photo evaluation remains incomplete.
Next one owner-run paid local Medium trial with approved model/key, same authorized
request and a new private q47 trace. Capture actual counts/timing/quality_stats; stop
on error and preserve trace, no manual repeat/limit increase/deployment. Returned output
still requires source and difficulty review. No assistant tests/static checks/build/API/
code/deployment/disposable files or private content created in this evidence step.


## Q4.7 live PARTIAL2/11; literal binding and task leakage diagnosed - 2026-10-28

Owner result status=completed but2returned MC/9missing:4MC,2TF,2ID,1essay. This is partial
pipeline completion, not task success or question-quality score. Calls12/slot-retries7,
no timeout, source audits0; call_budget1 correctly reserves2calls and refuses a new batch
with only1call left. Remaining overall29295ms at final response. All provider responses
in saved trace parsed with zero wire-invalid items, unlike Q4.6. Two MC slots passed
current deterministic/blind checks with interpretation judgments; manual source/quality
and explicit owner acceptance remain pending. No general success/latency claim.

Blueprint rejected one MC and one TF plan for fact/ref mismatch; no matching spare filled
those slots. Candidate failures: scenario_missing9,plan_answer_mismatch5; actual blind
reviews rejected3MC as recall/application mismatch. These counts are observations, not
proof of9absent scenarios or5incorrect answers. Source inspection and read-only private
artifact comparison show applicationRules requires exact normalized fact substrings and
exact normalized answer/sample equality. Some scenario checks fire on sentence joining/
paraphrase or inclusion of procedural task descriptions as facts. Several answer checks
fire on paraphrases or expanded essay wording, not established contradictions. Validators
are too literal to equate these findings with factual errors; they still must prevent
lost/changed conditions and contradictory keys.

A separate genuine construction defect is visible: ID stems copy a planner goal containing
because plus the rule/answer, revealing what learners should infer. planningInstructions
currently asks scenario_goal to include Given/decide/because; copying that goal into a
student stem carries private justification into the question. No ID was accepted/verified
in this run. Do not fix this by accepting decorative scenario prefixes as Medium.

Next proposal, not implemented: student-facing task separate from private rule/proof;
code-owned assembly of validated conditions plus the learner task; a single canonical
plan/key representation instead of requiring independent prose copies to match. Preserve
independent blind/source/ambiguity/difficulty checks and reject changed/omitted conditions
or contradictory answers. Semantic consistency/rubric handling must be designed explicitly;
no blanket similarity threshold or automatic answer flip. Add synthetic regressions for
joined sentences, answer paraphrase vs contradiction, task/meta facts and answer leakage.
No identical paid rerun/limit increase/deployment. Offline86PASS remains scoped. Original
five-file/photo/whole-task acceptance open. No code changes/assistant tests/static checks/
build/API/disposable materials or private source/question bodies copied into repository.


## Q4.8 canonical scenario/task/key rendering - 2026-10-28

Local implementation NOT RUN. Q4.7 partial2/11, offline86PASS and historical failures
retain their recorded scopes; no new quality score/runtime acceptance. Original five-
file/photo evaluation and explicit whole-task acceptance remain incomplete.

The existing scenario_goal now means the short student-facing task only. Planner
instructions no longer request Given/decide/because in that task; source rule/private
justification remain in fact, steps and expected_outcome. scenario_facts must be actual
conditions, not procedural task descriptions. renderPlan composes only the facts used
by steps plus the task, normalizes whitespace and enforces the existing1000-character
prompt cap. Unused meta facts/private proof are not concatenated. A because-clause in
the learner goal violates this contract (blueprint_task_justification/blueprint_render,
or plan_render during repair); this English syntax guard is not a universal semantic
leak detector. Causal premises belong in conditions; private reasoning never belongs
in the task. Meaningful-condition selection still needs independent review.

Canonical production generation schemas omit prompt/correct_answer/correct_boolean/
accepted_answers/sample_answer entirely. The model returns identity, points, explanation,
MC distractor metadata, essay rubric, and a full plan only when a plan repair is needed.
Wire/direct construction rejects unsolicited duplicate prompts or keys, including
paraphrases and contradictions, rather than overwriting them. Code renders one prompt
and uses the plan expected_outcome as MC key, parsed TF boolean, initial ID answer or
essay sample. Existing source-based answerVariants supplies ID acronym/full-name variants.
Legacy candidateSchema inspection/direct parser tests remain supported by default;
production opts into canonical rendering explicitly. No public response fields changed.

Exact application/source/count/rubric/spacing/duplicate/option/key checks remain: the
false-positive duplication is removed at construction, not by fuzzy acceptance. The
canonical plan can still be wrong or reveal an answer. Blind solving sees the final
rendered question/options without keys or proof and still checks ambiguity, actual
inference demand and distractors. answer_leaked now fails even Easy; it requires a plan
repair within existing limits. Appending conditions never automatically establishes
Medium. Source-audit disagreement handling/no automatic key flip remain unchanged.
Essay canonical samples/rubrics still require instructor review; existing independent
essay agreement is lexical rubric coverage, not a proof of semantic correctness.

Stem ambiguity repairs now require a full task/plan revision instead of asking for a
second independent stem. Options-only repairs retain the code-owned stem/plan/key.
Code-owned values in a saved previous candidate are trusted local data; untrusted model
replacement fields are rejected before merging. No new endpoints/dependencies/DB/API
calls. Same13-call/3-action/one-audit/45-second-call/110-second-local-total limits;11target
questions still plan11base typed calls before repairs. Output repetition is reduced,
but latency/cost/real-provider compatibility and quality improvement are unmeasured.

Maintained synthetic tests cover canonical per-type wire omissions/replacement rejection,
used vs unused conditions/private proof, ID variants, boolean/render limits, task-rule
leakage and independent Easy leakage rejection. Existing fixtures now emit only permitted
metadata; Medium task-change tests revise the plan/task rather than invent another stem.
Source/answer validators and C1 frozen reference unchanged. No assistant tests/static
checks/build/API/deployment. Owner runs the checked five-suite command expecting0failures;
stop and share full errors. Hold paid trials/deployment until reviewed. No disposable or
private materials created/copied; historical private traces remain untouched outsideGit.
Q4.8 malformed-repair regression also asserts retained cognitive level/direction until
a new candidate is parsed. Assistant has not run the suite.

## Q4.8 owner-reported offline regression result - 2026-10-28
Owner supplied terminal summary: `ok | 90 passed | 0 failed (1s)` following
request for the five-suite Deno command. Recorded as owner-reported local offline
regression PASS for Q4.8; exact commit and runtime version not supplied. Evidence:
owner chat, not assistant execution. No repeat suite required without new changes.
This does not establish live provider compatibility, complete Medium generation,
question quality, hosted deployment or explicit owner acceptance. Next: one local
Medium trial with a new private q48 trace; preserve errors/partial results and stop
on failure. Historical failures remain; original five-file evaluation/photo still
incomplete. No secrets or private question/source content recorded.

## Q4.9 deadline scheduling and verified partial recovery - 2026-10-28
Implemented, NOT RUN. Q4.8 live timeout remains a failure; owner90PASS applies
only to the older offline revision. Public JSON/types and13-call/3-action/
one-source-audit/45s-call/110s-local-total limits unchanged. No new AI calls.
Pipeline admits a generation/verification pair only if the remaining time covers
both estimates, and checks again before verification. Estimates use the maximum
observed duration per stage in this request, with a5s floor; these are scheduling
heuristics, not guaranteed latency or a promise that all requested items fit.
Private schedule_deferred records required/remaining milliseconds; time_budget
is counted in existing quality stats. Source disputes are queued/withheld until
first-pass active-slot coverage, then one optional audit shares existing budgets.
Unresolved/unaudited disputes never become accepted and cannot silently reroll.
A later AI_TIMEOUT with accepted work proceeds through existing final set checks,
position balancing and exact missing/dropped counts. Only previously verified
items may survive. timeout_partial is logged/traced. No verified work means the
timeout still propagates; non-timeout errors still propagate. A final set check
can remove an earlier accepted item; no empty-result success is promised.
Maintained regressions cover pair admission, observed slow verification,
post-generation verification reserve, deferred audit order, late timeout partial
counts, no-accepted timeout, and non-timeout propagation. No assistant tests,
static checks, builds, API calls or deployment. Owner must run the five-suite
command before any paid trial. Medium application/source/answer quality is still
unresolved; this scheduling fix does not establish question quality. Original
five-file evaluation/photo and explicit runtime acceptance remain incomplete.
No temporary/private materials created; prior private traces left unchanged.

## Q4.9 owner offline failure and test-deadline correction - 2026-10-28
Owner chat reports95PASS/2FAIL/3s for the five-suite run. Failing cases:
verified provider failures still fail closed without emitting an unverified quiz;
provider uses typed batches and preserves full contracts across all stages.
Source inspection identifies both used Date.now()+10000 for the entire request,
while Q4.9 requires at least10000ms remaining for generation plus verification.
Blueprint processing consumes part of that allowance, so these non-deadline tests
stop before the intended verifier429/all-stage assertions. Their synthetic request
deadlines now use110000ms; no sleeps or actual provider waits added. Provider429
case additionally asserts exactly3calls to prove it reached verification. Existing
response shape, complete counts, all9stages, wire contracts and AI_BUSY assertions
retained; dedicated short-deadline/timeout tests unchanged. Production scheduling,
validation, time/retry/call limits unchanged. No assistant test/static check/build/
API/deployment. Correction NOT RUN; owner reruns the two affected files first.
No runtime/full-task acceptance; original five-file evaluation remains incomplete.
No secrets, private content or disposable materials created. Historical95/2failure
and earlier scoped results preserved; no new pass claimed.

## Q4.9 corrected test files: owner-reported offline pass - 2026-10-28
Owner supplied `ok | 48 passed | 0 failed (2s)` following the requested
quality_test.ts + quiz_test.ts command. Both previously failing cases are covered
by these files; correction accepted as scoped offline evidence, not explicit
owner runtime/task acceptance. Exact commit/Deno version not supplied. Retain the
prior five-suite95PASS/2FAIL result and passing unchanged-suite evidence in its
original scope; do not claim a new simultaneous97-test run. Only test deadlines
and a provider call-count assertion changed after that run. No repeat offline
suite required without new changes/concerns. Next: one owner-run local Q4.9 Medium
trial with fresh private q49 trace; target11returned/zero missing, review final
question quality separately. Partial completed output is not full completion.
Preserve timing/stats/trace and stop on errors or partial output; no automatic
retry or deployment. No assistant tests/static checks/build/API/deployment. Live
Q4.9 completion, Medium source/quality review, hosted behavior, explicit acceptance
and original five-file/photo evaluation remain pending. No private content or
credentials recorded; no disposable materials created.

## Q4.9 owner live attempt: provider503 before blueprint - 2026-10-28
Owner terminal evidence: local Q4.9/Medium, first blueprint call HTTP503 after
1254ms,108730ms remaining; statusAI_BUSY, returned0/11, all requested counts
missing, trace_saved true/dropped_events0. One call/zero retries/verifier
checks/source audits; no validator failures logged. Exact commit/model/trace
filename not supplied with this result. Source inspection confirms HTTP503 maps
to AI_BUSY. Underlying provider cause/recovery time unknown; do not infer model
quality, a new schema defect, key failure or successful Q4.9 scheduling from this
attempt. Classify as provider-blocked attempt, not a scored question set. Keep
private trace and earlier failures; owner48PASS corrected files and unchanged
suite evidence remain scoped. No implementation change warranted by this log.
Owner may manually retry once later using a new private trace, preserving this
attempt; stop on repeated503, any error or partial output. No automatic retry,
limit increase, model change or deployment. No assistant tests/static checks/API/
build/deployment; no private content/credentials/disposable files recorded.
Live Q4.9/Medium quality, explicit acceptance and five-file/photo evaluation remain
incomplete.

## Q4.9 owner live retry: partial1/11, deadline admission exercised - 2026-10-28
Owner terminal: completed, returned1MC; missingMC5/TF2/ID2/essay1. Three calls,
zero retries/disagreements/audits. HTTP200 blueprint35769ms, generation19152ms,
verification37263ms; remaining17731ms. Failures blueprint_invalid3 plus
blueprint_fact_refs3, candidate_shape3, time_budget3. Counts are events, not
quality scores or unique-question counts. No timeout/provider503 in this retry.
Read-only private trace q49-medium-retry-20261028-223024.json (73295bytes),
model gemini-3.5-flash-lite, confirms scheduling required56417ms for another pair
with17726ms left; three deferred checks, no extra API calls. Trace contains four
MC candidates, three rejected before blind review. Each rejected construction has
at least one distractor category label differing from the plan's literal category;
parseCandidate requires exact normalized label equality. This establishes a
metadata-contract rejection, not independently that all rejected distractors were
semantically weak or wrong. The surviving MC passed automated review; manual
source/quality acceptance is pending. Blueprint fact-reference mismatches at
slots5/10/12 remain source-citation defects pending detail review. No new score.
Q4.9 admission guard exercised as designed in this run; timeout-partial catch not
exercised. Full11-question generation failed. Proposed next focus: category
metadata contract and granular candidate-shape diagnostics, retaining independent
semantic distractor review; separately investigate citation mismatches and stage
latency. No code changes, tests/static checks/API/build/deployment or automatic
rerun; do not increase budgets or relax source/answer/difficulty checks based on
this run. Owner offline48PASS scope and earlier failures preserved. Whole-task/
five-file/photo and hosted/explicit acceptance remain incomplete. Private source,
questions and credentials remain outside register/Git; no disposable files made.

## Q4.10 category-label contract and parser diagnostics - 2026-10-28
Implemented, NOT RUN. Q4.9 owner partial1/11 and earlier failures are retained;
no live improvement or quality score claimed. Read-only trace inspection found
three MC constructions rejected by literal distractor-category/plan-label equality.
Parser now treats the model's category string as diagnostic metadata: nonempty,
max100characters, exact field structure still required; no literal equality claim
of semantic validity. Independent blind reviewer still evaluates each actual
option's same_category/plausible/defensible judgments. A label cannot establish
category fit, and the public question never receives this diagnostic label.
Prompt/wire instructions clarify that division. No schema/public JSON changes,
new AI calls, dependencies, endpoints or DB changes. Source/evidence, application,
difficulty, answers, ambiguity, duplicate/spacing/rubric checks and all time/call/
retry limits retained. Genuine category defects must still fail semantic review;
the reviewer remains fallible and instructor review is required.
parseCandidate keeps its Question-or-null return and adds an optional internal
findings collector. First failing structural check supplies a fixed field-specific
candidate_* code (identity/prompt/explanation/plan/evidence/points/fields/answer,
distractor count/fields/text/category/misconception/reason/duplicate misconception,
TF boolean, identification answers/variants, essay sample/rubric). Pipeline uses
these codes in existing private traces, repair errors and aggregate quality stats
instead of opaque candidate_shape. Format repair grouping and stale structural
finding removal recognize the candidate_* family; semantic findings remain carried.
No private values appear in the fixed rule codes. Malformed provider wire still
uses candidate_wire; these diagnostics concern the local parsed construction.
Five maintained regression cases added: equivalent/different diagnostic labels
preserve parsed question; table-driven structural reasons; label variation reaches
blind review; matching labels cannot bypass semantic rejection; specific failure
propagates into bounded format repair/stats. Existing label-only null expectation
updated; revision assertion nowQ4.10. Existing synthetic fixture and wire shape
remain applicable. No assistant tests/static checks/build/API/deployment. Owner
runs five-suite offline command first; stop on errors, hold paid trials/deployment.
Original five-file/photo, current Medium/live quality and explicit acceptance are
incomplete. Separate blueprint citation mismatch/provider latency remain open.
No disposable or private files created/copied; earlier private traces untouched.

## Q4.10 owner-reported offline pass - 2026-10-28
Owner supplied terminal summary `ok | 102 passed | 0 failed (5s)` following
requested five-suite Deno command. Record as owner-reported local Q4.10 offline
regression PASS; exact commit/runtime version not supplied. Evidence owner chat,
not assistant execution; no explicit whole-task/runtime acceptance. No repeat
suite needed without new changes/concerns. Next: one owner-run local Medium trial
with fresh private q410 trace; target11returned/zero missing, then separate manual
source/quality review. Preserve errors/partial output and stop without automatic
retry/deployment. Earlier Q4.9 partial1/11, provider503 and historical failures
retained. Citation mismatch/latency/current live behavior and original five-file/
photo evaluation remain incomplete. No tests/static checks/build/API/deployment
performed by assistant; no credentials/private content/disposable files added.

## Q4.10 owner Medium live: partial1/11 after five reviews - 2026-10-28
Owner terminal summary: completed, returned1MC, missingMC5/TF2/ID2/essay1.
Five calls/zero retries/audits; blueprint20267ms, generation16922ms, review21517ms,
generation17944ms, review27050ms, allHTTP200; remaining6149ms. Four verifier
rejections: difficulty3/application4; no key mismatch/ambiguity/distractor/shape
failures logged. Blueprint invalid3: fact_refs2/item_shape1. time_budget3 are
repeated deferred checks, not three provider requests. No new question score.
Read-only private trace q410-medium-20261028-224238.json (92707bytes), model
gemini-3.5-flash-lite: slots1/2/3/4 and then5 reached blind review; slot4 accepted,
slots1/2/3 classified recall/zero inference; slot5 interpretation/one inference
failed condition coverage. All five solver keys agreed; disagreement counter is
not four wrong answers. Manual source/quality acceptance of returnedMC pending.
Source/trace inspection of recalled tasks shows direct category/property/purpose
recognition with scenario text restating or naming the tested concept. Separately,
slot5 review quotes the material scenario condition but omits a generic task/setup
condition that the plan lists as used. Existing coverage requires every used fact;
this establishes a coverage rejection, not independently a wrong answer or too-easy
question. Next work should address application task construction and meaningful
versus decorative condition dependencies, retaining independent answer/source/
distractor checks; do not globally waive missing material conditions. Citation
mismatches remain separate. Deferred next pair estimate44998ms versus6146ms left;
deadline guard exercised, no timeout-partial catch needed. Q4.10 has no logged
candidate-shape failures in this run, but full generation still failed. Latency
and outcome changes versus Q4.9 are uncontrolled; no speed/success-rate claim.
No code/test/static check/build/API/deployment/rerun by assistant. Owner102PASS
remains offline-only; earlier failures preserved. Whole task/five-file/photo,
current live/manual quality and explicit acceptance remain incomplete. Private
source/questions/credentials not copied to register/Git; no disposable files made.

## Q4.11 Medium intent and context/material dependencies - 2026-10-28
Implemented, NOT RUN. Q4.10 partial1/11 and102offlinePASS remain historical scoped
evidence; no new live/pass/quality score. Internal plans now carry task_kind for
Medium (outcome/decision/diagnosis); type restrictions: TFdecision, IDdiagnosis,
MC/essay any of the three. Code renders the corresponding application task rather
than the model's recognition-style scenario_goal. Model must put the complete
conditions, goal/action/change/violation into the scenario. Task templates are
English for the current English lesson trial; source-language task localization
is not implemented/accepted and must be resolved before broader language rollout.
Templates/labels do not prove actual reasoning; blind difficulty/application,
source, answer, leakage, assumptions, ambiguity and distractor checks still gate.
Scene-setting lives in optional scenario.context, max2strings of250characters.
Every Medium scenario.fact is material and must appear in its one inference step;
context cannot be referenced by indices. Rendering includes context and material
conditions, preserving needed information. Solver may omit context from condition
quotes; all material facts still require coverage. Context-only quoted reasoning
is rejected. Role declarations and substring quote matching are fallible; they do
not prove causal necessity or allow hiding a missing premise. Independent solving
and assumptions checks plus instructor review remain necessary. Coverage failures
now log verifier_conditions separately from verifier_application/difficulty and
trigger bounded plan repair; no automatic acceptance or extra source audit.
Provider flat contract adds task_kind and scenario_context; wire decoder reconstructs
internal roles, with empty values omitted at Easy/Hard (which retain existing task
rendering and dependent-step semantics). Fixed-difficulty blueprint enums constrain
intent values. Maintained flat-plan fixtures updated. Public question JSON, optional
evidence/sample/rubric, counts and response shape unchanged. No endpoints/DB/deps,
additional AI stages/calls or budget increases;13calls/3slotactions/oneaudit/45scall/
110slocal total retained. Slight request metadata added; no latency/cost improvement
measured. Blueprint source-reference failures and full11-question completion remain
open. Frozen C1 reference unchanged; no live calibration claimed.
Six new maintained cases cover application intents/type restrictions, context omission
versus missing material coverage, invalid dependencies/bounds, distinct coverage
rejection, positive independent material coverage, and new flat-role roundtrip/rejection.
Existing canonical rendering/Medium repair fixtures and revision assertion updated;
repair examples change scenario conditions instead of a duplicate learner task.
No assistant tests/static checks/build/API/deployment; owner runs five-suite command
and stops on errors before any paid trial. Whole-task/five-file/photo/manual/hosted
and explicit owner acceptance remain incomplete. No private/disposable files created;
prior traces and failures preserved; private content absent from register/Git.

## Q4.11 owner-reported offline pass - 2026-10-28
Owner supplied `ok | 108 passed | 0 failed (2s)` following requested five-suite
Deno command. Record as owner-reported local Q4.11 offline regression PASS; exact
commit/runtime version not supplied. Evidence owner chat, not assistant execution;
no explicit live/whole-task acceptance. No repeat suite needed without new changes
or concerns. Next: one owner-run local Medium trial, same authorized English lesson,
fresh private q411 trace. Target11returned/zero missing, then separate manual
source/quality review. Stop on errors/partial output, preserve all attempts; no
automatic retries or deployment. Earlier Q4.10 partial1/11 and all historical
failures retained. Citation defects, latency, live behavior, English-template
language limitation, original five-file/photo and explicit acceptance remain open.
No assistant tests/static checks/build/API/deployment, private content/credentials
or disposable files created.

## Q4.11 owner Medium live failure: zero accepted after first batch - 2026-10-28
Owner terminal: AI_BAD_OUTPUT, returned0/11/all requested counts missing. Three
HTTP200calls: blueprint27541ms, generation25385ms, verification21036ms; remaining
35973ms. Zero retries/audits, three verifier rejections. Failure events:
blueprint_invalid1/fact_refs1, glued_words1, verifier_difficulty3/application3,
time_budget3. No key mismatch/ambiguity/distractor/condition-role/parser failures
logged. AI_BAD_OUTPUT here follows no accepted questions, not an established JSON
or transport failure. Time deferrals are checks, not additional provider calls.
Read-only private trace q411-medium-20261028-231113.json (75741bytes), model
gemini-3.5-flash-lite: four MC constructions, one rejected before blind review,
three reviewed as recall/zero inference, solver keys agreed. Next pair estimated
46423ms versus35969ms remaining, so scheduler stopped without timeout.
Source/trace inspection identifies an actual deterministic false positive: the
valid English conjunction whereas in an explanation triggers glued_words because
source vocabulary contains where and as but not whereas. This is not demonstrated
spacing loss; do not rewrite its meaning or claim that candidate passed all checks
(it never reached blind review). Two reviewed tasks still return concept names from
definition-like descriptions despite outcome templates. The third is a concrete
rule-violation diagnosis; verifier recall judgment needs instructor calibration
against existing interpretation criteria (which permit diagnosis), not automatic
acceptance of generator or verifier. No evidence of three wrong answers.
Q4.11 templates/roles did not establish useful full generation. No quality score,
manual returned-set acceptance or runtime Pass. Recommended next work: narrow
legitimate-compound/spacing correction with retained genuine glued-word cases;
small frozen instructor-reviewed Medium calibration separating actual name recall
from one-rule diagnosis before further paid trials or difficulty-gate changes.
No implementation/tests/static checks/build/API/deployment or rerun by assistant;
owner108PASS remains scoped offline evidence. Preserve historical failures and
private trace; original five-file/photo/current live/hosted/explicit acceptance
remain incomplete. No private source/questions/credentials copied to register/Git;
only generic findings and the nonprivate conjunction/split recorded. No disposable
files created.

## Q4.12 spacing false-positive correction and proposed B1 review - 2026-10-28
Implemented, NOT RUN. gluedWords now recognizes the legitimate conjunction whereas
in its small grammar vocabulary, preventing a false positive when where/as occur
separately in the source. No dictionary dependency, auto-correction, blanket skip
of unknown words or changed meaning. A maintained regression checks casing and
questionRules integration plus continued rejection of isnot, maintainreferential
and whereasnot. Vocabulary splitting remains a heuristic and may have other false
positives; no general English spelling guarantee. Existing validation, application,
answer, source, difficulty gates, Q4.11 structure and budgets unchanged; revision
Q4.12 logged. No prompt/verifier relaxation, extra AI calls or automatic reruns.
Two new synthetic difficulty boundary cases are proposed in the quality report:
B1-R-ID (name from definition, proposedEasy/DBMS) and B1-D-MC (concrete repeated
key values, proposedMedium/B). Both await owner content/label review; no model
calibration or acceptance claimed. Already accepted C1-M-TF covers applying
uniqueness to concrete rows; do not request repeat acceptance of that control.
C1 document/hash/runner/evidence untouched. B1 is not a student quiz or part of
five-file evaluation; no new runner or approval bypass. Do not use pending cases
as production exemplars or alter the difficulty gate on their basis.
Owner108PASS and Q4.11 live0/11 retained in scope. No assistant tests/static checks/
build/API/deployment. Owner next runs offline suite and reviews only the two B1
proposals; hold paid trials/deployment pending findings. Whole task, current live
quality, citation/latency/language gaps and original five-file/photo remain open.
No private source/question copies, secrets or disposable files created; maintained
report/regression retained, unrelated work unchanged.

## Q4.12 owner-reported targeted offline pass - 2026-10-28
Owner supplied `ok | 29 passed | 0 failed (116ms)` after requested quality_test.ts
command. Scoped owner-reported local regression PASS for Q4.12 spacing correction
and that file's existing checks; exact commit/runtime version not supplied. No
new simultaneous full-suite pass, live success or whole-task acceptance inferred.
Earlier Q4.11 owner108PASS and live0/11 remain separate historical evidence. No
repeat targeted tests required without changes/concerns. B1-R-ID and B1-D-MC
content/answer/difficulty/distractor review remains Pending; no owner label reply
received. Do not interpret test summary as B1 approval. Accepted C1 unchanged.
Next: owner reviews only the two proposed boundary cases before any further paid
trial or difficulty-gate changes. Hold deployment/live reruns. Original five-file/
photo, current live quality, citation/latency/language gaps and explicit acceptance
remain incomplete. No assistant tests/static checks/build/API/deployment; no private
content/credentials/disposable files created.

## B1 human reference accepted; verifier-only runner ready - 2026-10-28
Owner explicitly replied B1-R-ID accept Easy/DBMS; B1-D-MC accept Medium/B,
distractors acceptable. Acceptance applies to both synthetic items' content,
answers and cognitive labels, plus MC distractors; NOT model agreement, runtime
success, generated-set quality or whole-task completion. B1 section in the
[quality report](../../docs/ai-quality-check.md) marked accepted/frozen;
questions/options unchanged. Historical pending notes superseded for B1 reference
only. C1 document/hash/accepted evidence untouched; no repeat C1 human review.
Existing ai_calibration.ts now supports explicit --boundary for B1; default C1
unchanged. Hash-checked B1 section isolates later report additions. Shared blind
request/scorer reused, keys/labels local; answer and difficulty agreement reported
separately. One owner-selected --live call,45s timeout, no automatic retries or
quiz generation/deployment. Changed reference stops before network; fixed/sanitized
errors. Added2maintained mocked regressions: frozen-section integrity/blind payload,
answer-vs-level disagreement/one-call/no-retry/pre-network rejection. NOT RUN.
Owner next runs ai_calibration_test.ts with read permission to both reference docs;
no repeat spacing suite required (owner29PASS preserved). Live B1 not run, no
calibration score or production gate relaxation claimed. No assistant tests/static
checks/build/API/deployment. Original five-file/photo/current live quality,
citation/latency/language gaps and explicit whole-task acceptance remain open.
No private question/source copies, secrets or disposable files created; maintained
runner/tests/report retained; ignored docs/unrelated work unchanged.

### Owner-operated B1 verifier selection

B1 is now owner accepted in docs/ai-quality-check.md. Existing C1 remains default
and frozen. --boundary selects only the two B1 items; neither reference is inserted
into production prompts. First run the maintained offline C1/B1 runner tests:

```powershell
deno test "--allow-read=../docs/ai-quality-calibration.md,../docs/ai-quality-check.md" --config supabase/functions/ai-generate-quiz/deno.json tests/ai_calibration_test.ts
```

Expected zero failures, all HTTP mocked; no provider calls. On failure retain full
errors and stop. Do not repeat prior spacing checks without a new concern. After
owner offline evidence is reviewed, the optional future targeted model comparison
uses --boundary --live and read access to ../docs/ai-quality-check.md, plus existing
private GEMINI_API_KEY/GEMINI_MODEL env/network permissions. It makes one verifier
call, no quiz generation or database access. --boundary --check reads only the
frozen section offline, but that separate check is unnecessary if the runner tests
already passed unchanged. Do not bypass hash mismatch or automatically retry.
B1 expectation is2answer agreements and2level agreements with0false rejects; this
is a target, not a measured result. No B1 negative control is included, so zero
false accepts would not demonstrate broad rejection quality. Stop and retain
per-item findings on mismatch/error. API costs/latency/full quiz quality unmeasured.

## C1/B1 calibration runner owner offline pass - 2026-10-28
Owner supplied `ok | 5 passed | 0 failed (86ms)` following requested
ai_calibration_test.ts command with read access to both reference documents.
Record scoped owner-reported local offline PASS for runner/hash/payload/scoring/
mocked one-call/error behavior, not a measured model result. Exact commit/runtime
version not supplied. Human B1 acceptance retained; C1 unchanged. Prior Q4.12
29PASS and Q4.11 full-suite108PASS/live0of11 remain historical scopes. No repeat
suite or human reference review required without changes/concerns. Next: one
owner-run --boundary --live verifier-only B1 comparison using current private
approved model/key; no full generation/deployment or automatic retry. Target2
answer agreements/2level agreements/0false rejects/calls1, not measured yet.
On error/mismatch preserve output and stop. No assistant tests/static checks/build/
API/deployment or new code in this update. Original five-file/photo/current live
quality/citation/latency/language gaps/explicit whole-task acceptance remain open.
No credentials/private content or disposable materials recorded.

## B1 owner live verifier comparison: scoped agreement - 2026-10-28
Owner supplied full JSON from ai_calibration.ts --boundary --live: model
gemini-3.5-flash-lite, current shared blindReviewRequest,1call/2items;
solving_agreements2, level_agreements2 of2 scored, false_accepts0/false_rejects0.
B1-R-ID solved with an accepted expansion and classified recall; B1-D-MC key
agreed and classified interpretation. Both well-formed, findings empty and
reviewer_accepts true. Scope: observed agreement with the two owner-accepted
reference cases in this call only. No measured latency/cost, full quiz pass,
general accuracy rate or explicit whole-task acceptance. B1 has no negative
controls, so false_accepts0 is not evidence of broad invalid-question rejection.
Human B1 acceptance/C1 frozen content/evidence unchanged. Owner5PASS offline
runner,29PASS spacing correction and older108PASS/live failures retained in scope.
No repeat B1/C1 review or live calibration needed without a justified change.
Interpretation: verifier can recognize this concrete one-rule diagnosis; this does
not establish that its prior abstract live diagnoses were all right or wrong.
Keep current difficulty gate; next investigation/fix targets concrete generator
cases and observed serial-call/deadline capacity, not a model-wide exception.
Hold further generation/deployment until a concrete change is ready for review.
No code/test/static check/build/API/deployment by assistant. Original five-file/
photo, current generated-set quality, citation/latency/language gaps and explicit
whole-task acceptance remain incomplete. Evidence owner chat; exact commit/runtime
version unknown. No private content/credentials/disposable files recorded.

## Q4.13 concrete case inputs, direct non-MC construction and bounded parallel waves - 2026-10-28
Implemented, NOT RUN. Owner B1 live agreement2of2/onecall is retained only for the
accepted reference cases; C1/B1 frozen content/hash and verifier criteria untouched.
No new generated-set pass or five-file score. Historical failures remain.

Medium private plans now require scenario.case with a material fact_id,2..6 short
observable input/state strings (max80characters each) and an action (max250). The
pivot must equal the contrasted material fact and be referenced by the inference.
Repeated observed values are allowed. The flat provider adapter adds case_fact_index,
case_inputs and case_action, with empty sentinels at Easy/Hard. Code renders the
inputs/action with that material fact; application/coverage checks use the rendered
material text. Planning requests actual values/states plus a proposed operation,
resulting state for outcome tasks and concrete evidence for diagnosis. This is
structural input validation, not proof of realism, counterfactual truth or Medium
reasoning: independent difficulty/source/answer/distractor/leakage/assumption gates
remain. English task-operator limitation/citation defects remain unresolved.

First-pass TF/identification text and canonical keys already come from the validated
blueprint. Code now builds those candidates at1point with the quoted objective rule
as explanation, then runs all existing candidate/set/application checks and blind
review. They share non-MC review batches of at most4; no MC judgment arrays are
requested for mixed TF/ID. Failures still consume bounded slot actions; repairs use
provider generation. MC distractors and essay rubrics still require generation.
Public question fields/counts/result shape remain unchanged; no new endpoints,
database or dependency. Localized per-scenario explanation prose is not generated
for first-pass TF/ID; rule-based explanations still require instructor review.

Scheduler admits up to2 independent batches per wave, reserves all expected call
slots before launch, interleaves provider types, and joins all settled work before
finalization. Deadline admission and recheck before verification retained. Unverified
or disputed candidates never enter accepted output. Final global set validation,
position balancing and accurate missing/dropped counts retained. A non-timeout
provider failure takes precedence over simultaneous timeout; existing timeout-only
verified-partial recovery retained. No automatic transport retry. One source audit
still waits for covered first-pass slots and shares existing budgets.

Planned baseline for6MC/2TF/2ID/1essay is8calls (blueprint1,MC4,non-MC review1,
essay2) before repairs/audit, down from11serial-stage calls. This is a code-path
count, not measured latency, billing savings or a promise to finish11questions.
Up to2inflight can increase burst pressure or start a peer before a provider error
is known; calls stay capped13, slot actions3, source audits1, per-call45s and local
overall110s. Stats add peak_inflight; timing adds request-local numeric call_id for
interleaved timing records, without source/question/key content.

Maintained fixtures/provider stage expectations updated for direct TF/ID, concurrent
waves, concrete cases and unchanged API fields. Six new cases cover8-call complete
synthetic mix, max2overlap/all joined, simultaneous fatal-error precedence, direct
non-MC fail-closed review, concrete-input validation/rendering and wire rejection.
Existing call-cap/deadline/timeout/metadata tests retained/adapted. All synthetic
model judgments remain mocks, not measured question quality. No B1 production
exemplar injection or reference edits. No assistant tests/static checks/build/API/
deployment. Owner next runs five-suite command with read access to both reference
docs; stop on errors and hold paid trials/deployment. Whole-task/manual/hosted and
original five-file/photo acceptance remain incomplete. No private/disposable files
created; existing private traces/unrelated changes retained.

## 2026-10-29 Q4.13 owner regression failure and test scheduling correction
Owner reports 116 passed / 1 failed (1s); failing case: structural_test.ts,
"observed slow verification prevents starting an underfunded next batch".
Environment/build not supplied beyond the Q4.13 test context. This is a failed
offline suite, not runtime or whole-task acceptance. Full assertion details were
not supplied. Source inspection identifies a serial timing assumption after the
scheduler became concurrent: both reviews may start before the fixture drops its
clock. The maintained test now explicitly holds peer generation until the first
review consumes the deadline, and asserts a schedule_deferred event requiring
more than the remaining 10000ms. Production scheduler, prompts, gates and limits
unchanged. Correction NOT RUN by assistant; owner rerun pending. C1/B1 evidence
and historical failures retained; original five-file evaluation remains incomplete.
No live calls, deployment, private content or disposable files created.

## 2026-10-29 Q4.13 owner offline rerun
Evidence: owner chat reports "117 passed | 0 failed (783ms)" after the maintained
slow-verification fixture correction. Recorded as owner-reported offline regression
Pass within Q4.13 context; exact command/build not repeated in this message.
Supersedes the failed suite outcome for this rerun only; prior 116/1 failure retained.
Explicit whole-task acceptance: not supplied. No live latency, generated question
quality, hosted deployment or five-file evaluation acceptance inferred. Next check:
one owner-controlled Medium trace with existing sanitized input, unique private
trace destination and approved model; preserve errors/partials, no automatic retry.
No assistant tests, static checks, builds, live API calls or deployment performed.

## 2026-10-29 Q4.13 owner Medium live partial result
Evidence: owner console plus read-only private trace q413-medium-20261029-000524.json
(153887 bytes, outside workspace). Local diagnostic Q4.13/Medium: completed with7/11
returned (5MC,1TF,1ID,0essay), missing1each type;6provider calls,0retries,
peak_inflight2,0trace errors/dropped events, no source audits. All6HTTP200;
blueprint27790ms, generation39067/14199ms, verification13275/12970/18670ms
(overlapping durations must not be summed as elapsed wall time). At final call,
11432ms remained from110s local deadline. No overall timeout reported.
Trace distinguishes slot9 ID blueprint_fact_refs and slot10 essay blueprint_item_shape
from MC slot5 verifier_difficulty/application (solver chose generator key, recall,
0inferences) and TF slot7 unsupported_absolute. No answer-key disagreement established.
Remaining generation+verification work deferred4times:57738ms estimated versus11431ms
remaining. Counters count events, not four additional missing questions. Model/key/test
mode not independently established by these logs; no hosted deployment inference.
Result is partial pipeline execution evidence, not7/11 manual question-quality score.
Explicit owner acceptance: not supplied. Seven returned items still require source,
answer/distractor/duplicate/difficulty review. Original five-file/photo evaluation
incomplete. Existing117PASS offline evidence and all historical failures preserved.
No code change, assistant test/static check/build/live call/deploy or disposable files.

## 2026-10-29 Q4.13 S04-E live blueprint failure
Owner console and read-only private q413-easy-20261029-001625.json (15647bytes):
Easy6/2/2/1 request, AI_BAD_OUTPUT,0returned/all11missing,1call HTTP200/23390ms,
0retries/verifier disagreements/source audits, peak1. All11blueprints rejected with
blueprint_plan; slot7also blueprint_fact_refs. Private trace confirms all11have empty
scenario.goal and expected_outcome; parsePlan requires nonempty task/key. Model in
trace:gemini-3.5-flash-lite. Not a transport/auth failure or strict difficulty/distractor
rejection. Provider raw format versus decoding root cause still needs inspection;
do not assume a wording-only fix. result null explains blank PowerShell .result.
No quality score for this unavailable generation; preserve historical Easy successes
within prior scope. Owner relaxed distractor standard does not authorize blank keys.
No explicit acceptance, code changes, assistant tests/static checks/build/API/deploy.
Next: narrow task/key contract diagnosis before any retry, no increased retry limit.
Original five-file evaluation remains incomplete; private content kept outside register.

## 2026-10-29 Q4.14 Easy blank task/key correction - NOT RUN
Confirmed Q4.13 private trace has empty tasks and keys; source inspection shows decoder
copies these values and wire schema previously allowed empty strings. Ambiguous Easy
empty-outcomes instructions are a possible cause, not proven provider intent.
Small correction: wire scenario_goal/expected_outcome now declare minLength1 and local
primitive validation rejects blank/whitespace-only values. Blueprint instructions
explicitly retain a complete task and source-supported key for Easy despite empty
reasoning arrays; final-outcome equality applies only when steps exist. No fallback
answer fabrication, added provider call/retry, public field/type/count change or
changes to difficulty/distractor acceptance. Revision Q4.14; existing source/answer
verification and provider error handling retained. No claim this guarantees11items.
Maintained wire regression covers all4Easy types, valid empty reasoning arrays,
empty/whitespace task/key rejection preserving slots, and literal false TF key.
Revision assertion updated. Fixtures use already nonblank tasks/keys; no new fixtures,
dependencies/endpoints or disposable files. Owner testing pending; assistant did not
run tests/static checks/builds/live calls/deployment. Previous117PASS remains Q4.13
scope, not Q4.14Pass. Owner whole-task acceptance absent; five-file evaluation incomplete.

## 2026-10-29 Q4.14 owner targeted offline result
Owner chat:41passed/0failed/253ms after wire_test.ts and quality_test.ts handoff.
Recorded as owner-reported targeted offline Pass in Q4.14 context; exact command,
commit and environment not repeated. No full-suite or live success inferred.
Explicit whole-task acceptance absent. Next: one owner Easy6/2/2/1 run using existing
sanitized request-easy.json and a new private trace; preserve previous failure,
stop on error/partial before retry, inspect returned answers/options. No assistant
code/tests/static checks/build/API/deploy. Original five-file evaluation incomplete.

## 2026-10-29 Q4.14 Easy provider-busy attempt
Owner console: blueprint HTTP200/31143ms, generation call2 HTTP503/1322ms,
concurrent generation call3 HTTP200/9117ms; AI_BUSY,0returned/all11missing,
3calls,0retries,peak2,0verifier disagreements/audits/trace errors/dropped events.
One blueprint_fact_refs rejection remains; previous all11blank-plan failure absent
in these logs. Reached generation but no question verification/quality acceptance.
Provider503 is a service error response; precise cause not established. Peer call
already in flight completed but did not produce a verified result. Public error
mapping and joined failure behavior match inspected source. Blank .result expected.
No quality score for unavailable run; preserve this trace before a later manual
retry with new filename. No code change justified solely by503. Exact model/build
beyondQ4.14 not supplied in console. Explicit owner acceptance absent;41offline
passes retained within targeted scope, original five-file evaluation incomplete.
No assistant tests/static checks/build/API/deployment or disposable files created.

## 2026-10-29 Q4.14 Easy owner retry partial9/11
Owner console: completed9/11 with6MC,2TF,1ID,0essay; missing0/0/1/1.
All9provider calls HTTP200,0retries,peak_inflight2; blueprint26537ms;
source audit8729ms,9616ms remaining of110s at final call. Overlapping stage
elapsed values are not summed. No blueprint failures or timeout in this run.
Blind findings:verifier_rubric_coverage1 and verifier_key_mismatch1; one source audit
left2unresolved, supports_generator/alternative/ambiguous all0. Disagreements do not
prove wrong generator keys; per-item review pending. No manual question-quality score.
Recorded as local runtime partial-generation evidence, not full11question success or
hosted acceptance. Previous Easy blank-plan and503attempts retained. Next review
saved output and disputed candidates without rerunning or loosening answer safety.
Explicit owner acceptance absent; original five-file evaluation incomplete. No assistant
code/test/static check/build/API/deployment or disposable materials.


## 2026-10-29 Q4.14 usage diagnostics - implemented, owner checks pending

Observational change only: provider_timing private events now include a usage object
with promptTokenCount, cachedContentTokenCount, candidatesTokenCount, thoughtsTokenCount
and totalTokenCount from Gemini usageMetadata, plus existing call ID/purpose/model.
Only nonnegative safe integers are retained; absent/malformed fields are null, never
inferred zero. Metadata is captured before candidate validation, including rejected
HTTP200 responses. HTTP failures, unreadable envelopes and transport failures can
have unknown usage. request_sent marks an attempted fetch, not confirmed billing.
Hosted timing logs omit the usage object; public request/response and database schemas,
Q4.14 prompts/quality rules/model/concurrency/retry/call/deadline limits are unchanged.

The existing owner-only private runner adds summary to its saved report and console:
model, wall-clock elapsed_ms, provider_calls (fetch attempts), calls_missing_usage
(any of five fields unknown), per-field tokens {observed_total, observed_calls,
missing_calls}, requested/returned/returned_by_type/missing_by_type and error.
Per-call events retain stage timing. Aggregation keys calls by call_id independently
of bounded event storage and includes joined concurrent peers even when another call
fails. No observations or unsafe aggregate sums produce null totals; observed zero
remains zero. No content, secrets or monetary prices are added to usage events.
Existing private path/no-overwrite/no-auto-retry protections remain. Old traces have
no retroactive usage; do not derive tokens from bytes or treat absent data as free.
Manual usable/rejected counts require human inspection, never automatic assignment.

Maintained structural_test.ts adds six mocked regression cases for numeric boundaries,
success/missing/malformed metadata, rejected candidates, observer isolation, offline
failure, concurrent fatal failure with a joined peer, zero attempts and aggregate
overflow. These are NOT RUN by the assistant; no static checks, builds, API calls or
deployment performed. Prior owner41 targeted passes remain within their earlier scope;
new diagnostics and full runtime/whole-task acceptance remain pending.


### Cost measurement (owner-operated, no prices in code)

Use the configured model and record the date, standard API tier and USD per-million
rates from https://ai.google.dev/gemini-api/docs/pricing. Batch processing inside this
pipeline is not Google's discounted Batch API. Official token semantics:
https://ai.google.dev/api/generate-content#UsageMetadata.

For each observed call, with P=prompt, C=cached prompt, O=candidate output and
T=thinking tokens, estimate (P-C)*input_rate/1e6 + C*cached_input_rate/1e6 +
(O+T)*output_rate/1e6, using rates applicable to that model/tier. Cached tokens are
already included in P; do not charge them twice. Do not add totalTokenCount as another
charge. Include any additional model-specific billable components if actually used.
Missing fields, C>P, unsafe totals, dropped timing evidence or unmatched provider
billing make the estimate incomplete; report observed usage and unknown coverage,
not an exact or zero cost. Optional omitted counters remain unknown in diagnostics;
resolve billing semantics from official model/provider records rather than guessing.

Sum costs across successes AND failures. Report paid-equivalent estimate separately
from actual free-tier charges/provider billing, excluding infrastructure. Cost per
usable question = aggregate estimated cost / manually accepted usable questions.
With zero usable questions report 'no usable output; cost per usable question undefined'.
Label the sample size; no production success rate or guarantee follows from one run.

Owner steps (from filo-app/backend):
1. Run only the targeted mocked cases; no live AI permission is needed:
   deno test --filter "usage" --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/structural_test.ts
   Expect six new cases to pass, with no network calls. Stop and report any failure.
2. Review the existing private partial trace first; preserve it. New diagnostics cannot
   recover its old token usage. Keep proposed manual review separate from owner acceptance.
3. For the next already-planned live trial, retain the current model/key in environment
   and use the established runner command below with a NEW destination (real AI calls):
   deno run --allow-read --allow-write='C:\Users\Dell\Downloads\FiloQualityPrivate' --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --input 'C:\Users\Dell\Downloads\FiloQualityPrivate\request-easy.json' --trace 'C:\Users\Dell\Downloads\FiloQualityPrivate\q414-usage-NEW.json'
   Choose an unused trace filename before running. Expect summary plus preserved events,
   counts and error; missing usage stays null. Stop on failure/partial and inspect before
   a later manual retry with a different filename. Offline/busy errors must retain the
   failed summary without automatic retry or fabricated zero token cost. Existing files
   must never be overwritten. No frontend/offline UI claim is covered by this runner.
4. Inspect keys/support/ambiguity and record manually usable/rejected counts, then apply
   the dated formula above. Retain earlier failed attempts in the aggregate.


## 2026-10-29 Q4.14 usage diagnostics owner targeted result
Owner chat reports: ok | 6 passed | 0 failed | 52 filtered out (56ms).
Recorded as owner-reported targeted mocked usage-diagnostics Pass following the
provided filtered command; exact command/build/environment were not repeated.
The52filtered cases were not run. No full-suite, live provider, deployment, billing
measurement or question-quality acceptance inferred. Earlier failures/partial output
and scoped passes remain. No repeat of these six checks requested.
Next: owner reviews existing saved output and, on the next planned live run, uses
an unused private trace filename to inspect summary tokens/timing/counts/errors.
Stop on error/partial before another manual retry; unknown usage is not zero cost.
Explicit whole-task acceptance absent; live usage/cost and runtime acceptance pending.
Assistant ran no tests/static checks/build/API/deployment; no implementation changes
or disposable materials in this follow-up.


## 2026-10-29 Q4.14 owner live usage summary - partial8/11
Owner pasted private-runner summary: model gemini-3.5-flash-lite, elapsed94688ms,
7provider calls, error null, requested11/returned8:4MC/2TF/2ID/0essay; missing2MC/1essay.
All7calls report prompt19327/candidates6016/total25343 tokens, each missing_calls0.
Cached/thinking counters absent on all7; calls_missing_usage7 means at least one field
unknown per call, not all usage absent. Nulls retained, no inferred zeros. Aggregate
total equals prompt+candidates; not proof of billing, caching absence or omitted-field
semantics. Owner live evidence of diagnostics/partial generation, not full11success,
manual quality acceptance, hosted verification or whole-task acceptance. Exact build,
trace filename, billing tier and per-stage failure reasons not provided in this summary.

2026-10-29 conditional standard paid-equivalent illustration using official Google
pricing https://ai.google.dev/gemini-api/docs/pricing: input0.30USD/1M and output2.50USD/1M.
Assuming all19327input tokens uncached and no additional billable thinking tokens,
19327*0.30/1e6 + 6016*2.50/1e6 =0.0208381USD per attempt (about2.08US cents).
This is not an exact bill or unconditional bound; cached/thinking counters remain unknown.
Eight returned items are not eight manually accepted usable items; cost/usable unknown.
At identical usage,1000attempts would illustrate20.84USD, excluding infrastructure,
other attempts and changed rates/usage. Free-tier charges may differ; verify billing.

Using code-reviewer guidance: observed concern is94.7s wait and incomplete delivery,
not demonstrated high dollar cost. Summary cannot establish why3items were missing.
Next owner step: inspect existing trace finish.stats and per-stage timings/rejections,
then review returned question keys/support; no new AI call or automatic retry required.
Keep previous6mockedPass/52filtered, prior503and9/11partial evidence in original scope.
Assistant performed no tests/static checks/build/live calls/deployment or generation
changes; no disposable files. Explicit owner acceptance absent; cost accuracy, manual
quality and complete-generation reliability remain pending.


## 2026-10-29 Q4.14 usage run stage diagnosis - no implementation change
Owner supplied stats/timings and assistant read existing private usage trace read-only.
7calls/allHTTP200,0retries,1verifier disagreement,peak2,0trace errors,0difficulty
mismatches,0source audits. Timings: blueprint30090ms; generation20631/23137/28847ms;
verification9984/12527/16464ms. Parallel elapsed times must not be summed as wall time.
2blueprints rejected (fact_refs twice; one also task_justification/render); both gaps
were filled by same-type spares. These rejections did not directly leave missing slots.

Trace establishes final2MC candidates passed local checks but were not blind verified:
scheduler required16464ms based on observed verifier maximum, with15316ms remaining.
No actual timeout or provider error occurred. Later round admission required another
generation+verification45312ms and deferred twice; no retry call was made. Pending
candidate verification is not independently resumed by this path. All3time_budget
counters are scheduling events, not3proven faulty questions. No unverified output emitted.
Essay withheld for verifier_rubric_coverage; inspected generator/solver answers agree
on central content but use different descriptions. Lexical coverage concern, not proven
wrong key. Rubric asks more descriptive detail than short expansion task wording;
review separately rather than silently accept. No source audit ran; last batch returns
before covered bookkeeping after deferred verification, so first-pass coverage gate
also prevents audit. No guarantee audit would fit or resolve the essay.

Recommendation for a separately authorized change: retain locally valid pending
candidates and prioritize verification-only continuation before another generation;
review and correct task/rubric alignment and semantic-equivalent rubric matching
without accepting wrong/unsupported answers. Do not add calls/retries, extend deadlines
or relax source/answer safety solely on this sample. Existing generation remains Q4.14.
Owner live partial8/11 evidence retained, not full generation or quality acceptance.
No further AI call needed for diagnosis. No assistant tests/static checks/build/API/
deployment; no disposable files. Explicit owner whole-task acceptance absent.


## 2026-10-29 direct-v1 owner comparison pipeline - NOT RUN

Owner requested a separate simple generation path to compare against Q4.14 planning.
Implemented locally in backend/tests/ai_direct.ts and selected ONLY by --direct in the
existing private ai_quality_trace.ts runner. Default stays Q4.14; hosted handler and
frontend routes do not select this path. No new endpoint, DB write, deployment, setting
migration, dependency or paid run. quiz.ts only exposes its existing privateText redactor
for reuse; production generation rules and transport behavior are unchanged.

Flow: existing validated source/counts/difficulty/focus -> one direct Gemini JSON call
-> existing basic validateOutput checks -> private candidate output and usage summary.
No blueprint/objective plans, separate solver, source audit, semantic difficulty gate,
repair call, spare objectives, canonical rendering or automatic retry. A concise prompt
asks for source-supported distinct questions and self-review, not independent verification.
JSON MIME only, no provider schema or Q4 flat-wire adapter. API TextResponseFormat.schema
is optional: https://ai.google.dev/api/generate-content#TextResponseFormat.

Uses the same configured GEMINI_MODEL/GEMINI_API_KEY and the same request input as the
baseline; no forced thinking-level setting or claim of web Low equivalence. Direct call
has a45second maximum within the runner's110second deadline and262144byte response cap.
Existing HTTP busy/unavailable, malformed/incomplete output and timeout codes remain;
no key/raw provider error is printed. Existing private output path restriction,
createNew/no-overwrite and --live requirement remain. Raw candidate text (bounded and
redacted) stays in the private trace, so malformed output can be inspected without retry.
Metadata usage is captured before candidate validation; failed calls retain unknowns
where metadata is absent. All totals use the existing private measurement summary.
summary.pipeline explicitly identifies direct-v1 or Q4.14.

Basic checks enforce shapes, field limits, valid keys, essay rubric totals if supplied,
exact prompt deduplication and count caps. Existing manual-format option limits2..10
remain, although the prompt requests exactly4. No new semantic rejection rules are added.
A returned question is NOT proof of correct/source-supported/unambiguous content or
requested difficulty. Essays lacking requested sample/rubric/evidence metadata must be
noticed in manual review; this comparison intentionally reuses the existing basic gate.
Never auto-publish or count returned items as manually usable. No result goes into the app.

Seven new maintained mocked cases in backend/tests/ai_direct_test.ts cover11mixed items
in one call, JSON-only/no planning contract, partial basic rejection without repairs,
malformed/truncated/zero output, HTTP/offline errors and unknown usage, bounded deadline/
response size, observer isolation/redaction, input limits and regeneration payloads.
These checks have NOT RUN; prior six owner usage passes remain prior scope. Request
owner reruns those six after runner selection change to check the default Q4.14 path.
Current direct runtime/provider acceptance/manual quality and owner acceptance pending.
No assistant tests, static checks, builds, live calls or deployment; no disposable files.


### Owner steps for direct-v1 comparison
1. From filo-app/backend, run maintained offline mocks:
   deno test --config supabase/functions/ai-generate-quiz/deno.json tests/ai_direct_test.ts
   Expect7passing cases, zero real network calls. Then rerun the affected default runner checks:
   deno test --filter "usage" --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/structural_test.ts
   Expect the same6usage cases to pass. Stop and report failures before a live trial.
2. Keep the existing model/key environment. Create a NEW private filename in PowerShell:
   $directTrace = "C:\Users\Dell\Downloads\FiloQualityPrivate\direct-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
3. Owner runs ONCE (real AI call; may consume paid quota):
   deno run --allow-read --allow-write="$directTrace" --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --direct --input 'C:\Users\Dell\Downloads\FiloQualityPrivate\request-easy.json' --trace "$directTrace"
   Expect summary.pipeline=direct-v1 and provider_calls=1 if fetch starts. This input
   already contains the original Downloads DBMS sample lesson and6MC/2TF/2ID/1essay.
   Full11is the requested target, not a guaranteed outcome. On busy/offline/timeout/
   malformed/partial result, preserve the trace and stop; no automatic retry.
   Existing destinations must be rejected without another AI call or overwriting evidence.
4. Inspect only numeric summary for sharing, then questions locally:
   $directReport = Get-Content -LiteralPath $directTrace -Raw | ConvertFrom-Json
   $directReport.summary | ConvertTo-Json -Depth 8
   $directReport.result.questions | ConvertTo-Json -Depth 8
   Expect usage known/unknown counters as returned by provider. Never paste keys or a
   full private trace. If result is null, inspect saved redacted provider_response locally.
5. Compare with the preserved Q4.14 baseline94.688seconds/7calls/8of11returned. Check
   actual time/calls/tokens, requested versus returned counts and human-usable questions.
   Review against the lesson: wrong keys, ambiguous options/inherited requirements,
   duplicate facts/cross-item clues, accepted variants, essay task/rubric alignment,
   evidence and source support. Keep style/distractor strength as separate notes.
   Missing metadata is unknown usage, not free. Count no successful output as usable
   without review; do not divide cost by zero if none are usable. One trial is not a
   reliability rate. No app integration/publication or hosted behavior is covered here.


## 2026-10-29 direct-v1 owner TS2366 failure and explicit error return - pending rerun
Owner supplied Deno test command stops at type checking: TS2366 generateDirect lacks
ending return (ai_direct.ts:23), so none of7direct runtime test cases ran. Historical
failure preserved; no runtime Pass inferred. Source correction adds explicit return
of fail(code) in catch. fail still throws QuizError with same mapped code; timing
finally/cleanup, success return, limits and one-call behavior retained. No --no-check
workaround or return-type weakening. Existing mocked error/deadline/observer cases
cover affected paths; no new test mirroring this one-line control-flow correction.
Owner reruns7direct tests, then6affected default usage checks; stop on any failure
before live trial. Exact fixed build/runtime results and owner acceptance pending.
No assistant tests/static checks/build/live calls/deployment or disposable materials.


## 2026-10-29 direct-v1 owner live result and raw-output review
Owner pasted summary/questions; assistant inspected matching existing private direct
trace read-only and compared with original lesson. Model gemini-3.5-flash-lite:
18312ms/1call, error null, requested11/returned10:6MC/2TF/2ID/0essay; missing1essay.
Prompt1874/candidates1549/total3423 observed on1call; cache/thinking unknown. No extra
AI call made. Local runtime output evidence, not hosted/manual/whole-task acceptance.
Seven-direct/six-default mocked rerun results not supplied here; do not infer Pass.
Historical TS2366 and prior scoped evidence remain recorded.

Private raw provider text contains11items, including the essay. Essay sample answer
and4point rubric agree with its task/source; rubric points1+1+2sum4. It omitted BOTH
explanation and evidence. Existing validateQuestion checks explanation type first,
so invalid_explanation drops it before optional evidence validation. Missing evidence
also violates the prompt but is not itself enforced as required by the basic gate.
This is an output-contract omission, not failure to generate an essay or a rubric
mismatch. No silent insertion of metadata or loosening of validators performed.

Source/content inspection: intended keys generally match source. Returned MC6asks
which normal form requires an inherited property without FIRST;2NF/3NFalso inherit
it, so alternatives are not mutually exclusive. Material ambiguity; revise task wording
rather than declare intended1NFkey wholly unsupported. Other9returned items show no
material wrong-key/unsupported-answer findings under practical review, not owner score
or acceptance. Improvement notes: MC3mixed-kind/easy distractors; raw essay overlaps
its DBMS example topic; false TFabsolute wording is a giveaway; MCpositionsA3/B2/C1/D0
unbalanced, and two explanations contain glued words. Raw essay metadata needs completion.
No private question/source/answer text reproduced in this register/report.

Comparison on the supplied two attempts only: Q4.14 returned8/11in94688ms/7calls/
25343reported tokens; direct returns10/11validated,11raw in18312ms/1call/3423tokens.
About5.17times faster (80.7percent less elapsed),86.5percent fewer reported total tokens.
Conditional same standard rate illustration (all input uncached/no extra billable
thinking, official Google pricing rates previously verified2026-10-29):
1874*0.30/1e6 +1549*2.50/1e6=0.0044347USD (~0.44UScent), versus0.0208381USD baseline.
Not actual billing or cost per manually usable question; cache/thought values unknown.
No general success/quality rate or equal semantic verification claimed.

Recommendation: this supports simpler draft generation as a promising direction;
next narrow correction would enforce/clearly specify required output fields and
inherited-level task wording, retaining human review and basic validity boundaries.
Do not restore complex planning or switch models based on this result. Production
replacement and any further implementation need separate authorization. No need to
rerun this private trace for diagnosis. Owner next reviews MC6ambiguity, raw essay
rubric/metadata and actual usable count locally, preserving evidence. Current default
Q4.14 unchanged; no assistant tests/static checks/build/live calls/deploy or disposable
files. Explicit owner quality/whole-task acceptance remains absent.


## 2026-10-29 direct-v1 Easy Medium Hard owner trials - practical source review
Owner pasted three console summaries/questions; assistant read matching existing
private trace/request files and lesson read-only. Input files correctly set easy,
medium,hard with6MC/2TF/2ID/1essay each; no command difficulty-selection bug found.
All use gemini-3.5-flash-lite/direct-v1,1call,errornull,0dropped trace events.
Easy:13863ms,prompt1874/output1577/total3451,10validated(6/2/2/0),missingessay1.
Medium:18812ms,prompt1874/output1790/total3664,11validated(6/2/2/1),missing0.
Hard:17351ms,prompt1874/output1609/total3483,10validated(6/2/2/0),missingessay1.
Cached/thinking counters absent in all3; no inferred zeros or actual billing claim.

All3raw responses contain11items. Easy/Hard essaysample/rubric are present but BOTH
explanation/evidence omitted; consoleinvalid_explanation matches existing basic gate.
Medium includes both fields and essay survives. Raw essay counts do not change the
validated counts. Recurring output-contract omission, not failure to invent an essay.
Earlier TS2366 failure and unreported mocked rerun results remain distinct; these live
runs do not establish7direct/6default mockedPass or hosted/full acceptance.

Practical content findings (assistant source inspection, no numeric quality score):
- Easy is broadly recall as requested. Intended keys generally source-supported;
  weak/obvious distractors and glued explanation words are editing notes. EasyQ5
  excludesPRIMARY KEY from options, so the MediumQ4multi-answer concern is not shared.
- Medium is mostly recall/definition identification, including its descriptive essay;
  no meaningful concrete condition/application required. It is complete format-wise
  but not demonstrated Medium difficulty. MC4acceptsNOT NULL whilePRIMARY KEY also
  forbidsNULL according to the lesson, so single-answer wording is ambiguous. Empty
  wording additionally confuses null with empty-string semantics; revise to precise
  direct non-null constraint naming or exclude the competing implication. Essay fifth
  rubric point adds a logical-unit transaction requirement not explicitly asked or
  developed in sample answer; align prompt/sample/rubric. MC3/essay overlap transaction
  property coverage. Acronym prompts accept full names despite asking for an acronym;
  loose answer-format notes separate from wrong concept keys.
- Hard is also mostly recall, not dependent multi-step reasoning; merely naming
  normalization levels/technical terms does not make it Hard. No claim question keys
  globally wrong. Normal-form items need FIRST/introduced-at specificity where higher
  options inherit requirements; MC1includes a beyond-source higher form as distractor.
  MC4andID10overlap/acronym expansion exposes earlier letter answer. BothTFareTrue;
  imbalance/style is lower priority than ambiguity/difficulty, not a new acceptance gate.
No private question/source/answer text copied into register or maintained docs.

Conclusion for these3attempts: one-call generation is fast13.9-18.8seconds and raw
count-complete, but not yet reliable at required metadata or difficulty adherence.
Medium11of11is local runtime format-completion evidence only, not quality/full acceptance.
Recommended next separately authorized narrow work: small required-field JSON contract
with per-type examples; clearer difficulty instructions using concrete source-supported
cases forMedium and two dependent inferences forHard; explicit unique-answer/inheritance
and cross-item clue rules. Keep one call/basic validation/instructor review; no return
to blueprint/solver/audit loops or automatic repairs just to improve labels. No guarantee
prompt/schema alone enforce semantics. No further AI rerun needed to diagnose these files.
Owner next reviews MediumMC4, difficulty labels and missing essaymetadata, then records
usable counts separately. No implementation changes, assistant tests/static checks/
build/live calls/deployment or disposable files. Explicit owner acceptance absent.


## 2026-10-29 direct-v2 grouped schema and difficulty examples - NOT RUN

Current private --direct comparison now identifies itself as direct-v2. Supersedes
only direct-v1 private generation behavior; all direct-v1 traces/results and historical
TS2366 remain intact. Q4.14 hosted/default generation, public API/database/frontend,
model/key configuration and thinking settings are unchanged. No extra provider calls,
blueprints, judges, source audits, spare objectives, repairs or automatic retries.
The direct call retains45second/262144byte limits, redaction, observer isolation,
usage accounting, failure codes and the existing private no-overwrite destination.

Provider response is now a native JSON-schema object containing required arrays
multiple_choice,true_false,identification,essay. Each array has0..requested_count
items of its own shape; zero-count types must be empty. No union, flat-wire adapter,
provider item type field or nullable unused answer fields. Every item requires nonblank
prompt/explanation/evidence and integer points; MC requires exactly4options and valid
index, TFboolean, IDaccepted answers, essaynonblank sample_answer/rubric. Nested rubric
points/key_point requirements and current length/type limits are represented in schema.
Schema is guidance enforced by provider when supported, never proof of semantic quality.

Direct-only decoder requires exactly these4array groups; missing/wrong groups, extra
root fields, invalidJSON or old raw arrays failAI_BAD_OUTPUT. Per-item missing/extra
fields, blank common text, invalid essaymetadata or non-four-option MC are rejected;
existing validateOutput then checks lengths, answer shapes, integer points/rubric sum,
exact prompt duplication and valid counts. No metadata fabricated or semantically
repaired. Arrays beyond requested cap count excess items as dropped; only firstNraw
slots are considered, not filled from over-cap extras after a malformed early item.
Group determines finaltype. Valid candidates are flattened to existing result.questions
with dropped/missing_by_type counts. Empty groups reflect missing counts, not dropped
items. If no valid candidates survive, generator returnsAI_BAD_OUTPUT with private raw
output/usage retained. Raw traces have grouped shape; public/private result fields and
CLI --direct/input settings stay compatible, summary.pipeline changes to direct-v2.

Original concise prompt now defines difficulty for all question types: Easyretrieval,
Mediumone source-supported rule applied to meaningful case conditions, Hardtwo dependent
inferences using an intermediate result. Three original tile/pack/panel teaching examples
have self-contained miniature references and answers; explicitly excluded from factual
lesson context/evidence and not allowed as generated questions. Neutral hypothetical
case values permitted only with actual-source rules; no outside facts. Longer wording,
technical vocabulary, decorative cases and recalling several definitions do not establish
higher difficulty. TF/IDmust infer from cases; essays must align task/sample/rubric.
MCmutual exclusivity, inherited requirement FIRST specificity, NULLversusempty precision,
distinct facts and no cross-question answer disclosures are explicit writing rules.
These are prompts/manual-review criteria, not new semantic rejection gates or promises.

Reference patterns: single-call batching documented by
https://github.com/AayushNair10/SocraticTutor and mixed-format authoring documented by
https://github.com/vicajilau/quizdy. Original implementation, no copied repository code,
frameworks, dependency installs or claims of their demonstrated difficulty accuracy.
Official guidance: https://ai.google.dev/gemini-api/docs/prompting-strategies and
https://ai.google.dev/gemini-api/docs/structured-output. No external app/account writes.

Maintained ai_direct_test.ts now has10mocked cases:7updated plus3for required fields,
MC/rubric validity, malformed groups/partial/excess/zero-count/misplaced itemtype behavior.
Existing timeout/error/observer/redaction/usage/input/regeneration paths remain covered.
Tests are NOT RUN by assistant; earlier6ownerusagePass and direct-v1live outcomes retain
only their earlier scope. New schema provider acceptance, owner mocked/default checks,
Easy/Medium/Hard improvement and whole-task acceptance remain pending. No assistant
static checks/build/live calls/deployment. No disposable materials or private question/
source content created in repository. Graphify refresh pending attempt after documentation.


### direct-v2 owner verification steps
1. From filo-app/backend run:
   deno test --config supabase/functions/ai-generate-quiz/deno.json tests/ai_direct_test.ts
   Expected10mocked tests pass, no network calls. Stop on any type/check/runtime failure.
2. Recheck affected default private-runner behavior (shared import/revision label changed):
   deno test --filter "usage" --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/structural_test.ts
   Expected6usage tests pass and default Q4.14 still selected. Earlier scoped Pass retained;
   this limited rerun is justified by the changed shared import, not a full-suite request.
3. Only after offline checks pass, retain the existing model/key environment and prepare
   new difficulty inputs outside Git (same lesson/counts, new unique identifier):
   $privateRoot = 'C:\Users\Dell\Downloads\FiloQualityPrivate'
   $trialId = [guid]::NewGuid().ToString('N')
   $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
   foreach ($difficulty in @('easy','medium','hard')) {
       $request = Get-Content "$privateRoot\request-easy.json" -Raw | ConvertFrom-Json
       $request.difficulty = $difficulty
       [System.IO.File]::WriteAllText("$privateRoot\request-v2-$difficulty-$trialId.json", ($request | ConvertTo-Json -Depth 20), $utf8NoBom)
   }
4. Run each independently, once (real Gemini calls, may consume paid quota); stop and
   inspect failures/partial output before any retry. Do not overwrite prior traces:
   $easyTrace = "$privateRoot\direct-v2-easy-$trialId.json"
   deno run --allow-read --allow-write="$easyTrace" --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --direct --input "$privateRoot\request-v2-easy-$trialId.json" --trace "$easyTrace"
   $mediumTrace = "$privateRoot\direct-v2-medium-$trialId.json"
   deno run --allow-read --allow-write="$mediumTrace" --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --direct --input "$privateRoot\request-v2-medium-$trialId.json" --trace "$mediumTrace"
   $hardTrace = "$privateRoot\direct-v2-hard-$trialId.json"
   deno run --allow-read --allow-write="$hardTrace" --allow-env=GEMINI_API_KEY,GEMINI_MODEL --allow-net=generativelanguage.googleapis.com --config supabase/functions/ai-generate-quiz/deno.json tests/ai_quality_trace.ts --live --direct --input "$privateRoot\request-v2-hard-$trialId.json" --trace "$hardTrace"
   Expectedsummary.pipeline=direct-v2 and1provider call if fetch starts. Target11items
   (6/2/2/1), including essayexplanation/evidence/sample/rubric; full counts not guaranteed
   for insufficient source. HTTP400schema rejection, busy/offline/timeout and malformed
   output must retain sanitized error/unknown usage with no automatic retry.
5. For each saved trace inspect summary and questions locally:
   $report = Get-Content -LiteralPath $easyTrace -Raw | ConvertFrom-Json
   $report.summary | ConvertTo-Json -Depth 8
   $report.result.questions | ConvertTo-Json -Depth 8
   Repeat with mediumTrace/hardTrace. Share numeric summary only; keep full source and
   questions private. Inspect grouped raw provider_response locally if result is null.
6. Check lesson support/keys/unique MC answers, no duplicate facts or cross-item clues,
   correct variants, exact source evidence and essay task/sample/rubric alignment. Ensure
   tile/pack/panel teaching examples have not leaked into DBMS questions/evidence. Judge
   Easyretrieval/Mediumapplication/Harddependent reasoning for each question type. Compare
   with preserved direct-v1times13.863/18.812/17.351s and validated10/11/10; no prior rerun.
   Record counts, errors, tokens and manually usable items separately from owner acceptance.
   Missing cache/thinking counters remain unknown. Schema compliance alone is not quality
   Pass; no artificial score or silent difficulty relabel. Owner may explicitly waive a
   required check; otherwise it remains pending. Production switch/app checks out of scope.


## 2026-10-29 direct-v2 owner mocked checks and three live trials
Owner pasted full Deno commands/results:10direct tests passed/0failed/55ms;6usage
checks passed/0failed/52filtered/85ms. Record owner-reported scoped mocked Pass;52not
executed, no full-suitePass inferred. Negative-fixture question_dropped and mocked
provider errors are expected test paths, not evidence these live calls failed.
Previous TS2366 remains historical, superseded for this tested revision scope only.

Owner console and existing private traces read-only: direct-v2/gemini-3.5-flash-lite,
1call each,errornull,0trace drops. Easy21989ms,prompt2380/output1498/total3878,
11validated(6/2/2/1);Medium16492ms,prompt2380/output1885/total4265,11validated;
Hard14749ms,prompt2380/output2396/total4776,10validated(6/2/2/0),missingessay1.
All3raw grouped responses contain6/2/2/1, required essaymetadata present. Native grouped
schema accepted in these3local provider trials, not a universal/provider/hosted guarantee.
Cached/thinking counters unknown on each call; no zero assumption or billing claim.

Hard essay rejected invalid_rubric: question.points=1 but rubric2+2+2=6. Every required
field is present; no return of missing-explanation/evidence failure in these3runs.
Schema enforces individual field types/ranges, not cross-field sum equality. Existing
local validator correctly withholds inconsistent scoring; no automatic score correction.
No full11success forHard or manual content acceptance inferred.

Practical assistant lesson/output inspection (no numerical quality score):
Easy generally appropriate recall, but MC1andID10repeat same language fact/explicit
acronym cue; data/information also reused in essay and other items. Very weak distractors
are improvement notes rather than wrong-key findings. Essayfields/rubric now present.
Medium adds case framing, but most MC/TF/IDstill name definitions, commands or properties;
MC6includes identifying definition in stem, making it recognition. Essay repeats supplied
worked deletion scenario; do not claim successful transfer/application from framing alone.
Normal-form MC5needs FIRST/strongest qualification with higher-form distractors. No blanket
wrong-key classification. Difficulty control remains incomplete across question types.
Hard MCmostly combine2independent recalled facts; neither result is needed to derive the
other. TF/IDremain recall; long stems do not establish2dependent inferences. Some unrelated
conditions and weaker alternatives remain, not all key errors. Raw essaymostlydescriptive,
with invalid scoring noted above. No reliableHardgeneration demonstrated.
Evidence strings in Mediumessay and multipleHarditems splice separate excerpts with
ellipsis; Hardforeign-key quotation also paraphrases the source. They are not exact
contiguous quotations even when underlying concepts are supported. This is a grounding/
quotation-fidelity finding, not a claim all answers hallucinated. No tileexample leakage
seen in reviewed outputs. Private question/source/answer text not reproduced in register.

Conclusion: scoped mocked checks pass, grouped schema/required-field adherence improved
in these3runs and one-call speed retained. Scoring arithmetic, exact evidence, repeated
facts/cues and actualMedium/Harddemand remain open. Do not declare task complete or replace
hostedQ4.14. No repeat mocked/live runs requested just to record these results. Owner next
reviews Hardessaypoints/rubric, dependentversusparallelreasoning and exact source evidence,
then records usable counts/explicit acceptance separately. Any code or prompt change
requires separate authorization; avoid endless blind prompt-only revisions. Original
five-file/hosted/whole-task gaps remain. No assistant tests/static checks/build/live calls/
deployment, implementation changes or disposable files in this follow-up.


## 2026-10-29 owner accepts direct-v2 experiment - M10-BE-03 scope retained
Owner chat: 'okay its good for me can you apply it?' and restates M10-BE-03fivefile task.
Explicit owner acceptance recorded for the reviewed direct-v2TXT experiment within its
observed scope; no silent conversion to flawless quality, full count success forHard,
numeric quality score, hosted deployment or whole five-file completion. Existing rubric/
difficulty/evidence/duplicate findings remain documented; acceptance is separate from
measured outcomes. No explicit waiver of other files/dev-project checks provided.
Application target (hosted switch versus experiment/documentation only) awaiting scope
clarification; no hosted code change or deployment made on this ambiguous instruction.

Current latest S04comparison (local private Gemini calls, not DEVendpoint verification):
| Set/revision | Returned MC/TF/ID/Essay | Measured time/calls | Owner acceptance / numeric quality score |
| --- | --- | --- | --- |
| S04-E/direct-v2 | 6/2/2/1 | 21.989seconds/1call | Accepted qualitatively; numeric score not supplied |
| S04-M/direct-v2 | 6/2/2/1 | 16.492seconds/1call | Accepted qualitatively; numeric score not supplied |
| S04-H/direct-v2 | 6/2/2/0 | 14.749seconds/1call | Accepted experimental result; essay score mismatch retained; numeric score not supplied |

Only S04TXTlesson is supplied/authorized in the recorded evaluation inventory. S01PDF,
S02PPTX,S03DOCX,S05photo remain pending; photo extraction prerequisite remains unresolved,
not an observed qualityPass/Fail. Original5files x3difficulties=15sets; supplied local3sets
cannot stand in for missing12sets or dev-project checks. Keep original baseline matrix/
prior owner/mock/live evidence and all historical failures. Do not generate substitute
team-owned files or assign scores on the owner's behalf. Task remains incomplete unless
remaining required evidence arrives or owner explicitly waives/reduces the scope.

Prompt improvements and observed limitations are recorded in ai-prompts.md for Technical
Writer review: onecall grouped native schema/required essayfields;3difficulty examples;
MCmutual exclusivity/inheritance specificity/task-rubric alignment. Lowdifficulty adherence,
spliced evidence and Hardrubric arithmetic remain open, no guaranteed fix claimed.
Documentation handoff prepared locally; no external Technical Writer recipient/channel
identified or delivery/acknowledgement claimed. No assistant tests/static checks/build/
live calls/deployment or disposable files; no private question/source text stored here.


## 2026-10-29 apply accepted direct-v2 to authenticated endpoint - NOT DEPLOYED
Owner scope reply 'as long as the generation is working' interpreted with preceding
'apply it' as authorization to wire accepted one-call generator into the backend.
This is implementation authorization, not proof of successful deployment or waiver
of M10-BE-03 remaining samples. Owner acceptance of local TXT experiment retained.

Moved unchanged direct-v2generation logic from backend/tests/ai_direct.ts into maintained
supabase/functions/ai-generate-quiz/direct.ts; private runner/tests import same module.
Removed old task-created module only after verifying its two callers were updated.
Authenticated handler now invokes generateDirect; Q4.14generator remains available for
historical comparison, and private runner without --direct deliberately remains Q4.14.
No separate provider schema/prompt copies or new runtime mode config. One native grouped
Gemini call; same public questions/dropped_by_type/missing_by_type response; prompts,
counts/difficulty/focus/regeneration inputs, evidence/sample/rubric metadata unchanged.
No answer/source semantic verification added; owner accepts current experimental quality
with historical difficulty/quotation/repetition/scoring concerns still recorded.

JWT/session/instructor/ownership/archive/delete/quiz-lock checks, input/body limits,
per-user begin_ai_request, sanitized errors, DEV-only AI_TEST_MODE and finally-based
finish_ai_request retry remain in handler untouched. Zero surviving questions fail;
verified-format partial result may return200with missing/dropped counts. Inconsistent
rubric totals remain rejected, not automatically fixed. No persistence/publication added.
Direct call45smaximum within110shandler deadline; no provider retries. Numeric hosted
provider_timing now records pipeline_revision=direct-v2/purpose=direct_generation without
usage payload or question/source/providertext; private observer retains prior diagnostics.
No key/model changes, DB migration, dependency/install, frontend integration or deployment.

Handler mocks now use a maintained grouped synthetic provider fixture; Q4fixtures retained
for historical pipeline tests. Two new endpoint regressions cover1call/public shape/
terminal success and partial versus malformed-output finalization with no repair.
Existing denial/scoped-query/concurrency/DEV-simulation/DB/finalization cases retained.
Owner pending:10direct plus22quiz/handler mocked cases, then DEV deployment/invocation
withAI_TEST_MODEoff and matching terminal usage evidence. Previous owner10direct/6usage
Pass and local3difficulty outcomes carried forward within recorded pre-wiring scope.
No assistant tests/static checks/build/live calls/deployment or disposable materials.

M10-BE-03remains incomplete: onlyTXTsample supplied; fourothermaterials/12sets/numeric
scores and DEV endpoint evidence pending unless explicitly waived. Updated ai-prompts.md
is local TechnicalWriter handoff; external recipient/delivery unconfirmed. Current
implementation available for owner testing; no runtime or whole-task acceptance claimed.


### Owner verification after hosted source wiring
1. From filo-app/backend run:
   deno test --config supabase/functions/ai-generate-quiz/deno.json tests/ai_direct_test.ts supabase/functions/ai-generate-quiz/quiz_test.ts
   Expected32mocked cases (10direct+22quiz/handler) pass with type checking. No live
   calls. Preserve previous evidence; stop if any case fails before deployment.
2. Owner deploys only this function to existingDEV, using existingCLI/auth:
   npx.cmd supabase functions deploy ai-generate-quiz --project-ref fiobwfzmqcffbpixzvbq
   npx.cmd supabase secrets set AI_TEST_MODE=off --project-ref fiobwfzmqcffbpixzvbq
   No migrations/model/key changes. Expecteddeployment succeeds; never treat deployment
   success as generationPass. Assistant has not executed these commands.
3. Invoke existingDEVrequest with fresh verified instructor credentials and valid owned
   active class/unlocked quiz IDs. Existing private provider-only request may omit IDs;
   supply them in a new private request rather than changing old evidence. Example:
   $devRequestPath = 'C:\Users\Dell\Downloads\FiloQualityPrivate\request-endpoint-NEW.json'
   $devRequest = Get-Content 'C:\Users\Dell\Downloads\FiloQualityPrivate\request-easy.json' -Raw | ConvertFrom-Json
   $devRequest | Add-Member -NotePropertyName class_id -NotePropertyValue 'YOUR_ACTIVE_OWNED_CLASS_UUID' -Force
   $devRequest | Add-Member -NotePropertyName quiz_id -NotePropertyValue 'YOUR_UNLOCKED_QUIZ_UUID' -Force
   [System.IO.File]::WriteAllText($devRequestPath, ($devRequest | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
   curl.exe -sS -X POST 'https://fiobwfzmqcffbpixzvbq.supabase.co/functions/v1/ai-generate-quiz' -H "Authorization: Bearer $env:FILO_ACCESS_TOKEN" -H "apikey: $env:FILO_ANON_KEY" -H 'Content-Type: application/json' --data-binary "@$devRequestPath"
   Use an unusedNEWfilename and replace UUIDplaceholders. Set localFILO_ACCESS_TOKENto
   a fresh current verified instructor token andFILO_ANON_KEYto theDEVpublishable/anon
   key without sharing them. Endpoint request must keep the selected lesson/counts.
   Expectedquestions/dropped/missing public shape; no plans, no forced full counts.
   Dashboard function logs should showdirect_generation anddirect-v2for one call.
4. Using existing usage-ledger inspection, confirm matching terminal request status.
   Accepted partials may be200/success with missing counts; failures must finalizefailed.
   Busy/offline/provider errors retain sanitizedcodes; do not repeatedly resend. Existing
   denied/student/locked/foreign-class cases must refuse before provider invocation;
   overlapping request must retainAI_IN_PROGRESS. These are covered by mocks; live checks
   remain owner's choice under existing accepted scope, not a request to redo prior suites.
5. For M10-BE-03retain TXTresults and historical findings. Select/provide the remaining
   four authorized student-data-free materials and DEVresults at3difficulties; confirm
   photo extraction capability or explicitly waive/block that slot. Give actual manual
   scores/owneracceptance separately; no automatic completion or fabricated sample output.

2026-10-29 owner DEV Easy: HTTP 200, 11/11 (6/2/2/1), no reported drops/missing; required essay metadata and 5-point rubric present. See docs/ai-quality-check.md and qa/TEST_ACCEPTANCE.md. Revision/call-count logs and terminal ledger evidence still pending; no new mock Pass or quality score inferred.
