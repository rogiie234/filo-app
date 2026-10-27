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
