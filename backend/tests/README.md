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
