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
