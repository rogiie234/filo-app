# Gradebook backend contracts ? 2026-10-18

Prepared locally; migration deployment, SQL acceptance and dev timings are pending owner execution. The canonical existing RPC reference remains [docs/API_CHANGES.md](../docs/API_CHANGES.md).

## Gradebook query shapes

Use verified instructor requests and RLS; never a service key on the frontend. Load a class once with these four reads, not one request per cell. In the shapes below, CLASS_ID and ASSIGNMENT_IDS are bound values from the selected class. Paginate all results (including submissions and grades) beyond the server row cap; do not silently total partial pages. Refresh after Save/Return; preserve ungraded cells as null/dash rather than zero.

```text
class_members
 select student_id,status,profiles!class_members_student_id_fkey(display_name,avatar_path)
 eq class_id CLASS_ID; in status [active,left,removed]; order student_id
posts
 select id,title,points,due_at,created_at
 eq class_id CLASS_ID; eq kind assignment; is deleted_at null
 order created_at desc,id
submissions
 select id,post_id,student_id,status,submitted_at,is_late
 in post_id ASSIGNMENT_IDS; eq status turned_in; order id
submission_grades
 select submission_id,score,feedback,graded_at,returned_at,
        submissions!inner(post_id,status,posts!inner(class_id,kind,deleted_at))
 eq submissions.posts.class_id CLASS_ID
 eq submissions.posts.kind assignment; is submissions.posts.deleted_at null
 eq submissions.status turned_in; order submission_id
```

Resolve roster profiles with the explicit student foreign key (class_members also references decided_by). Retain former-member rows for historical grades; pending/declined requests are not enrolled roster entries. Student reads remain own returned grades only, with active membership required by existing lifecycle RLS. Never join grade contents into a student cache before Return. An instructor sees turned-in submissions only.

The rollback seed [seed/gradebook_40x10.sql](seed/gradebook_40x10.sql) contains SQL equivalents for measuring all four reads under authenticated owner RLS, including join and policy cost. Expected candidate indexes already exist: idx_members_class, profiles_pkey, idx_posts_class / idx_posts_due, idx_submissions_post and submission_grades_pkey. Inspect EXPLAIN ANALYZE actual plans and Execution Time, target <1,000 ms per query. SQL joins and PostgREST embedding may plan differently: measure frontend-generated queries too when integrated. A sequential scan on 400 rows can be appropriate; do not force index use. No new index is justified without dev measurements. Report all four times and plans before accepting M5-BE-02.

## Grading guard correction

Migration `20261018120000_grading_guards.sql` preserves RPC signatures: `save_grade(p_submission uuid,p_score integer,p_feedback text default null)` returns submission_grades; `return_grades(p_ids uuid[])` and `return_all_graded(p_post uuid)` return actual changed count. Null, negative and above-points scores are refused. Draft/deleted/non-assignment work cannot be saved; Return excludes drafts, unsaved/null scores, previously returned grades, deleted posts and closed classes. Save updates the same primary-key row and preserves returned_at, so edits after Return stay visible without another inbox row. Submission locks serialize Save/Return with unsubmit.

`return_grades` receives submission IDs, not grade IDs or post IDs. IDs belonging to another instructor are ignored. It has no class parameter: an owner supplying IDs across two of their own classes can return both. The frontend must send only selected-class IDs; use return_all_graded(p_post) for assignment scope. Changing this legacy signature requires a separate contract decision.

## Missing-work scoring (M5-SA-01 accepted by owner)

New migration `0011_grade_missing.sql`: `grade_missing(p_post uuid, p_student uuid, p_score integer, p_feedback text default null)` returns `submission_grades`. Verified class owner only; open class, live assignment, server time strictly after due_at, enrolled/former membership (`active`, `left`, `removed`), integer 0..points. Pending/declined/nonmembers and already turned-in work are refused. This is an explicit instructor action, never automatic zero.

Creates a submission or converts a draft to `status=turned_in`, `submitted_at=null`, `unsubmit_until=null`, `is_late=false`, no comment or item metadata. Draft item metadata is discarded to avoid exposing unfinished private contents; SQL does not remove Storage blobs, which remain for class purge. Confirm conversion in the grading UI before calling. Calls save_grade for the same score/feedback rules. Save remains hidden until Return; returned rows count as graded by non-null returned_at, even without submitted_at. Existing policies and turn_in/unsubmit guards lock student changes. Former members retain records for instructor history but cannot see class grades until active membership is restored, per existing lifecycle policy.

On uncertain outcomes, refresh the post/student submission and grade first. Repeating grade_missing after success is refused as already turned in; edit via save_grade using the resulting submission ID. Apply migrations with your existing migration-history workflow: 0011 is deliberately the requested version and sorts before timestamped versions, so existing dev history may require the CLI include-all option. Do not rename or edit applied files. Neither migration has been applied here.


## M6 materials download and incremental pull contract - 2026-10-18

Prepared source only. No migration application, SQL, HTTP, device test or timing was run.

### Signed materials downloads

Use the existing Supabase Storage API, not a new database RPC:

```dart
final url = await supabase.storage.from('materials')
    .createSignedUrl('$classId/$postId/$fileName', 3600);
```

Lifetime: **3,600 seconds (60 minutes)**. Sign only when downloading; never persist signed URLs as attachment paths. REST equivalent: `POST /storage/v1/object/sign/materials/CLASS_ID/POST_ID/FILE` with project API key, verified user's `Authorization: Bearer JWT`, JSON `{"expiresIn":3600}`. Resolve returned relative `signedURL` against the project's `/storage/v1` base. GET that URL for the bytes. Use ordinary user JWTs, never service_role. Pending/removed/left/non-members cannot mint links. Existing valid URLs remain bearer capabilities until expiry, including after membership revocation; possession is sufficient to download. An expiry failure requires rechecking current access and requesting a new URL, then retrying once; permission denial must stop retrying. Offline: keep local downloads available and defer new downloads until connected.

### Incremental pulls

Apply `20261018130000_sync_pull_support.sql` on DEV after existing migrations. Adds full `(updated_at, primary_key)` indexes, server INSERT timestamps, notification read-mark timestamps and active-member class-tombstone visibility. Existing BEFORE UPDATE triggers already replace timestamps with server `now()` (transaction time); phone clocks never choose the watermark. Do not send updated_at in writes. This migration does not replace frontend full-refresh loaders or implement a sync worker.

Maintained SQL shapes: [tests/sync_pull_queries.sql](tests/sync_pull_queries.sql). **200 rows per page**. All ordering is explicitly ascending. Use each table's own watermark and persist the complete timestamp without rounding to milliseconds. First page uses `updated_at >= LOWER`; next pages add `(updated_at, PK) > (CURSOR_TIME, CURSOR_ID)`, keeping LOWER fixed. PK is `submission_id` for submission_grades and `id` elsewhere. Do not use offset or updated_at-only paging: more than 200 equal timestamps would otherwise skip or repeat forever.

PostgREST equivalent for subsequent pages (encode bound values):

```text
/rest/v1/posts?select=*&updated_at=gte.LOWER
 &or=(updated_at.gt.CURSOR_TIME,and(updated_at.eq.CURSOR_TIME,id.gt.CURSOR_ID))
 &order=updated_at.asc,id.asc&limit=200
```

Omit `or` on the first page. Keep RLS and scope filters on every page. Never add `deleted_at=is.null` to a delta read. Upsert by PK, apply tombstones locally, and atomically commit each page and cursor. After the final empty page, save the maximum received timestamp as the next LOWER and restart inclusively next cycle (upsert duplicate IDs). On failure retain last committed cursor and retry; do not advance a failed page or erase usable offline data. Account switch uses separate caches/watermarks.

Timestamp ties are handled by the PK cursor, but timestamp polling is not a commit-ordered change feed: a long transaction can commit an older `now()` after a cursor has passed it, and RLS visibility can change without touching child timestamps. Reconcile full visible snapshots on join/approval, Return/results release, access changes and periodically; reset relevant cursors. On removed/left membership or a class tombstone, evict cached class content and stop pulls for that class. Physical deletion also needs snapshot reconciliation (class purge after 14 days). No claim of exactly-once or lossless concurrent transaction delivery.

Coverage: profiles, device_tokens, notification_settings, classes, class_members, posts, post_attachments, submissions, submission_items, submission_grades, quizzes, questions, exam_sessions, exam_answers, bank_questions, notifications. RLS still limits which caller can read each (exam tables remain instructor-only; students use existing exam RPCs). Read question_options as a complete instructor-owned snapshot with questions; it lacks updated_at and tombstones. Answer keys remain instructor-only snapshot/RPC data. second_chances is an append-only instructor audit snapshot. leave_events, OTP/session records and ai_usage_log are not phone pull tables. Hard-deleted device/settings/notification rows require snapshot reconciliation. Do not expose answer keys or server-only tables to make generic sync work.

### Conditional Drive handoff

M6-SA-01 retention is not recorded; enablement is pending that decision and owner project access. No Android authorization or backup uploader exists in inspected source. If retained: request `https://www.googleapis.com/auth/drive.file` only when backup is enabled, create a normal Drive folder `Filo Backup`, store its per-account ID, and use Drive v3 `files.create` resumable uploads. Google access token is distinct from the Supabase JWT. Do not broaden scopes or put tokens/session URLs in logs. See decisions.md for setup and verification limits.


## M6 Drive implementation handoff - 2026-10-18

Supersedes the earlier conditional/absent implementation note: owner explicitly retained Drive backup and authorized implementation. Source is now under frontend/lib/features/drive_backup, reachable from the account avatar menu. No new Supabase endpoint, SQL migration, server-held Google credential or service account is used. Cloud Drive API enablement/consent changes and owner runtime acceptance remain pending.

- Folder: Filo Backup; scope: https://www.googleapis.com/auth/drive.file; one-way selected-file backup.
- Authorization: native GoogleSignIn7.2 authorizationClient.authorizeScopes on enable; noninteractive authorizationForScopes on retries; same Google email as Filo login plus persisted Google ID. A Supabase bearer JWT is never a Drive API credential.
- REST: GET /drive/v3/files/generateIds; GET /drive/v3/files/ID for reconciliation; POST /drive/v3/files for folder; POST /upload/drive/v3/files?uploadType=resumable for new files; PATCH same-ID upload endpoint when restarting an existing incomplete file; PUT session Location with Content-Range.1MiB chunks,308 Range resume,404/410 session restart,200/201 completion followed by size/MD5 validation. Persist generated IDs before remote creation to avoid uncertain-response duplicates. No broad Drive listing or scope expansion.
- Dedicated durable local backup outbox: account SQLite v3 drive_backup_settings/drive_backup_jobs; encrypted per-account session URLs via FlutterSecureStorage. Foreground reconnect/resume/minute retries; OFF pauses pending jobs and keeps Drive copies. Wi-Fi-only defaults ON and also applies to manual Retry. Completion deletes only private queue snapshots, not selected source files. Last success is selected-queue completion, not full-library backup.
- Existing Class Files remains sample-only, so choose real local files through the Android system file picker. DriveBackupService.enqueue(File,name) is the future local-file-library integration point. Completed content is deduplicated within an account. No full-download-library/background-terminated upload/restore behavior is claimed.
- Google Cloud project filo-app-58815 still needs Drive API enabled and drive.file declared under Data Access, with configured audience/test users. Basic/non-sensitive scope verification guidance and precise app-created-or-explicitly-shared scope semantics are recorded in docs/decisions.md. Owner checks include small and20MiB uploads, interruption/resume/dedupe, permission revoke/deny, Wi-Fi preference, account isolation and unrelated Drive-file denial. No assistant tests, builds, analysis, live calls or timings.


