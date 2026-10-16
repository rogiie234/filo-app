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