## M6 storage/sync acceptance update - 2026-10-18

Owner explicitly accepted M6-BE-01 and M6-BE-02 in full, including previously pending full-table/performance acceptance. Both have status **Complete - accepted**. Earlier prepared/pending statements are historical for those tasks; no unexecuted cases or unmeasured performance numbers are represented as verified. M6-BE-03 Drive Cloud setup/runtime acceptance remains separate and pending. See docs/decisions.md for evidence and limits. No assistant tests or remote actions.


## M7 quiz builder backend - 2026-10-20

Status: PREPARED; not deployed or executed. M7-SA-01 owner accepted retaining the question bank and prohibiting deletion after a student starts. M7-BE-01/02/03 and quiz security checklist items 2/5 remain pending owner DEV results.

Apply, in order, after the existing repository migrations:
1. `20261020100000_quiz_publish_security.sql`
2. `20261020110000_atomic_questions_and_bank.sql`

### Atomic question RPCs

`save_question(p_quiz uuid, p_question jsonb) -> jsonb`, authenticated verified owning instructor only, on a nondeleted quiz in an active class with `locked_at IS NULL`.

```json
{
  "id": null,
  "type": "multiple_choice",
  "prompt": "Which answer is correct?",
  "points": 1,
  "explanation": null,
  "position": 0,
  "options": ["First", "Second"],
  "correct_option_index": 1
}
```

- Required common fields: `type`, nonblank string `prompt` (max 1000 characters), integer `points` (1?1000), and integer `position` (0?2147483647). Optional `explanation` is null or a string of at most 500 characters. Text is preserved, not truncated.
- `id` omitted/null/empty creates a database UUID. A supplied UUID must already belong to this quiz; it never creates a row with a client-supplied ID or moves a question.
- Multiple choice: `options` contains 2?10 nonblank text strings, each max 500 characters; `correct_option_index` is a zero-based integer selecting exactly one option.
- True/false: `correct_boolean` must be a JSON boolean, including `false` (not the string `"false"`).
- Identification: `accepted_answers` contains 1?10 nonblank text strings. No new per-answer character cap is imposed. Existing grading normalization is unchanged.
- Essay needs no key. Irrelevant type-specific payload fields are ignored; the saved rows contain only the selected type's options/key.
- Return: `{"question_id":"UUID","option_ids":["UUID", "UUID"]}`. Option IDs follow input order, or `[]` for non-MC. An edit preserves the question ID and `ai_generated`, replaces all option IDs and the key, and clears obsolete type data. A failed call rolls back rows, IDs, keys, totals and essay flag together.

`reorder_questions(p_quiz uuid, p_ordered_ids uuid[]) -> void` has the same authorization/state checks. Supply every current question ID exactly once, without foreign IDs, duplicates, null elements or multidimensional arrays. Empty array is valid only for an empty quiz. Positions become 0..N-1 atomically; null input is invalid.

New RPC errors: `42501` for authorization/inaccessible/archived/deleted quiz; `22023` for invalid input, foreign question ID, invalid permutation or locked state. Internal validators/lock helpers have no client EXECUTE grant. Neither RPC is granted to anon. Existing publish error messages/signature remain intact; repeat publication returns the existing row without new notifications.

### Edit/deletion/security changes

Publishing and first start lock the parent quiz row; content triggers, atomic saves, reordering and direct soft deletion serialize against it. A publish on a deleted/inaccessible quiz is refused. Only active class members receive inbox rows; this does not guarantee push delivery. Question moves check both parents and refresh both totals. Options/keys cannot be reparented. Option/key guards pin their question rows before resolving parents.

After a start, instructor edits to questions/options/keys, instructions, type, time limit, opens, both shuffles, show-answers, passing percentage and `deleted_at` are refused (`22023`). Title and a closing time satisfying the existing window constraint remain editable. Drafts and published quizzes without starts can still be soft-deleted. No new instructor hard-delete grant is added. Server lifecycle/result updates and class purge remain permitted.

Clients should refetch after an uncertain response before creating another new question: an empty-ID save is not an idempotency-key API. `40P01`/`40001` mean the transaction aborted and may be retried as a whole after refetch; do not repeat only the options/key portion. Do not queue quiz authoring/submission offline. Existing direct draft-table grants remain for compatibility, with strengthened locks; the app should use `save_question` for atomic writes.

### Question-bank stored shape

- MC: `options = [{"text":"First","is_correct":false},{"text":"Second","is_correct":true}]`, exactly one correct flag; `answer = null`.
- True/false: `options = null`, `answer = {"boolean":false}`.
- Identification: `options = null`, `answer = {"accepted":["Answer","Alternative"]}`.
- Essay: `options = null`, `answer = null`.

Verified instructors can operate only on their own rows. Deletion is `UPDATE deleted_at`; client hard DELETE is revoked. Own tombstones remain selectable for synchronization. Content writes validate the same prompt/points/explanation/type limits as atomic saves and clear unused options/answer fields. Pure tombstone updates remain possible for legacy rows without rewriting malformed old content. No bulk rewrite of existing bank data occurs.

To copy: map option texts in array order and locate the true flag as `correct_option_index`; map `answer.boolean` to `correct_boolean` or `answer.accepted` to `accepted_answers`. Omit the bank ID from the new-question payload. Copies get independent question/option IDs and no bank foreign key. Later bank edits/deletion cannot modify quiz copies.

Owner execution: `backend/tests/quizzes.sql`, `backend/tests/question_bank.sql`, and the selected blocks in `backend/tests/quiz_concurrency.sql`. See `backend/tests/README.md` M7 instructions. No migration application, test execution, remote ledger verification, checklist acceptance or runtime success is claimed here.


## M7 question-delete cascade correction - 2026-10-20

Prepared migration `20261020120000_quiz_question_delete_cascade.sql`, after the two initial M7 migrations. No RPC signature/grant or table shape changes.

The existing lifecycle guard resolves options/keys through their parent question. During FK cascade deletion the parent is already absent, so an authenticated instructor's question DELETE can be refused. guard_question_edits now validates/locks the parent quiz, deletes the answer key then options in BEFORE DELETE while the question is visible to child RLS/lifecycle guards, and allows the parent deletion. These writes are one atomic SQL statement; a failure rolls them all back. Existing owner, archived/deleted class and locked-quiz checks remain. Server purge remains supported; no trigger-depth/GUC bypass or weakened access policy is introduced.

Owner reported quiz summary 193 PASS / 9 FAIL; first failures remove incomplete MC/TF/identification, followed by publish/inbox/student-start failures. Source establishes the cascade defect; exact remote error details were requested and runtime correction remains unverified. Apply only this new pending migration if the earlier two are already applied, then run the ENTIRE latest quizzes.sql. The script requires this guard and adds per-type parent-and-child deletion assertions. All M7/checklist acceptance remains pending. Assistant did not apply migrations or execute tests.


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

## 2026-10-24: Additive save_answers RPC

`20261024100000_exam_answer_batches.sql` adds `save_answers(uuid,jsonb) -> jsonb`,
EXECUTE authenticated only, with verified caller/session ownership/class/deadline checks
and a session lock. Accepts1-20 distinct question IDs and positive local revisions,
returns per-answer save timestamp/error receipts with echoed revisions. Reuses
`save_answer`, retaining its fields/limits/upsert/deadline behavior. Item validation
failures are isolated; session/access and unexpected errors roll back the whole call.
Legacy RPC remains unchanged, no table or policy additions. Full wire contract is in
`docs/API_CHANGES.md`. Deploy before updated client. Rollback-only maintained regression:
`backend/tests/exam_answer_batches.sql`. Prepared, not deployed or executed by assistant.

## 2026-10-24: Owner accepted exam refinement and batch-save runtime

Owner explicitly accepts all runtime checks for the exam refinement, batched saves,
rapid-answer saving and final diagnostic cleanup. Owner supplied84PASS/0FAIL for the
exam suite before the two later rapid regressions; no later automated count inferred.
Supplied SQL Editor success and healthy50-answer save capture are owner evidence.
No assistant test/SQL/build/static analysis/live/device rerun or independent migration
ledger verification. Temporary diagnostics removed; maintained regressions retained.

## M9-BE-03 - automatic results release wait (2026-10-25)

Owner reports successful DEV application of `20261024110000_exam_release_wait.sql` and results SQL summary 249 passed, 0 failed, overall PASS, failures [] on 2026-10-25. Owner-reported unattended HOLD PASS, final PASS and fixtures_removed=true accepted; requested backend DEV task complete; no assistant execution or independent remote migration inspection. Owner confirms M9-SA-01 accepted this wait. No public RPC signature, return shape, permission, table or scheduler changes.

`maybe_release_results(uuid)` now holds the open-quiz everyone-submitted path until 10 minutes after `max(submitted_at)` across non-voided submitted/auto-submitted attempts. The single function constant is `v_release_wait_minutes := 10`. A missing qualifying timestamp keeps the open quiz unreleased. Auto-submission retains its existing deadline-based submitted_at; the wait is measured from that timestamp, not worker execution or essay grading.

All active students must still have a qualifying attempt; no attempt may be in progress and grading must be complete. Granting a second chance voids the old attempt and blocks open-quiz release until the replacement is submitted. Submitting the replacement starts a fresh 10-minute wait; grading does not restart the timer or bypass it. Voided history is excluded from the timestamp calculation.

Closing time bypasses only the wait, preserving progress/grading checks. Manual `release_results` retains its checks and closes the quiz before using the shared function, so it also bypasses the wait. Existing notifications and unreleased-score privacy are retained. The existing one-minute `filo-finalize-exams` job calls `finalize_expired_sessions()` then `release_ready_results()` even without newly expired sessions: release is eligible on the first successful tick at/after the wait ends, normally within another minute. Scheduler failures can delay it; no app action is required.

Maintained owner-run proof: `tests/exam_results.sql` covers the boundary, replacement submission, grading, privacy, missing timestamp, closing/manual bypass and idempotency. `tests/exam_cron_setup.sql` / `exam_cron_inspect.sql` now require saved HOLD PASS evidence before eligibility and final PASS after the wait with successful cron and the correct unique inbox row. Use the existing guarded cleanup. Prior M9-BE-02 acceptance does not establish acceptance of this change.

### M9-BE-03 owner unattended hold/release PASS

Owner supplied HOLD PASS then unattended PASS on 2026-10-25: reserved session 8b020000-0000-4000-8000-000000000006 auto_submitted, score7, grading complete, submitted_at=deadline_at=2026-10-25T05:04:15.765408Z. Early observation had null release and no inbox with successful expiry cron. Eligibility was 05:14:15.765408Z; release occurred 05:15:00.057649Z (13:15:00.057649 Philippine time), 44.292241 seconds after eligibility, with successful_cron_after_wait=true and correct_release_inbox=true. Confirms owner-reported unattended hold and release on the next minute tick; initial WAIT preceded finalization and was followed by HOLD PASS. Together with applied migration and SQL249PASS/0FAIL, only guarded fixture cleanup remains pending. No assistant execution or independent remote verification.

### M9-BE-03 complete - owner cleanup accepted

M9-BE-03 COMPLETE for requested backend DEV scope on owner evidence (2026-10-25): migration 20261024110000 applied successfully; results SQL 249 PASS / 0 FAIL, overall PASS, failures []; unattended HOLD PASS before eligibility followed by release PASS 44.292241 seconds after eligibility with successful cron and correct unique inbox; guarded cleanup fixtures_removed=true. Supersedes all earlier pending migration/SQL/cron/cleanup statements for this task. No repeat checks needed absent a change or defect; no assistant test/SQL/live execution or independent remote verification, broader frontend/device/offline/concurrency acceptance not inferred.


## M9-BE-04 score override - prepared 2026-10-25

Owner explicitly confirmed M9-SA-01 acceptance for score overrides. New migration
`20261025100000_exam_score_override.sql`; DEV application and owner acceptance pending.

- RPC: `override_points(p_session uuid, p_question uuid, p_points integer, p_feedback text default null) returns void`.
  Supabase payload keys are `p_session`, `p_question`, `p_points`, `p_feedback`.
- Requires a verified authenticated class owner; other instructors, students and anonymous callers cannot override.
  Existing class write guards continue to reject archived/inaccessible classes.
- Session must be submitted or auto_submitted; voided/in-progress attempts are refused.
  The question must belong to the session's quiz. All four question types are supported.
- Points are non-null integers from zero through question.points. Fractional input is invalid for the integer RPC
  parameter; callers must not round/cast fractions before sending them. SQL numeric-to-integer casts can round
  before this function is invoked and cannot preserve the original fractional input.
- Feedback is nullable, at most 2000 characters; oversized feedback is rejected (unlike grade_essay's existing truncation).
  Omitting feedback clears it. Validation failures roll back the whole call.
- Upserts an unanswered question, or updates only points_awarded, is_correct, feedback, graded_by and updated_at
  on an existing answer. Student response fields and answered_at are preserved on updates. For a newly created
  answer, response fields remain null and answered_at uses the existing insertion default; it is not proof of student input.
  graded_by records auth.uid(); is_correct is true exactly at full points, including essays.
- Recalculates auto_score/essay_score/generated total_score and grading_complete, then checks existing release
  eligibility. The accepted 10-minute wait is unchanged; already-released results show the corrected total without
  another release notification. Retrying an identical request preserves one answer and the same score.
- grade_session skips answers with graded_by set, retaining automatic grading for all other non-essay answers.
  override_points, grade_session and grade_essay lock the session before answer writes/recalculation. Existing
  grade_essay signature, permissions, feedback truncation and null is_correct behavior remain unchanged.
- No new columns, UI, audit history, result notification type or scheduler. Latest manual grade wins; an explicit
  later grade_essay call can replace an essay override. Maintained coverage: backend/tests/exam_results.sql (M9D).

No assistant tests, SQL execution, live verification, analysis or builds. DEV migration/runtime/concurrency acceptance pending owner checks.


### M9-BE-04 owner-reported SQL PASS - 2026-10-25

Owner supplied results summary: passed=299, failed=0, overall=PASS, failures=[]. Records owner-reported SQL regression acceptance for the updated maintained exam_results.sql, including M9D override cases. Supersedes SQL-run-pending wording above; no passing SQL rerun requested absent a new change or defect. Migration application/ledger confirmation, separate two-connection concurrency and fractional JSON/transport-retry checks have not been supplied; overall task acceptance remains pending those owner checks. No assistant tests, SQL, live verification, static analysis or builds, and no frontend/offline acceptance inferred.


### M9-BE-04 owner migration ledger confirmed - 2026-10-25

Owner supplied successful `npx.cmd supabase migration list --linked` output showing local and remote versions matched through 20261025100000 (2026-10-25 10:00:00 UTC), including all prior listed migrations. Records owner-supplied linked migration ledger evidence for the score override migration; no assistant remote inspection. Together with SQL299PASS/0FAIL overallPASS failures[], migration and maintained SQL acceptance are recorded. Separate two-connection concurrency and fractional JSON/transport-retry evidence remain pending; do not rerun the passing SQL suite absent a change or defect. No assistant tests, SQL, live checks, analysis/builds or Git mutations.


### M9-BE-04 COMPLETE - owner DEV evidence, 2026-10-25

Requested backend DEV scope accepted on owner evidence: linked migration ledger matched through 20261025100000; maintained results SQL299PASS/0FAIL overallPASS failures[]; override-first grading call elapsed19.09s and reverse-order override elapsed19.03s, consistent with session serialization. Both orderings retained points1/is_correct=false, the owning instructor graded_by and correct feedback; auto_score1/essay_score0/total_score1 matched independent sums. Owner showed both identical valid HTTP calls succeeded; subsequent fractional JSON p_points1.5 returned HTTP400, followed by answer points1/is_correct=false/feedback HTTP retry check and unchanged total1. The HTTP response body was empty, so no exact SQLSTATE/error-message attribution is claimed. Repeated HTTP calls prove identical retry behavior, not an independently observed dropped response. Supersedes prior pending migration/SQL/concurrency/HTTP acceptance wording for requested scope; do not rerun passing checks absent a change or defect.

No assistant tests/SQL/live verification/static analysis/builds. No frontend override UI/offline integration, broader load/concurrency or independent remote inspection claimed. No disposable materials created, staged, committed or pushed; owner-created app test attempt is retained without deletion. Background Schema and decisions remain ignored local docs; Graphify artifacts are outside app Git, and prior canonical semantic-source blockers remain.
# M10-BE-01: `ai-generate-quiz` — 2026-10-26

## Provider diagnostics — 2026-10-27

### Bind provider output positions to type counts — 2026-10-27

Owner received one valid essay with three essay candidates dropped and the three other
types missing. A per-item anyOf allowed the provider to choose essay for every slot;
the validator correctly retained at most the requested essay count. Replaced the union
with request-specific prefixItems: one typed schema for each requested position, in
multiple_choice/true_false/identification/essay order, repeated by requested count.
maxItems equals requested total, not20 for every request. A single-type regeneration
therefore has only its own one-item schema. Prompt mirrors this order explicitly.
No minimum count is forced, preserving empty/partial output for unsupported sources;
server still validates each returned question/count and never changes its type to
fill a slot. Existing response API/retry/authorization/privacy rules unchanged.
Google documents prefixItems support: https://ai.google.dev/api/generate-content
Maintained mixed/zero-count/regeneration/20-slot schema assertions added; no assistant
tests, analysis, builds, live calls, deployment or secrets. Owner four-type acceptance
still pending.

### Require MC indexes in provider schema — 2026-10-27

Owner fixed log invalid_correct_index identifies dropped MC candidates with absent,
noninteger or out-of-range correct_index. Flat provider schema made the field optional
for every type. Replaced that with a small per-type anyOf union: MC requires options
and integer correct_index0-9, TF requires its boolean, identification its answer list,
and essay has no answer properties. Distinct leading properties separate the variants;
additionalProperties=false prevents cross-type keys. Avoided string limits and nested
array-size constraints in provider schema to keep complexity down; server still enforces
2-10 options and correct_index strictly less than actual options length. Prompt explicitly
maps first/second/third/fourth to0/1/2/3 and prohibits strings, letters, null and arrays.
No guessed key, one-based conversion or weakened validator. REST APPLICATION_JSON enum
retained. Mocked wire and missing/string/null/negative index regressions updated; no
assistant tests, analysis, builds or live calls. Owner tests/deploy/four-type request
pending; no API response, dependency, database or secret changes.

### Dropped-question diagnostics — 2026-10-27

Owner supplied13 passing focused tests and successful real Gemini output (TF,
identification, essay), first with one MC candidate dropped and then two MC candidates
dropped using richer source; one requested MC still missing. Provider response now
succeeds, but full four-type acceptance remains pending. Added fixed server-only
`ai-generate-quiz: question_dropped <recognized type> <fixed reason>` diagnostics.
Reasons distinguish unused null/other answer fields, wrong_index_field, unknown_fields,
invalid_prompt/explanation/points, options_not_array, invalid_option_count/text,
duplicate_options, invalid_correct_index, invalid_boolean/accepted_answers,
duplicate_prompt and excess_type. No unexpected field names, question text, answer,
explanation, source, caller identifiers or raw candidate is logged. Existing rejection
rules, returned objects, counts and partial-result/retry policy are unchanged; no
invalid question is accepted to fill a quota. Maintained exact-log privacy test added.
No assistant tests, analysis, builds, live calls, deployment or secrets changed.
Owner must rerun focused tests, deploy and repeat the four-type request once, then
inspect the fixed multiple_choice drop reason if MC remains missing.

### REST output MIME enum correction — 2026-10-27

Owner provider400/schema_rejected persists with the simplified schema. The REST
reference defines responseFormat.text.mimeType as the MimeType enum with value
APPLICATION_JSON, while the implementation sent application/json copied from the
tutorial example. Corrected only that provider enum value; the HTTP Content-Type
header remains application/json. The schema, validators, public result and error
contracts remain unchanged. Maintained mocked wire assertion checks both values
separately. Reference: https://ai.google.dev/api/generate-content#MimeType
This identifies a concrete reference mismatch, not yet a verified runtime root cause.
No assistant tests, static analysis, builds, live calls, deployment or secrets.
Owner focused test rerun, deployment and real request remain pending.

### Simplified provider schema — 2026-10-27

Owner reported fixed category schema_rejected for HTTP400. Replaced the provider-facing
four-variant anyOf schema with a flat array-of-question-objects schema using basic
types, type enum, common required fields and optional per-type answer fields. Removed
provider string/numeric limits and additionalProperties, keeping all strict limits,
cross-type/unknown-field rejection and answer validation in validateQuestion unchanged.
Prompt explicitly states every length/point limit and requires unused fields to be
omitted, never null. No API response or persistence change, JSON-only downgrade,
automatic model fallback, dependency or database migration. Existing malformed-output
regressions continue to cover boundary validation; mocked request assertions now check
the flat provider schema and absence of unions/string constraints. Owner deploy and
real generation pending; no assistant tests, analysis, builds, live calls or secrets.
Classification identifies a schema-related rejection, not its exact unsupported keyword.

### Sanitized HTTP400 rejection classification — 2026-10-27

Owner still reports provider_http400 after the current request-format update, so its
root cause is not established. On HTTP400 only, read at most16,384 response bytes for
at most3 seconds within the existing provider deadline. Inspect the error in memory
and log only `ai-generate-quiz: provider_rejection` plus one fixed category:
`api_key_invalid`, `key_or_project_restricted`, `free_tier_unavailable`,
`request_field_unsupported`, `schema_union_ordering`, `schema_complexity`,
`schema_rejected`, `model_unsupported`, or `unclassified`. Never log the raw error,
response body, reason/metadata values, key, model value, prompts, sources or answers.
Classification is a diagnostic hint based on recognized reasons/wording, not proof
of root cause. Malformed, oversized, unreadable or unrecognized errors classify as
unclassified without changing the existing AI_UNAVAILABLE response or retry policy.
Maintained classification/privacy regressions prepared; no assistant tests, analysis,
builds, live calls, deployment or secrets changed. Owner must redeploy and repeat one
real request, then inspect the new fixed category before changing configuration.

### Current structured-output request format — 2026-10-27

Owner reported provider_http400 after selecting Flash-Lite. Source inspection found
the provider request still used the older responseMimeType/responseJsonSchema fields.
Updated generationConfig to the current documented REST shape:
`responseFormat: {text: {mimeType: "application/json", schema: <existing schema>}}`.
The same JSON Schema, independent output validation, privacy boundaries, response
shape, error mapping and retry policy remain in force. Maintained mocked-provider
assertions now require the current shape and absence of both older fields. Reference:
https://ai.google.dev/gemini-api/docs/generate-content/structured-output?hl=en
No assistant tests, static analysis, builds, provider calls, deployment or secret
updates. Owner redeployment and real-request acceptance pending; HTTP400 alone does
not establish that the older fields were its sole cause.

Owner supplied real-mode AI_UNAVAILABLE followed by sample-mode success using the same
request. This confirms the sample authorization/validation/begin/finish path for that
run, not a successful Gemini call. Provider/configuration cause remains unknown.
Added fixed server-log events `ai-generate-quiz: missing_api_key`,
`missing_or_invalid_model`, `provider_http` (numeric HTTP status only), and
`provider_transport_failure`. No key/model value, URL, caller identifier, prompt,
source, answer, response body, headers or raw exception is logged. Client error shape
and usage error codes are unchanged. Maintained regression asserts exact diagnostic
arguments using private sentinel inputs. No assistant tests, builds, static analysis,
live calls, deployment or secret changes. Owner must deploy, set AI_TEST_MODE=off,
repeat the failed request and inspect the function Logs for these events. HTTP400
means provider request rejected (key or payload/schema may be involved);401/403 means
authentication/access rejection;404 means model/endpoint unavailable;429 and overload
statuses retain AI_BUSY. Do not infer a precise root cause from HTTP status alone.

Implementation prepared; owner tests and real-provider acceptance pending. No deployment,
secret changes, automated tests, static analysis, builds or live API checks were run.
No schema changes. Existing `begin_ai_request` and `finish_ai_request` remain service-only.

## Call and authorization

`POST /functions/v1/ai-generate-quiz`, headers `Authorization: Bearer <access_token>`,
`apikey: <project publishable key>`, `Content-Type: application/json`.
The function authenticates tokens itself (`verify_jwt=false`); this does not make it
anonymous. It checks token, verified session/user pair, active instructor profile,
owned non-archived/non-deleted class, then an unlocked/non-deleted quiz in that class.
Denied access returns `NOT_ALLOWED` before acquiring a slot or contacting Gemini.
Malformed identifiers return `INVALID_REQUEST`; database availability failures return
`AI_UNAVAILABLE`, rather than pretending the caller lacks permission. OPTIONS returns
204; non-POST methods return 405/`INVALID_REQUEST`.

```json
{
  "class_id": "<owned-class-uuid>",
  "quiz_id": "<quiz-uuid-in-that-class>",
  "texts": [{"file_name": "biology.txt", "text": "Plants use sunlight for photosynthesis."}],
  "counts": {"multiple_choice": 1, "true_false": 1, "identification": 1, "essay": 1},
  "difficulty": "easy",
  "topic_focus": "photosynthesis"
}
```

All four count keys are required; unknown count keys are invalid. Counts are integers
0–20 with total 1–20. Difficulty is `easy|medium|hard`. Topic focus is optional,
at most 200 Unicode code points. Source array has at most three entries; filenames
are nonblank strings up to 255 code points, used only for input validation, never sent
to Gemini. Text must be a string. Empty/whitespace-only combined sources give `NO_TEXT`.
Shared source limit: 40,000 code points, counting original text before trimming;
no silent truncation. Request body limit: 524,288 UTF-8 bytes. These are separate limits.

Regeneration adds `"mode":"regenerate"`, `"type":"essay"`, and
`"current_prompts":["Question being replaced", "Other existing question"]`, with counts
`{"multiple_choice":0,"true_false":0,"identification":0,"essay":1}` for that example.
Provide the original source texts or one replacement text entry in `texts`; source
text is never retained server-side. There is no second text-list key or source lookup.
Comparison list: 1–100 nonblank strings, each at most 1,000 code points and at most
40,000 code points combined. Include the replaced question and all existing prompts.
Type and difficulty are supplied by the caller; the function cannot infer the selected
question from an ID. Generation mode is omitted or `generate`; comparison fields are
rejected outside regeneration. Existing questions are never deleted or persisted here.

## Success contract

HTTP 200:

```json
{
  "questions": [
    {"type":"multiple_choice","prompt":"Which resource supplies energy for photosynthesis?","points":1,"explanation":"The source identifies sunlight.","options":["Sunlight","Sound","Wind","Soil"],"correct_index":0},
    {"type":"true_false","prompt":"Plants use sunlight for photosynthesis.","points":1,"explanation":"This is stated in the source.","correct_boolean":true},
    {"type":"identification","prompt":"Name the process described in the source.","points":1,"explanation":"Plants use sunlight in this process.","accepted_answers":["photosynthesis"]},
    {"type":"essay","prompt":"Explain the connection between sunlight and the process described.","points":1,"explanation":"Focus on the relationship stated in the source."}
  ],
  "dropped_by_type":{"multiple_choice":0,"true_false":0,"identification":0,"essay":0},
  "missing_by_type":{"multiple_choice":0,"true_false":0,"identification":0,"essay":0}
}
```

Question rules: nonblank prompt ≤1,000, explanation string ≤500 (empty allowed), integer
points 1–1,000 (omitted provider points become 1). MC: 2–10 distinct nonblank option
strings ≤500 each, one integer zero-based `correct_index` within bounds. TF: boolean
`correct_boolean` including false. Identification: 1–10 nonblank strings ≤200 each;
equivalent normalized duplicate strings collapse. Essay: no answer fields. Fields for
other types and unknown question fields cause that candidate to be dropped. Returned
objects contain only the documented fields. String limits count Unicode code points.

Only complete STOP provider candidates are considered; surrounding code fences are
stripped before JSON parsing. Duplicate prompts use NFKC, whitespace normalization and
case folding across all types and the regeneration avoid list. Accepted questions are
trimmed per requested type; no question quota is borrowed from another type.
`missing_by_type` is requested minus returned. `dropped_by_type` counts invalid, duplicate
or excess candidates of each recognizable type, across attempts. Unparseable output and
unknown-type entries cannot be assigned a type; their shortfall appears in missing counts.
If any valid question remains, return it immediately, even if incomplete. Retry once
only when none survive; two unusable results give `AI_BAD_OUTPUT`. Never invent fill-ins.
Structural validity does not establish factual correctness, privacy anonymization or
semantic uniqueness. Instructors must review before explicitly saving/publishing.
Saving later uses the existing `save_question` contract: map `correct_index` to
`correct_option_index` and supply position/other required persistence fields there.

## Errors and request lifecycle

Every failure is `{"error":{"code":"AI_BUSY","message":"The AI assistant is busy. Please try again in a few minutes."}}`
with exactly one fixed code and short English message. No raw provider/database errors.

| Code | HTTP | Meaning / recovery |
| --- | --- | --- |
| `NOT_ALLOWED` | 403 | Invalid/missing token, unverified session, wrong role/ownership or read-only assessment; resolve access before retrying. |
| `INVALID_REQUEST` | 400 | Malformed JSON, identifiers, counts, text entries or settings; correct input. Non-POST uses 405. |
| `NO_TEXT` | 400 | Supply readable source text. |
| `TOO_LARGE` | 413 | Reduce source/comparison text or encoded body size. |
| `AI_IN_PROGRESS` | 409 | Another request owns the user's slot; wait, then retry. |
| `AI_BUSY` | 503 | Provider 429/500/502/503/504; wait before an explicit retry. |
| `AI_TIMEOUT` | 504 | Provider call deadline; explicit retry is allowed. |
| `AI_BAD_OUTPUT` | 502 | Two unusable, blocked, truncated, malformed or oversized provider responses; change text/focus or retry. |
| `AI_UNAVAILABLE` | 503 | Configuration, database, transport, unsupported schema/model, unexpected provider or unconfirmed finalization failure. Resolve configuration/service availability first. |

After authorization and input validation, acquire `begin_ai_request(user, 'generate_quiz')`;
null means `AI_IN_PROGRESS` with no provider call and no finish for an unacquired slot.
Acquired requests always attempt `finish_ai_request` in finally with success/failed and
only the fixed error code. Retry the same finish update once on failure. If neither
finish is confirmed, return `AI_UNAVAILABLE` and discard otherwise successful questions;
the log's actual state may be uncertain. Begin timeouts can likewise leave an uncertain
acquisition. Existing RPCs ignore started rows older than two minutes, allowing recovery;
they do not automatically mark stale rows failed. Hard platform termination can prevent
finally, and client cancellation does not guarantee provider cancellation or refund.

Auth timeout 8s; request read 5s; each database operation 5s; each Gemini attempt ≤45s;
overall pre-finalization deadline 110s; finish ≤5s each, at most twice. Provider body
limit 262,144 UTF-8 bytes. No retries for provider busy/transport/timeouts. API key is
sent in `x-goog-api-key`, never the URL. Only texts, focus, comparison prompts and trusted
generation settings reach Gemini: no filenames, caller names/emails or class/quiz/user
IDs are added. Source text itself is not automatically anonymized: supply nonprivate
content. No request, response, secret or raw exception is written to application logs.
Usage logging stores only the existing user/kind/status/timestamps and sanitized code.

## DEV controls, deployment and owner checks

Run from `filo-app/backend`. First obtain the exact System Analyst-approved model ID;
there is deliberately no model fallback. Replace placeholders privately; do not commit
secrets or paste credentials into shared logs/chat. Commands are owner-run, not executed:

```powershell
npx supabase secrets set --project-ref fiobwfzmqcffbpixzvbq GEMINI_API_KEY='<private-key>' GEMINI_MODEL='<analyst-approved-model-id>' AI_TEST_MODE=off
npx supabase functions deploy ai-generate-quiz --project-ref fiobwfzmqcffbpixzvbq
deno test --config supabase/functions/ai-generate-quiz/deno.json supabase/functions/ai-generate-quiz/quiz_test.ts
```

The test command uses mocked HTTP only; no real credentials, database or provider calls.
Initial Deno dependency resolution may download the existing Supabase dependency and
create a lockfile. No additional library is introduced by this function.

`AI_TEST_MODE=sample` returns deterministic, explicitly labeled DEV questions matching
requested counts. Any error code in the table can be the secret value to simulate its
response, with no Gemini call. All real authorization, input validation and slot checks
still run first. Synthetic errors after acquisition finalize failed with that code,
including synthetic `AI_IN_PROGRESS`; a real concurrent refusal acquires no slot.
The switch works only when `SUPABASE_URL` exactly matches
`https://fiobwfzmqcffbpixzvbq.supabase.co`; any enabled switch elsewhere or unknown mode
fails closed with `AI_UNAVAILABLE`. Missing, empty or `off` disables simulations.
Never use this secret to bypass production authorization. Disable it after DEV QA:

```powershell
npx supabase secrets set --project-ref fiobwfzmqcffbpixzvbq AI_TEST_MODE=off
```

Owner acceptance: run maintained tests; generate all four types with real neutral text;
check token/session/student/ownership/class/locked/archive denial, boundary inputs,
concurrency, every simulation, provider retry/partial-output cases, recovery after
disconnect, usage finalization and absence of sensitive log content. Frontend/offline
integration is not implemented here; clients retain drafts and offer explicit retry.



# M10-BE-02: AI limits and atomic provenance - 2026-10-27

Prepared migration `20261027100000_ai_flag_and_limits.sql`; not applied or tested by the assistant.
`save_question(uuid,jsonb)` keeps its signature and `{question_id,option_ids}` response.
Optional `p_question.ai_generated` must be a JSON boolean (explicit null, strings, numbers,
arrays and objects raise `22023`). New omitted flags default false. Edits preserve the existing
flag when omitted; true provenance is sticky even when an edit sends false. Existing ownership,
verified-session/class/lock guards and atomic options/key/totals behavior remain intact.
The instructor save caller now sends the flag inside the RPC, eliminating its separate PATCH.
Apply the migration before releasing the updated caller. Old clients remain compatible, but
old clients retain their former two-write behavior until upgraded. No backfill or UI changes.

Source inspection: `ai_usage_log` has only id, user_id, kind, status, error_code, created_at,
finished_at; no content columns. Migration 0007 enables RLS, provides no log policies, revokes
app table access and RPC execution, and grants server execution to service_role. Administrative
postgres access remains expected. No new security defect was identified by this inspection;
DEV role assertions are authored, not runtime Pass. `begin_ai_request` already serializes by
per-user advisory transaction lock, refuses recent `started` rows, and ignores started rows
older than two minutes. This is an in-flight slot, not a two-minute cooldown after completion,
a daily cap, or a global shared-key quota. An old unfinished row remains historical, not silently
rewritten as a terminal result. Existing finalization retries once; database outage or worker
termination can still leave `started`, with slot recovery after two minutes.

DEV `AI_TEST_MODE=unexpected` now throws an ordinary exception after acquisition and before any
provider call. Existing DEV URL guard applies. Expected response: HTTP 503 / AI_UNAVAILABLE;
expected row: failed / AI_UNAVAILABLE / nonnull finished_at. It logs no exception text or payload.
Existing sample success and AI_BUSY/AI_TIMEOUT/AI_BAD_OUTPUT modes are unchanged. Restore off
in finally after owner simulations. Mocked assertions cover finalization/retry and overlapping
handler requests; only the separate two-connection SQL procedure establishes real DB locking.

Maintained owner checks: `tests/ai_requests.sql` (rollback summary), `tests/ai_concurrency.sql`
(separate connections), `tests/ai_cleanup_job.sql` (committed tagged fixtures and actual daily
job evidence), handler `quiz_test.ts`, and frontend `quiz_save_ai_test.dart`.
The rollback suite executes the existing cleanup command against old/boundary fixtures, then
rolls back all effects; this does not prove the scheduler ran. The scheduled job remains
`filo-purge-ai-log`, daily `15 3 * * *`, deleting created_at strictly older than 30 days.
See tests README for exact owner procedure. All M10-BE-02 execution/DEV acceptance is Not run;
M10-BE-01 evidence remains accepted only within qa/TEST_ACCEPTANCE.md's recorded scope.


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


## M10-BE-02 owner Auth401 diagnostic - 2026-10-28

Owner GET /auth/v1/user diagnostic returned token_valid=False HTTP401 using aiHeaders.
Auth rejected supplied credentials; exact error body/code unavailable. Expired/invalid token
versus wrong API key is not distinguished by status alone. Live simulations remain blocked,
not Pass; next action is fresh verified-instructor access token with matching DEV public key,
then rerun only token diagnostic. Do not rerun accepted SQL77/Deno17/Flutter8/DB concurrency
checks. Prior simulation finally reset off remains the last confirmed switch state.
Evidence: owner pasted diagnostic output. No secrets retained, assistant execution, production
changes, disposable materials or Git mutations. Scheduled cron evidence, ledger, live simulation
rows and overall acceptance remain pending.


## M10-BE-02 owner refreshed token accepted - 2026-10-28

Owner attachment820b4fd2-7724-429f-b78c-8f84e98aed61/Pasted text.txt shows refreshed
GET /auth/v1/user token_valid=True. Supersedes current token-rejected state while preserving
historical Auth401 and simulation403 attempts. This proves Auth accepted the supplied token
at that check, not verified device session, instructor role, ownership or quiz editability.
The pasted simulation loop has no subsequent mode/HTTP output, test-start value, secrets-set
or reset completion output; execution/outcomes of that later loop are not established. Do
not infer new simulation Pass or a newly confirmed switch reset. Last evidenced off reset
remains the earlier completed batch. Next owner check is read-only prerequisite inspection
before further simulation attempts; never record tokens or payload content in project docs.
Prior SQL77/Deno17/Flutter8/DB concurrency and fixture evidence remain accepted within scope.
Ledger, live simulation finalization rows, scheduled cleanup and overall acceptance pending.
No assistant tests/live checks/implementation changes/disposable materials/Git mutations.


## M10-BE-02 owner authorization prerequisites PASS - 2026-10-28

Owner diagnostic returned session_verified=true, role=instructor, profile_active=true,
class_ready=true, quiz_ready=true. Combined with refreshed Auth token_valid=True, accept
these prerequisites within the reported DEV inspection time/scope; no permanent access
state or simulation success inferred. Earlier403 and401 attempts remain historical.
Fresh five-mode live simulation outcomes/log finalization still pending. Prior SQL77/Deno17/
Flutter8/DB concurrency evidence retained; no repeat of those accepted checks requested.
Next owner attempt uses curl.exe response/status capture to avoid empty PowerShell
ErrorDetails.Message. No credentials or question/source content recorded. No assistant tests,
live checks, implementation changes, disposable materials or Git mutations. Scheduled cleanup,
migration ledger and overall owner acceptance remain pending.


## M10-BE-02 sample still denied after prerequisites - 2026-10-28

Owner curl attempt at2026-10-27T16:35:22.5813639Z returned sample HTTP403 NOT_ALLOWED,
then correctly stopped; finally secrets reset AI_TEST_MODE=off succeeded. Remaining four
modes did not run in this attempt. Unlike earlier PowerShell failures, backend code is now
evidenced. Prior successful prerequisite query remains historical scoped evidence, not proof
of identical HTTP principal/URL or still-unexpired token at the later call. Root cause open.
No runtime bypass, speculative production fix, new simulation Pass or ledger/cron evidence.
Next read-only diagnostic compares exact curl Auth status, bearer shape, email/sub/session
claims and expiry plus intended function URL without printing secrets. Existing passes retained.
No assistant tests/live checks/implementation changes/disposable materials/Git mutations.


## M10-BE-02 owner curl token expired - 2026-10-28

Owner exact curl Auth diagnostic: HTTP403, bearer_format_valid=true, email_present=false,
subject_matches=false, session_uuid_valid=true, seconds_until_expiry=-393,
function_url_correct=true. Token was expired by6m33s at this check. This explains why these
credentials cannot pass authentication now; it does not prove the exact expiry timing of every
historical denied call. Earlier token/prerequisite Pass remains valid only at its recorded time.
Do not change production authorization or repeat accepted SQL/mock/concurrency checks.
Next owner action: current access token from the same verified instructor session, Auth check
then immediate simulation loop to avoid another delayed retry. Previous off reset remains last
confirmed switch state. No new simulation Pass. Ledger/cron/live row evidence/overall acceptance
pending; no credentials retained, assistant tests/live checks or implementation/Git mutations.


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

## M10-BE-03 Q3 staged quiz quality pipeline - 2026-10-28

Owner-authorized replacement of prompt-only live generation. Request keys, four question
types and response envelope remain unchanged. Live MC candidates now use internal
correct_answer plus3 distractors; exactly4 options and balanced zero-based correct_index
are built in code using a per-request seeded RNG. The model no longer chooses positions.
Returned questions optionally add evidence:string (12–1000 chars), and essays sample_answer:
string (<=4000) and rubric:[{key_point:string<=500,points:positive integer}], sum=question.points.
Live candidates require these metadata. No objective/fact/internal candidate keys returned.
Manual quiz save/publish schemas and student question delivery are unchanged; no metadata
persistence migration. Instructor response metadata must stay out of student-facing payloads.

Flow: one N+2 blueprint call (requested types/difficulty, unique objective/fact/evidence),
batched candidate generation, pure validators, separate key-blind batched solve, failed-only
repair (initial+at most2 retries per objective), terminal drop, same-type spare when available.
No partial, malformed or ambiguous verifier decision is accepted. Evidence requires exact
single-source NFKC/whitespace-normalized occurrence, with conservative question/objective/
evidence lexical alignment. Invalid blueprint slots remain missing; rejected question
objectives increment dropped_by_type once after exhaustion; repaired attempts appear in
quality_stats only. A replacement may make missing0 while dropped remains nonzero. No new
permanent provider request log row per internal call; one usage slot/finalization per quiz.

Validators cover structural/option rules, near-duplicates, same-fact/text overlap, absolute
TF wording unless explicit statement evidence, vocabulary-based glued words, source-explicit
acronym expansions, essay metadata/points and majority long-answer cues. Final answer position
counts differ at most1; options/index remain aligned after drops. Blind MC/TF checks one
answer vs key; identification compares source-derived variants, essay uses lexical rubric
coverage. English/lexical heuristics are conservative, not semantic proof or auto-grading.
Evidence occurrence does not establish entailment; independent solver can agree incorrectly.

Existing auth/verified instructor/class/quiz guards, source/body limits, configuration,
provider error categories, production test-switch guard and finish retry remain. Same110s
handler budget,45s maximum per provider call. Clean run3 provider calls; bounded repairs/spares
can reach13, with source tokens repeated per generation batch. No cost/latency measurements.
Provider/verification HTTP failures fail closed with existing codes; no unverified fallback.
No further stage starts near deadline; verified partials possible, zero usable givesAI_BAD_OUTPUT.
DEV sample mode remains a labelled legacy simulation, not a quality test.

Log ai-generate-quiz: quality_stats once per live run, including errors: numeric calls,
retries, verifier_disagreements and fixed-rule failure counts only. No source/evidence,
question/answer/rubric/provider text, IDs, keys or tokens in those stats.

Validation: explicitly requested focused Deno suites run by assistant on2026-10-28:
34 tests PASS /0FAIL, type checking included. Earlier run30PASS/1FAIL caught acronym extraction,
fixed and broadened; prior compile issues resolved. Mocked transport/solver tests, not live
provider schema acceptance or deployment evidence. No live calls or deployment. Owner runtime
review of new pipeline, current model schema support, actual latency/quota and five-file
quality completion pending. See docs/ai-prompts.md and docs/ai-quality-check.md (local ignored
docs) and tests/README.md. No dependencies or migrations added.
### Q3 contextual identification variants - 2026-10-28

Owner follow-up output exposed an expansion question accepting its own acronym as answer.
answerVariants now uses stem context: source-supported full-name variants retained, acronym
already supplied by a full-name/expansion stem excluded; empty resulting answers rejected.
Parser and quality-rule caller use same helper; no shape change. Added regression; focused
Deno suites35PASS/0FAIL with type checking. Local/not deployed. See quality report for owner
output findings and unresolved pasted-spacing versus in-memory diagnostic. No live calls.
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
### C1 standalone verifier calibration harness - 2026-10-28

Added maintained tests/ai_calibration.ts/test for one optional owner-run Gemini blind batch
using frozen accepted Markdown and private process environment. Shared blindReviewRequest
extracted/reused without changing production prompt/schema or public behavior. No new API
route/test mode/dependency/model selection, no instructor token or deployment needed for
local harness. Local keys/labels/rubrics withheld from request; results scored separately
for solving, cognitive agreement and false accepts/rejects.43focused testsPASS/0FAIL with
read-only reference permission and mocked HTTP. No live calibration or quality acceptance.
See tests/README.md for owner commands and limits; full task remains open.
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

Owner-approved design implemented locally, NOT tested/deployed. No public endpoint, response
field/type, auth, database or dependency change. Plans/rationales/reviews remain internal.
planning.ts adds exact source-span references, application facts, linked inference steps,
changed-condition contrast and answer binding. Medium requires one step; Hard dependent steps.
Code assembles evidence instead of accepting retyped quotes. Current bounded references allow
one or two adjacent spans within one file; unsupported distant context remains a gap.
review.ts checks all review dimensions independently, including per-option defensibility,
category/plausibility, scenario use, assumptions and independent essay answer-point coverage.
Blind review still excludes source/key/plan/target difficulty. Disputes may use one source-aware
batch with neither preferred key; outcomes support generator/alternative, ambiguity or remain
unresolved. Keys are never silently flipped. Repairs are revalidated/reviewed; replacements
retain the requested slot budget, and new duplicates cannot evict already verified items.
At most3 actions per slot, with audit consuming an action; no increased retry/call/deadline
ceiling. Clean path3 calls; current three-round loop plus audit at most8, explicit guard13;
these are structural bounds, not measured cost/latency. Additional metadata increases tokens.
quality_stats marker Q4; all applicable failure counters may overlap per attempt, source_audits
summarizes dispositions. No private content added to logs. Optional observer is absent from
hosted handlers; maintained local ai_quality_trace.ts captures bounded private attempts outside
workspace/Git. A private HTTP400 provider_error event may retain a bounded, redacted
structured provider message; no raw body/details/headers or supplied key. Hosted logs
and public errors remain unchanged. Keep traces private; pattern masking is not a general
sensitive-data detector. See tests/README.md and local
ai-prompts.md for owner command/contracts/limits. Legacy buildPrompt/responseSchema inspection
helpers are not the live pipeline. C1 content/hash unchanged; earlier live evidence does not
verify the changed reviewer. Prior48PASS/DEV72 failure retained, Q4 acceptance pending.

Q4 provider compatibility adjustment (2026-10-28): remove nested plan-array maxItems
constraints from planSchema; parsePlan retains original source_refs/facts/steps/dependency
limits. Top-level batch counts, shape/required fields, byte/deadline budgets and question
validation remain. No fallback, retry/call increase or public API change. Generic first-call
HTTP400 does not establish schema complexity as root cause; adjustment is provisional.
New maintained boundary regression prepared, NOT RUN; no further live request performed.

### Q4.1 JSON-mode compatibility (supersedes provisional nested-schema workaround)

Owner isolated a schema-dependent rejection: same blueprint instructions/lesson accepted
with tiny schema(200), full blueprint schema rejected(400). Exact field/constraint unknown.
modelRequest now uses JSON mode without provider-enforced nested schema; full internal
schema remains in system output instructions. Source/question data stays in separate user
payload; blind reviewer still receives no key/source/plan/target difficulty. Blueprint,
generation, verification and C1 runner use same builder; no runtime fallback or new calls.
All existing parsers/source/quality checks and action/call/time limits retained. Original
nested plan maxima restored in instruction contract, never relaxed in parser. Public output
unchanged, revision Q4.1. Tradeoff: JSON mode gives less provider-side shape enforcement;
malformed output fails local checks under existing budgets. No added endpoints/dependencies.
Maintained tests/fixtures updated, NOT RUN; no live acceptance/deployment claimed.

Q4.1 diagnostics follow-up: optional private observer now retains bounded/redacted
non-thought model text, finish reason and parsed shape/outcome, plus HTTP status and
missing/blocked/decoding metadata. No full HTTP envelope/headers or hosted/public logging.
Per-response text cap65536characters, existing collector budgets remain. Hosted handler
still supplies no observer. Parsing/acceptance/call/retry behavior unchanged; malformed
blueprint cause remains unknown for earlier trace. Maintained offline regression NOT RUN.

### Q4.2 shallow model envelope and planner separation

Owner trace identified completed blueprint text with trailing extra closing brace and mixed
question fields. modelRequest now enforces only a fixed shallow outer items-array schema;
full stage schema remains in instructions/local checks. modelItems strictly unwraps one
items key with object items; syntax errors/aliases/extra outer fields stay invalid. Public
quiz/exam response unchanged. No heuristic JSON repair or automatic schema fallback.
Planning shares source/cognitive policies but no longer receives question-construction
instructions. Blueprint extra question/answer/explanation fields now rejected explicitly.
Generation/C1 fixtures/callers aligned; frozen reference unchanged. MarkerQ4.2, same call/
repair/time/byte budgets, no dependencies/endpoints/database/auth changes. Maintained
regressions updated/prepared, NOT RUN; provider acceptance/live quality pending. No extra
AI calls/deployment performed. Supersedes Q4.1 schema-free transport, not historical evidence.

### Q4.3 encoded-item model transport (supersedes Q4.2 object-item schema)

Owner Q4.2 trace accepted HTTP200/JSON but returned one type-only item, missing complete
blueprint. Provider schema now fixes outer items as array of strings; each encodes a full
JSON object, decoded by shared modelItems. This avoids declaring only generic identity
properties for provider item objects. Malformed/non-object encoded entries become null
in place and fail stage checks; envelope aliases/extra keys/non-string items rejected.
All nested fields preserved, no heuristic syntax repair or inferred defaults. Public quiz
JSON unchanged; generation/calibration/fixtures share codec. Same local validators, stage
separation and call/repair/time/byte limits. MarkerQ4.3; private invalid_items metadata added.
Escaping may add output tokens, inner JSON can still fail; no live acceptance claim.
Maintained tests updated, NOT RUN. No extra AI calls/deployment/dependency/database changes.


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
Q4.8 retains the previous observed difficulty/direction across malformed repairs until
a new parsed candidate replaces that assessment; regression coverage updated, NOT RUN.

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

## M11-BE-01: ai-chat (chat and summary) - 2026-10-31

Status: implemented locally; maintained mocked tests passed on 2026-10-31. DEV deployment,
real Gemini responses, error branches, logs and owner acceptance are pending.
M10 acceptance does not establish M11 runtime results. Evidence register:
[M11 acceptance](../../qa/TEST_ACCEPTANCE.md#m11-be-01-ai-chat-and-summary---2026-10-31).

### Call and authorization

`POST /functions/v1/ai-chat`, `Authorization: Bearer <fresh-access-token>`,
`Content-Type: application/json` (and the project's public `apikey` header where required).
OPTIONS returns 204 for CORS; other methods return 405 / INVALID_REQUEST.
Gateway JWT verification is disabled in config because the handler validates the token
through Auth and returns the same sanitized NOT_ALLOWED contract for denied callers.
The checks run in order: valid token, matching user/session in verified_sessions,
then active, nondeleted student profile. Missing/denied identities return 403 before
reading the body, acquiring a slot or calling Gemini. Database/configuration failures
return AI_UNAVAILABLE without allowing the request through.

```json
{
  "mode": "chat",
  "messages": [{ "role": "user", "content": "What do the files explain?" }],
  "sources": [{ "name": "lesson.txt", "text": "Extracted lesson text." }]
}
```

All three fields are required. `mode` is `chat` or `summary`. `messages` is an array
of at most 10 objects, each with role `user` or `assistant` and nonblank string content
of at most 2,000 Unicode code points. Send the last 10 in chronological order; the
server rejects excess history rather than silently discarding it. Chat requires a
final user message. Summary may use `messages: []`.

`sources` is an array of at most 3 objects with a nonblank `name` (up to 255 Unicode
code points) and readable string `text`. The combined text limit is 40,000 Unicode
code points, independently of the message limit. Excess counts/text/name length
return TOO_LARGE; wrong shapes/types/settings return INVALID_REQUEST. The raw JSON
body is additionally limited to 524,288 bytes, streamed with a 5-second read bound.
Unknown object fields are ignored and never included in the prompt.

For general chat, explicitly send `sources: []`. An empty/whitespace selected source
returns NO_TEXT even alongside readable sources, preventing extraction failure from
silently becoming general chat. Summary without sources also returns NO_TEXT.

### Response, prompt and privacy

```json
{ "answer": "A short plain-text answer.", "mode": "files", "truncated": false }
```

HTTP 200 returns only `answer`, `mode` and `truncated`. Answer is nonblank plain text,
trimmed and limited to 4,000 Unicode code points. `mode` is `files` for requests with
readable sources (including summaries), otherwise `general`. `truncated` concerns
source text only: it is always false because this function rejects excess source
text and never cuts it. It cannot detect source truncation performed by the caller.
An answer limited to 4,000 characters does not change that flag.

Trusted system instructions are composed from `docs/study-prompts.md`, common rules
plus exactly one task. Supplied text and history are JSON-encoded between separate
`<filo_sources>` and `<filo_messages>` boundaries; angle brackets inside the JSON are
escaped so supplied content cannot forge the markers. History is interpretation
data, never source evidence. Source-based chat remains source-only even when a later
message requests general knowledge; absent information is stated plainly. General
chat requires an explicitly empty source list. Summaries give an overview and main
ideas in the source language; chat follows the latest question's language.

Source names, profile/account names, emails and IDs are not added to the Gemini body.
Only validated message roles/content and source texts are sent. Supplied text may
itself contain personal information: no automatic anonymization is claimed. The
system instructs the model to omit personal details; source grounding and omission
still need semantic owner review. Clients must render answer as text, not executable
HTML. No conversation, source text, answer, provider body, key, or raw exception is
written by this function to the usage log or console. The existing metadata-only
usage log stores account ID, request kind, status, error code and timestamps.

### Request slot, provider and errors

After authorization and validation, call `begin_ai_request(p_user, p_kind)` with
kind `chat` or `summary`. Null means AI_IN_PROGRESS and acquires no slot. An acquired
request always attempts `finish_ai_request(p_id, p_status, p_error)` in finally,
with success/null or failed/the sanitized code. Retry the same idempotent finalization
once if unconfirmed. If both attempts fail, return AI_UNAVAILABLE; do not claim that
the terminal database write was confirmed. Existing stale-slot recovery remains
the database's 2-minute window; a runtime killed before finally may leave a started row.

Use only server secrets GEMINI_API_KEY and GEMINI_MODEL; no model default, SDK or new
database migration is added. Make one Gemini generateContent call, with plain-text
output and a 45-second bound covering transport and body reading; abort it afterward.
Provider JSON is bounded to 262,144 bytes. Do not retry Gemini automatically. Ignore
thought parts. STOP and MAX_TOKENS replies with readable text are bounded and returned;
blocked replies discard even partial text. Malformed envelopes, unavailable network,
missing key/model or unexpected failures receive AI_UNAVAILABLE. The provider adapter
uses the official [generateContent contract](https://ai.google.dev/api/generate-content).

All errors have exactly `{ "error": { "code": "CODE", "message": "Short English message." } }`.

| Code | HTTP | Message / condition |
| --- | --- | --- |
| NOT_ALLOWED | 403 | You are not allowed to use the study assistant. |
| INVALID_REQUEST | 400 | Check the study mode, messages, and sources. Malformed JSON/settings; method rejection uses 405 and “Use POST for this request.” |
| NO_TEXT | 400 | Add a readable source to generate a summary or use your files. |
| TOO_LARGE | 413 | The request is too large. Use fewer messages or less source text. |
| AI_IN_PROGRESS | 409 | An AI request is already running. Please wait and try again. |
| AI_BUSY | 503 | The AI assistant is busy. Please try again in a few minutes. Provider 429/500/502/503. |
| AI_TIMEOUT | 504 | The AI request timed out. Please try again. Provider 408/504, aborted transport or the 45-second deadline. |
| AI_BLOCKED | 502 | The AI could not return an answer. Try rephrasing your request. Empty replies, prompt blocks, candidate safety/recitation/privacy blocks. |
| AI_UNAVAILABLE | 503 | The AI assistant is unavailable. Please try again later. Other provider, network, configuration or bookkeeping failures. |

These are backend messages. The draft study UI's PRD busy wording still has its own
persistence/manual-action release gates; this task does not certify that UI copy.

### DEV test switch and owner handoff

AI_TEST_MODE retains M10's exact DEV URL guard (`https://fiobwfzmqcffbpixzvbq.supabase.co`).
`off`, empty or unset uses Gemini. In DEV, `sample` returns a fixed, visibly DEV-labeled
chat answer or summary with the normal response fields; it makes no claim about the
submitted material. Any code in the error table simulates that error; `unexpected`
tests generic-exception handling. Unknown modes and non-off modes outside DEV return
AI_UNAVAILABLE. Real authorization, validation and acquisition run before simulation;
every acquired simulated request is finalized. Restore AI_TEST_MODE=off in finally
after owner testing. It is a project-wide secret also used by M10, not a client field.

From `filo-app/backend`, commands for a focused rerun and DEV deployment (deployment not executed by the assistant):

```powershell
deno test --allow-env --allow-net --config supabase/functions/ai-chat/deno.json supabase/functions/ai-chat/chat_test.ts
npx supabase functions deploy ai-chat --project-ref fiobwfzmqcffbpixzvbq
```

The maintained tests mock database and provider calls: authorization order and query
scope, Unicode/count/body limits, prompt-marker collision handling, identity omission,
plain text/output bounds, provider error/safety/timeout mappings, slot overlap,
simulation and finalization retry. A mocked result is not evidence of live Gemini,
actual database concurrency, logs, deployment, app behavior or owner acceptance.
Owner live checks must cover file chat, missing source answer, explicit general chat,
summary, denied instructor/unverified sessions, errors and corresponding terminal
metadata-only usage rows. Client offline UI, local history/summary saving and retry
presentation are blocked on the later M11 frontend integration; this task adds no UI.

On 2026-10-31 the user explicitly requested test execution. The assistant ran the
focused Deno command above on Windows using the installed Deno outside the sandbox:
**13 passed, 0 failed** (test duration 315 ms, exit 0). An initial sandbox attempt
could not launch the executable; no tests ran in that attempt. Database and provider
responses were mocked; no DEV deployment, live Gemini/API request, real-session or log
inspection was performed. Owner acceptance and live checks remain pending.

## M11-BE-02: Flashcards and practice quiz - 2026-10-31

Status: implemented locally; maintained mocked tests authored **NOT RUN**. Deployment,
real provider quality, actual authorization/ledger behavior, log privacy and explicit
owner acceptance remain pending. See [acceptance register](../../qa/TEST_ACCEPTANCE.md).
No database migration, new dependency, server content persistence or frontend storage is added.

### Calls and inputs

POST JSON to `/functions/v1/ai-flashcards` or `/functions/v1/ai-mock-quiz`, with
`Authorization: Bearer <access-token>` and the usual project API key header. OPTIONS
returns 204 with existing CORS headers. Gateway JWT verification is disabled in config
so handler authentication returns NOT_ALLOWED for invalid/missing tokens. A valid token,
verified session bound to that user, and nondeleted student profile are required.
Instructors are refused. Auth/database infrastructure failures give AI_UNAVAILABLE.

Both require `sources`: zero to three `{ name, text }` objects. Names must be nonblank
strings of at most 255 Unicode code points; text must be a string and every supplied
source must be nonblank. Combined source text cap: 40,000 code points, rejected rather
than truncated. Names and user metadata are not forwarded to Gemini. `topic_focus` is
optional, string, max 200 code points, trimmed; with `sources: []`, it must be nonblank.
With sources, the topic only narrows source-supported content. Unreadable supplied
sources return NO_TEXT even when a topic is present. Raw JSON cap: 524,288 UTF-8 bytes.
Incorrect shapes/counts/topic/types give INVALID_REQUEST; excessive source count/name/text
or body size gives TOO_LARGE. Missing all usable input gives NO_TEXT.

Flashcards require an explicit integer `count` from 5 to 30 (no backend default):

```json
{
  "sources": [{ "name": "lesson.txt", "text": "A primary key uniquely identifies each row in a table." }],
  "topic_focus": "Primary keys",
  "count": 5
}
```

Practice requires `count` exactly 5, 10, 15 or 20, and `types` with one to three unique
supported values: `multiple_choice`, `true_false`, `identification`. Empty, duplicate
and unknown types, including essay, are refused.

```json
{
  "sources": [],
  "topic_focus": "Basic relational database terminology",
  "count": 5,
  "types": ["multiple_choice", "true_false", "identification"]
}
```

The prompt requests each selected type with an even distribution in caller order
(for five across three types: 2/2/1). This is prompt guidance, not a per-type quota:
valid partial output may omit a type and is returned without replacement calls.
Callers must inspect actual returned types.

### Outputs and validation

HTTP 200 returns `{ cards, dropped, missing }` or `{ questions, dropped, missing }`.
All returned text is trimmed. Text limits count Unicode code points before trimming;
blank or overlong fields are rejected rather than shortened. These synthetic examples
intentionally show partial results, not full requested sets:

```json
{
  "cards": [{ "front": "What does a primary key identify?", "back": "A row uniquely within a table." }],
  "dropped": 0,
  "missing": 4
}
```

```json
{
  "questions": [
    { "type": "multiple_choice", "prompt": "Which key uniquely identifies each row?", "options": ["Primary key", "Foreign key", "Table name", "Column position"], "correct_index": 0, "explanation": "The primary key uniquely identifies each row." },
    { "type": "true_false", "prompt": "A primary key can identify a row uniquely.", "correct_boolean": true, "explanation": "Uniqueness is a primary key property." },
    { "type": "identification", "prompt": "What is a horizontal record in a table called?", "accepted_answers": ["row", "tuple"], "explanation": "A row, also called a tuple, represents one record." }
  ],
  "dropped": 0,
  "missing": 2
}
```

The model returns a JSON array; the backend supplies the wrapper and counts. Strip
enclosing JSON fences before parsing. Malformed JSON/non-array roots have zero usable
items. Reject unknown/extra per-item fields. Every raw array element rejected for
invalidity, duplication, an unrequested type or excess count adds one to `dropped`.
Invalid roots have no enumerable items and contribute no dropped count. Deduplicate
fronts/prompts using NFKC, collapsed whitespace and lowercase; keep the first valid
occurrence. Continue past invalid entries to retain later valid items.
`missing = requested count - returned count`. Counts describe only the returned
attempt; a discarded zero-valid first attempt is not added to successful retry counts.

Cards require exactly nonempty `front` (max 200) and `back` (max 500).
Questions require nonempty `prompt` (max 1000), nonempty `explanation` (max 500), a
requested `type`, and only its applicable fields:

- `multiple_choice`: exactly four distinct nonempty string `options` (max 500 each)
  and a single integer `correct_index` from 0 through 3. Reject normalized duplicate
  options, arrays/multiple keys, string/letter indices and embedded correctness flags.
- `true_false`: `correct_boolean` must be a real boolean, including false.
- `identification`: `accepted_answers` contains 1–10 nonempty strings (max 200 each).
  Normalize duplicates as above, retaining the first trimmed spelling; this does not
  define the phone's grading normalization.

No essays, points, rubric or evidence fields are accepted. A single answer key and
distinct options are structurally enforced. Factual correctness, equivalent answers,
privacy omissions and source fidelity still require human review. Prompt instructions
do not guarantee semantic correctness or anonymize input sent to the provider.

### Lifecycle, provider and errors

After authorization and input validation, acquire `begin_ai_request(p_user, p_kind)`
with `flashcards` or `practice_quiz`; null means AI_IN_PROGRESS. Every acquired slot
is finalized in finally as success/null or failed/sanitized code. Retry the same
idempotent finish once if unconfirmed; two finish failures give AI_UNAVAILABLE.
No source, topic, name, generated content, token or raw provider response is logged.
Only the existing metadata ledger is written. A process killed before finally may
leave a started row until existing stale-slot recovery; terminal writes cannot be
confirmed when the database is unavailable.

Use existing GEMINI_API_KEY and GEMINI_MODEL server configuration, JSON response mode,
a 45-second transport/body bound per call, and a 262,144-byte provider body cap.
Ignore thought parts. STOP/MAX_TOKENS replies still require local validation.
When a nonempty model reply yields zero valid items, retry generation once under the
same slot; a second zero-valid reply gives AI_BAD_OUTPUT. At most two serial calls
(90 seconds of provider work) are made. Partial valid results are not retried. Empty
or safety-blocked replies immediately give AI_BLOCKED. Provider/transport/configuration
failures retain ai-chat mappings and are not automatically retried.

Errors use `{ "error": { "code": "CODE", "message": "..." } }`:

| Code | HTTP | Exact message |
| --- | --- | --- |
| NOT_ALLOWED | 403 | You are not allowed to use the study assistant. |
| INVALID_REQUEST | 400 | Check the study settings, topic, and sources. |
| NO_TEXT | 400 | Provide readable source text or a topic with no sources. |
| TOO_LARGE | 413 | The request is too large. Use less source text. |
| AI_IN_PROGRESS | 409 | An AI request is already running. Please wait and try again. |
| AI_BUSY | 503 | The AI assistant is busy. Please try again in a few minutes. |
| AI_TIMEOUT | 504 | The AI request timed out. Please try again. |
| AI_BLOCKED | 502 | The AI could not return an answer. Try rephrasing your request. |
| AI_BAD_OUTPUT | 502 | The AI could not produce valid study material. Try a different topic or source text. |
| AI_UNAVAILABLE | 503 | The AI assistant is unavailable. Please try again later. |

Non-POST methods use INVALID_REQUEST, HTTP 405, `Use POST for this request.`
Provider 408/504 or abort/deadline gives AI_TIMEOUT; 429/500/502/503 gives AI_BUSY;
empty/blocked candidates give AI_BLOCKED. Malformed provider envelopes, other HTTP
statuses, network errors, unexpected finish reasons and missing config give
AI_UNAVAILABLE. Bad generated JSON differs from a malformed provider envelope.

### DEV switch and owner commands

AI_TEST_MODE follows ai-chat: unset/empty/off calls Gemini; sample returns count-matching,
visibly DEV-labelled synthetic data; each code above simulates that error; unexpected
simulates a generic exception. Real authorization, validation and acquisition still
happen first, and acquired requests finalize. Unknown modes or any non-off mode outside
`https://fiobwfzmqcffbpixzvbq.supabase.co` fail AI_UNAVAILABLE. This is a project-wide
secret, not a client option; restore off in finally after simulations. Simulations do
not establish real provider behavior, safety filtering or semantic quality.

From `filo-app/backend` (owner execution only):

```powershell
deno test --allow-env --allow-net --config supabase/functions/ai-flashcards/deno.json supabase/functions/_shared/study_test.ts
npx supabase functions deploy ai-flashcards --project-ref fiobwfzmqcffbpixzvbq
npx supabase functions deploy ai-mock-quiz --project-ref fiobwfzmqcffbpixzvbq
npx supabase secrets set AI_TEST_MODE=off --project-ref fiobwfzmqcffbpixzvbq
```

Maintained mocked tests cover both kinds, bounds, answer variants, duplicate/essay/
conflicting-field rejection, partial/zero output, retry, provider mappings, safe data
markers, auth scope, DEV modes, slot overlap and finish retry. They are authored, not
executed. Owner live checks must cover source and topic modes, all supported types,
instructor/unverified refusal, errors, overlap/retry and matching terminal metadata
rows/log privacy. Frontend offline save/reopen and error/retry UI await later integration.

### 2026-10-31 focused mocked test results

At the owner's explicit request, assistant ran the command above. The first permitted
run reported 11 passed/1 failed (92ms): the true/false assertion compared serialized
object property order. Corrected the test assertion only, with no production change;
the full rerun reported **12 passed/0 failed** (77ms, exit 0), and Deno reported Check.
The initial sandbox launch failed before testing. This supersedes only the earlier
NOT RUN statement for the corrected local mocked suite; the first failure is preserved
in the [acceptance register](../../qa/TEST_ACCEPTANCE.md). Real DEV/Gemini, actual
session and DB behavior, log privacy, frontend/offline and owner acceptance remain
pending. No deployment or live calls were performed.

## M11-BE-03: Student AI security and limits - 2026-10-31

Status: maintained DEV runner and regression tests authored; **NOT RUN**. No live DEV
result, deployment, new runtime Pass, waiver or owner acceptance is recorded. Prior
BE-01 13/13 and BE-02 12/12 mocks apply to the prior revision; changed handlers require
focused owner reruns. No demonstrated database defect or new migration is introduced.
Owner setup/execution/review guide is outside this repository:
[QA owner verification](../../qa/M11-AI-STUDY-MODULE-ACCEPTANCE.md#be-03-details).

`backend/tests/student_ai_security.mjs` (run from backend as `node tests/student_ai_security.mjs`)
uses Node22+ built-ins, explicit DEV targeting, real supplied actor sessions, service
ledger access and Management API access. No account/profile/session setup is forged.
It covers role matrix and real provider controls, input bounds, cross-kind overlap,
independent students, stale-slot cleanup, simulations, metadata schema/access denial,
provider markers, function-log scanning and a source injection. Runtime output and
optional new report outside filo-app contain metadata only; synthetic response/log
human review uses temporary in-memory loopback pages, not saved raw evidence. Missing
logs or uncertain reviews leave overall incomplete (exit2); failures exit1; only full
assertion/review success exits0. Owner acceptance is separate.

New DEV instrumentation is enabled only by exact existing DEV SUPABASE_URL plus
`AI_DEV_TRACE=on`. It emits JSON events tagged `filo_ai_dev_v1` with exactly:
`tag`, `request_id` (UUID), `endpoint`, `event`, `log_id` (UUID/null), `error` (code/null).
Events are request/acquired/provider_attempt/provider_settled/complete. Fetch attempts
are marked at the outbound provider boundary; ordinary production responses/logs are
unchanged. A validated UUID `x-filo-ai-test-id` request header is accepted for correlation;
otherwise a UUID is generated. DEV trace responses add that ID, `x-filo-ai-log-id` only
if acquired, and `x-filo-ai-test-mode` for propagation checks. These headers disclose
no content or user/account identity. No new browser CORS header policy is added;
the test runner uses direct HTTP. Outside DEV or with tracing off, no events or extra
response headers are emitted.

`AI_TEST_MODE=hold` is a new DEV-only simulation: after real authorization, input
validation and begin_ai_request, wait12seconds then return the normal labelled sample
and finish the slot. Other modes retain their mapping. AI_BAD_OUTPUT remains structured
functions only, not ai-chat. The runner verifies the same student's flashcard refusal
while chat holds, and observes another student's simultaneous slot. It restores mode
off, checks propagation and writes trace off in finally, including normal SIGINT/SIGTERM.
Hard termination/network outages can prevent cleanup; owner recovery commands and
fixture-ID scope are documented. The runner never bulk-deletes logs; normal request
rows remain. Only owned stale/access-probe fixtures are removed and removal checked.

Log querying uses current Supabase Management API `/analytics/endpoints/logs` with
bounded ClickHouse SQL, result/error checks and collection polling, not retired logs.all.
A request is not deemed provider-free from an empty log query: start/end markers,
acquisition correspondence and observed positive provider controls are required.
Canary scanning plus a human review of the selected log window cannot prove unrelated
runs or all possible prompt injection attacks safe. Source text sent to Gemini may
contain personal data; this task adds no anonymization promise.

Owner local commands (not executed by assistant):

```powershell
node --test tests/student_ai_security.test.mjs
deno test --allow-env --allow-net --config supabase/functions/ai-chat/deno.json supabase/functions/ai-chat/chat_test.ts supabase/functions/_shared/study_test.ts
```

The maintained Node cases check evidence completeness, forbidden metadata fields,
terminal-row matching, token/project preflight and rejection before network access.
Deno cases extend both endpoint handlers for DEV-only trace/hold, auth-first behavior,
metadata privacy, production refusal and untrusted correlation IDs. No new suite Pass
is claimed. Remote Management API shape/permissions and real execution remain pending.

### 2026-10-31 focused local test results

At the owner's explicit request, assistant ran the maintained suites on the uncommitted
Windows workspace revision. Node security-runner tests: **6 passed/0 failed**, exit0,
184.7806ms. The deliberate fake transport failure printed a failed mock run while its
cleanup assertion passed; it was not a live project failure. Deno chat and study suites:
**28 passed/0 failed** (14 each), exit0, 384ms; Deno Check was reported for both. This
supersedes the earlier NOT RUN statement only for these local mocked suites. No source
fix, live DEV/Gemini call, deployment, real log review or owner acceptance occurred.
[QA register](../../qa/TEST_ACCEPTANCE.md) retains scope and remaining evidence.
