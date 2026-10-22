# Backend API Changes

## M7-FE-03 owner acceptance - 2026-10-22

Status: Complete - accepted on the owner's report "1-9 passed" for the
acceptance checklist supplied in chat. The reported checks cover defaults and
manual answer-visibility overrides, input boundaries, Philippine schedules,
all-setting draft save/reopen, existing-draft updates, unsaved navigation,
offline/reconnect and save recovery, 130% text readability, and archive/started
restrictions. This supersedes the pending owner acceptance in the implementation
entry below for M7-FE-03 only. Question editing, publishing and AI remain separate
tasks. The assistant did not independently execute or observe these checks;
device/build details were not supplied. No app code or API changes.

## M7-FE-03 assessment form and settings - 2026-10-22

Extended the existing live AssessmentFormScreen with a Settings heading, both
shuffle switches, show-correct-answers switch and optional integer passing score
(0–100; blank is null). All eight setting hints use quiz-builder-messages.md.
Date controls explicitly identify Philippine time (PHT, UTC+08:00), retaining
UTC storage, optional draft schedules and closing-after-opening validation.
New drafts follow Quiz answers on / Exam answers off until the instructor
manually changes answer visibility. Saving or opening an existing assessment
preserves its stored choice across later type changes.

Existing title/instructions limits, 30-minute default and 1–600 validation,
server-generated draft creation, full settings persistence/cache, offline save
reason, unsaved-change confirmation and uncertain-save reconciliation remain
in use. Questions stay below settings; question editing, publishing and AI are
separate tasks. Archived/started restrictions remain. No backend contract,
schema, public interface or dependency changes.

Source review and formatting only. No tests, analysis, builds, device or live
API checks run. Owner step-by-step acceptance is pending for defaults/manual
override, all-setting save/reopen, limits/schedules, offline/reconnect/retry,
unsaved navigation, read-only states and enlarged text. No disposable testing
materials created; pre-existing workspace edits preserved.

## Baseline â€” 2026-10-15

Scope: all 27 app-callable functions listed in [SCHEMA section 7.1](MD%20Files/05-background-schema-document.md#71-functions-the-app-calls). Exact SQL parameter names, types, defaults, and return types below come from [migration 0006](../backend/supabase/migrations/0006_functions.sql). This baseline documents the existing contract; it does not change any function or parameter.

Use the exact `p_` parameter names as keys when calling Supabase RPCs. Parameters without a default are required. `default null` means the parameter may be omitted. All functions are in the `public` schema. Composite return types refer to the corresponding database row types.

| Function | SQL parameters, in declaration order | Returns | Caller |
| --- | --- | --- | --- |
| `request_join` | `p_code text` | `join_result` | Student |
| `decide_join` | `p_member uuid, p_approve boolean` | `void` | Instructor |
| `approve_all_pending` | `p_class uuid` | `integer` | Instructor |
| `remove_member` | `p_class uuid, p_student uuid` | `void` | Instructor |
| `leave_class` | `p_class uuid` | `void` | Student |
| `archive_class` | `p_class uuid` | `void` | Instructor |
| `restore_class` | `p_class uuid` | `void` | Instructor |
| `delete_class` | `p_class uuid, p_section text` | `void` | Instructor |
| `restore_deleted_class` | `p_class uuid` | `void` | Instructor |
| `start_submission` | `p_post uuid` | `submissions` | Student |
| `turn_in` | `p_submission uuid, p_comment text default null` | `submissions` | Student |
| `unsubmit` | `p_submission uuid` | `submissions` | Student |
| `save_grade` | `p_submission uuid, p_score integer, p_feedback text default null` | `submission_grades` | Instructor |
| `return_grades` | `p_ids uuid[]` | `integer` | Instructor |
| `return_all_graded` | `p_post uuid` | `integer` | Instructor |
| `publish_quiz` | `p_quiz uuid` | `quizzes` | Instructor |
| `start_exam` | `p_quiz uuid` | `exam_sessions` | Student |
| `get_exam` | `p_session uuid` | `jsonb` | Student |
| `save_answer` | `p_session uuid, p_question uuid, p_option uuid default null, p_bool boolean default null, p_text text default null` | `timestamptz` | Student |
| `log_leave` | `p_event uuid, p_session uuid, p_left_at timestamptz` | `void` | Student |
| `submit_exam` | `p_session uuid` | `jsonb` | Student |
| `get_my_session` | `p_quiz uuid` | `jsonb` | Student |
| `get_result` | `p_session uuid` | `jsonb` | Student |
| `grade_essay` | `p_answer uuid, p_points integer, p_feedback text default null` | `void` | Instructor |
| `release_results` | `p_quiz uuid` | `void` | Instructor |
| `grant_second_chance` | `p_quiz uuid, p_student uuid, p_reason text, p_proof text default null` | `void` | Instructor |
| `owned_class_count` | None (`()`) | `integer` | Instructor |

### SCHEMA shorthand and SQL parameter mapping

SCHEMA 7.1 uses conceptual argument labels. The table above preserves the implemented RPC names rather than treating those labels as literal RPC keys:

- `code`, `member_id`, `class_id`, `student_id`, `post_id`, `submission_id`, `quiz_id`, `session_id`, `question_id`, `event_id`, and `answer_id` map to `p_code`, `p_member`, `p_class`, `p_student`, `p_post`, `p_submission`, `p_quiz`, `p_session`, `p_question`, `p_event`, and `p_answer` respectively.
- `approve`, `comment`, `score`, `feedback`, `ids`, `left_at`, `points`, and `reason` map to their corresponding `p_` names in the table.
- `delete_class` uses `p_section` for SCHEMA's `section_text`.
- `grant_second_chance` uses `p_proof` for SCHEMA's `proof_note`.
- `save_answer` expands SCHEMA's conceptual `answer` into `p_option` (multiple choice), `p_bool` (true/false), or `p_text` (text answers). Its return value is a timestamp.
- Functions grouped together in SCHEMA 7.1 have separate entries above. Internal and scheduled functions from section 7.2 and Edge Functions from section 7.3 are outside this baseline.

### Future changes

Record subsequent API changes in dated entries describing the affected function, old and new signatures, migration, and frontend impact. Preserve this baseline. If a function or parameter in SCHEMA 7.1 needs to change, record a **Proposed change** before changing the contract, as required by the implementation plan.

## 2026-10-15: classmates and locked-link reports

Migration: `../backend/supabase/migrations/0010_classmates_and_locked_links.sql`.
Both RPCs are new; no existing signatures change. Both require an authenticated,
OTP-verified session. PUBLIC and anon have no execute permission.

| RPC | Required Supabase RPC arguments | Returns | Authorization |
| --- | --- | --- | --- |
| `list_classmates` | `p_class uuid` | Rows: `id uuid`, `display_name text`, `avatar_path text`, `google_photo_url text` | Active member or class owner |
| `report_locked_link` | `p_post uuid` | `void` | Active student member |

`list_classmates` includes the caller when active, excludes pending/removed/left
members and deleted profiles, and sorts by display name then profile ID. The
owner can call it but is not added to the member list without an active membership.
Photo fields remain nullable: prefer an uploaded avatar, otherwise the Google
photo. An avatar path is a private Storage reference, not a public or signed URL.
Deleted classes are inaccessible; archived classes remain readable/reportable.

`report_locked_link` requires a non-deleted post/class and at least one non-deleted
link attachment. It records the student's report; it does not inspect Drive sharing
permissions. It inserts a `link_report` notification for the class owner with
`target_type = 'post'` and `target_id = p_post`.

Limit: one report per student, per post, per UTC calendar day. A private
`locked_link_reports` ledger enforces this with a primary key, including concurrent
calls. Deleting a notification does not reset the limit. A duplicate raises SQLSTATE
`22023`; authorization failures raise `42501`. Missing link attachments raise
`22023`. The report and notification commit or roll back together.

Frontend impact: call the exact `p_class`/`p_post` argument keys. Display the roster
from this RPC instead of querying other students' membership rows. Handle a repeat
report as already reported today. No frontend integration is included here.

Validation: `../backend/supabase/tests/classmates_and_locked_links.sql` runs authenticated
student, non-member, owner, and pending-member cases, validates notification routing,
daily deduplication after notification deletion, next-day eligibility, OTP gating,
and anonymous permissions. All fixtures roll back. Applied on dev on 2026-10-15;
all seven role/edge-case test groups passed. Execution/deployment evidence is in
`../backend/supabase/tests/0010_validation.md`, including remaining verification limits.


## 2026-10-16: class lifecycle access corrections (pending DEV validation)

Migration: `20261016100000_class_lifecycle_access.sql`. Existing RPC signatures are unchanged. Delete now requires an exact section match, including case and whitespace. Deleted class rows are hidden from members and visible to owners for recovery. Former members lose cloud access to submissions, items, returned grades, exam/session/result RPCs and submission Storage metadata; instructor records remain. Archived content writes, exam resume and approval are blocked. Storage writes reject archived or deleted classes. Recovery keeps the existing strict before-14-day boundary.

Frontend: handle SQLSTATE 42501 for inaccessible/read-only operations and refresh class/membership state. Existing signed URLs retain their normal lifetime; downloads remain locally. Tests are prepared in backend/tests/class_join_approval.sql; deployment and execution are pending the owner. No security checklist acceptance is claimed.


## 2026-10-17: client-generated post and attachment IDs

Migration: `../backend/supabase/migrations/20261017120000_post_client_ids.sql` (prepared; deployment pending owner).
No RPC signatures change. Adds authenticated INSERT permission for `posts.id` and `post_attachments.id` so the composer can use stable UUIDs for uncertain-response recovery and upload retry. Existing RLS, verified-session, ownership and open-class guards remain authoritative. No UPDATE privileges are added. Attachment metadata retries use INSERT ON CONFLICT DO NOTHING (`ignoreDuplicates: true`), retaining the original row and avoiding updates to immutable fields. Existing insert grants for other fields and update grants are unchanged.

Source inspection identified the composer/grant mismatch; actual server error and runtime success have not been independently verified. Owner should apply the migration and verify all post kinds and attachment Retry without duplicates. Assistant ran no tests, SQL or live API verification.

## 2026-10-18: student draft comments and text editing

Migration: `../backend/supabase/migrations/20261018100000_submission_draft_editing.sql` (prepared; owner deployment and acceptance pending).
No RPC signatures change. Adds authenticated column UPDATE permission for `submissions.private_comment`, with an UPDATE policy requiring the caller's own draft, active membership, an open class, a non-deleted post and no returned grade. Adds column UPDATE permission for `submission_items.text_content` under the existing own-draft policy, item constraints and lifecycle trigger. Status, ownership, turn-in times and grade columns remain unavailable for direct client UPDATE. Draft comments retain the existing 1000-character constraint; text retains the existing 10000-character constraint. Existing `start_submission(p_post)`, `turn_in(p_submission, p_comment)` and `unsubmit(p_submission)` contracts remain authoritative for lifecycle changes.
Frontend: save comments/text with UPDATE plus a returned row, and cache only server-confirmed values. If this migration is not deployed, these two saves may fail with permission denied; retain the user's input and offer Retry. Existing file/link insertion and item tombstones use existing grants. No SQL, tests, static analysis, builds or live verification were run by the assistant.

## 2026-10-18: turn-in rechecks current file settings

Migration: `../backend/supabase/migrations/20261018110000_turn_in_current_file_rules.sql` (prepared; deployment and owner acceptance pending).
`turn_in(p_submission uuid, p_comment text default null) returns submissions` is unchanged. Turn-in now refuses non-deleted file items when the current assignment has `allow_files=false`, and refuses file counts above its current Max files. Both refusals use SQLSTATE `22023`, retain Draft/items/storage and require the student to remove disallowed files before trying again. Links and text remain eligible. It also refuses deleted/non-assignment posts and returned-grade work. Submitted work is not retroactively changed by an instructor file-setting edit.
The RPC locks its submission and assignment rows; the existing item-rule trigger locks the same submission before validating item writes, preventing a concurrent insertion from slipping across turn-in and serializing slot counts. Existing verification, membership, archive, deadline, comment and unsubmit-window behavior remains. No execute grants or lifecycle signatures change. Frontend rechecks live settings/items before the RPC, caches current settings and blocks invalid file drafts with an explanation. Server checks remain required when settings change after the client read or the client is stale. Existing draft files remain visible for explicit removal; no automatic file deletion or draft purge is introduced. No SQL, tests, analysis, builds or live checks run.


## M5 grading preparation ? 2026-10-18

See [backend gradebook query shapes and guard corrections](../backend/API_CHANGES.md). Existing RPC signatures remain unchanged. Dev acceptance and timings are pending owner execution; Owner confirmed M5-SA-01 acceptance; new grade_missing contract and deployment-order note are documented in the backend API reference.


## 2026-10-18: optional Drive backup implementation

Owner retained backup and authorized implementation. Account avatar menu now opens Drive backup. Native Google authorization requests only drive.file on enable and uploads selected local files to Filo Backup using Drive v3 resumable uploads. Dedicated per-account SQLite v3 backup outbox, secure session URLs, stable remote IDs, server offset reconciliation, size/MD5 completion checks and foreground/Wi-Fi retries are implemented in source. No Supabase RPC/sign-in scope change or new remote migration. Class Files remains preview-only; Android file-picker selection bridges real local files until the downloaded-file library integrates enqueue(File,name). Google Cloud Drive API enablement/Data Access configuration and all runtime acceptance remain pending owner action. See backend/API_CHANGES.md M6 Drive implementation handoff and docs/decisions.md for precise scope semantics, setup, retry policies and verification status. No assistant tests, builds, analysis or live calls.


## 2026-10-18: M6 frontend local files and queued sync

M6-FE-01..08 source implemented; runtime acceptance pending. Drift v4 local_folders/local_files are independent from cloud-cache FKs. Files/download/provider/viewer/manager screens now share local source-attachment IDs and private per-account paths. Class/post/assignment downloads use3600-second Storage links, Dio streams, Cancel/temporary cleanup and free-space preflight. Public Drive links are best effort; report_locked_link signature is unchanged. Office opening/export uses content-URI grants without broad storage permissions.

SyncCoordinator is the shared class/post refresh entry point:200-row full-precision timestamp+PK pulls, typed caches and auxiliary JSON rows, snapshot reconciliation, per-table errors, removed/left eviction preserving local files. Cached results use get_result, never direct student exam-table reads. Generic outbox action contracts: notification_read {notification_id,read_at}; leave_event {session_id,left_at} with event UUID as outbox id; drive_backup {file_id} with stable per-account/local-file id. Retries5s exponential/1h cap/8 tries,30-minute claim lease, deferred permissions/connectivity do not consume retries. Workmanager adds best-effort15-minute network-constrained Android background work; foreground lifecycle/reconnect flush remains available. No queued assignment turn-in/quiz submission.

Drive backup now enumerates My Files, queues null backed_up_at files, uses existing resumable Drive service and marks local/whole-library success only after confirmation; OFF pauses pending jobs and phone deletion never deletes Drive copies. Settings controls are in Files menu. Prior picker-only limitation is superseded. Google Cloud API/consent setup and all live Drive acceptance remain pending. Offline cache unlocking is session/device-bound using a prior server-verification marker; server RPC/RLS verification is still required on reconnect. Package choices, scope/Drive HTML limits and precise offline/background semantics are in decisions.md. No assistant tests, analysis, app builds or live checks run.


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
# M7 frontend consumer integration — 2026-10-21

Frontend FE-01–06 consumes the existing contracts; no server signature, schema,
grant or RLS change is introduced. Instructor assessment settings use existing
quizzes INSERT/UPDATE, question editing uses save_question(p_quiz,p_question),
ordering uses reorder_questions(p_quiz,p_ordered_ids), publication uses
publish_quiz(p_quiz), question deletion uses the existing questions DELETE and
assessment/bank deletion updates deleted_at. Locked settings patches contain
only title/closes_at. Bank copies map the documented shapes to fresh question
payloads and omit bank IDs. Complete answer-key data is cached only in the
verified owning instructor's account database. Authoring is never queued
offline. Client save stages are not one aggregate transaction; partial and
uncertain outcomes retain unsaved edits and require reconciliation as needed.
Maintained frontend tests were added but not run; mobile/offline acceptance is
pending owner checks. Earlier backend acceptance remains owner-reported.


### M7 frontend quiz INSERT alignment - 2026-10-21

The existing quizzes INSERT column grant excludes id/status/protected fields. New quiz rows now omit id and use the returned server-generated UUID. No grant or RPC change. Unknown creation outcomes block replay and require reload/reconciliation against newly visible matching drafts or Classwork refresh. Owner save/publish retry pending; no assistant runtime verification.


## Instructor quiz data layer, current checkout - 2026-10-21

Data layer implemented; the current preview builder is not wired to it.
Use instructorQuizzesProvider(classId) and instructorQuizProvider((classId: ..., quizId: ...))
for cached streams. Null means uncached; [] is a confirmed empty snapshot.
Watch instructorQuizListRefreshProvider/instructorQuizRefreshProvider explicitly for online
loads and errors. ref.refresh(provider(key).future) retries without losing cached content.
Verified account database and cached instructor/class ownership protect instructor answer keys;
online operations also verify server class access. Schema-v5 instructor_quiz_lists and
instructor_quiz_details remain separate from student metadata and cascade on class removal.

QuizDraft holds unsaved in-memory edits, typed settings/question/option/key accessors,
change groups, totals and a deep saved baseline. Editable dates are ISO strings with explicit
offsets; writes normalize to UTC. manilaToUtc takes calendar components; utcToManila returns
a UTC-tagged Manila calendar-component container for display, not an instant to serialize.
No authoring outbox or unsaved-keystroke persistence is introduced.

repository.save(draft) stages settings, question deletes/saves and ordering using the existing
contracts. New quiz/question IDs come from the server. Quiz INSERT omits id/status.
Started quizzes permit only title/closes_at changes. Success refetches complete details/list
before accepting the baseline. Partial/uncertain writes retain edits and set reconciliationRequired.
reconcile(draft) returns saved server state without clearing this guard: review differences,
explicitly acceptSaved(serverState), then reapply chosen local changes. If creation returned
no ID, refresh the list and identify the created draft before accepting it; never replay creation
blindly. Edits made during saving also remain intact and require reconciliation.
publish(classId,quizId) calls the existing idempotent RPC and refetches visible state.

Five date/status unit tests passed, including 23:30, 00:30, date-boundary round trips,
exact open/close boundaries and nullable dates. Maintained draft/cache tests were added but
not run. Migration, account isolation, API and airplane-mode acceptance remain owner work.
No analysis, validation builds, device or live API checks were run. No backend changes.


## M7-FE-02 instructor classwork list - 2026-10-21

This supersedes the earlier data-layer-only screen-integration note for these entry points.
The signed-in instructor Classwork tab now combines cached assignments and
instructor quiz/exam metadata, sorted by created_at descending with stable
IDs breaking ties. Filters are All, Assignments, Quizzes and exams, and Drafts.
Quiz/exam rows show a type chip, icon-and-word time-derived status, title,
Manila opening/closing times, question count and points. An active-route timer
updates chips at the next opening/closing boundary and on foreground resume.
Missing dates are labeled Not set; unknown legacy cached counts are not shown
as zero. List reads stay cached-first and errors retain saved rows.

refreshList uses quizzes.select('*,questions(count)') to cache question_count
without fetching prompts, options or keys. This is an existing relation count,
not a new backend field/RPC. Supabase documents the existing referenced-table
count syntax at https://supabase.com/docs/reference/javascript/select .
Opening an assessment still fetches the complete instructor-only detail snapshot.

instructorAssignmentsRefreshProvider joins the existing coalesced sync run and
checks assignment/access/queue errors before writing the account-local
instructor_classwork_posts:<classId> checkpoint. This separate sync_state marker
confirms successful empty reads without changing legacy post cursors. The list
uses it to distinguish an empty class from an incomplete/offline cache.
Pull-to-refresh and Retry refresh both sources; partial results remain visible.

The existing action immediately above the class navigation tabs opens the live
AssessmentFormScreen from instructor Classwork. Draft and published rows open
that same form; published edits use the approved confirmation. This list task
connects form loading, basic settings saves and saved-question summaries only.
The full question editor, question-bank UI, AI and publishing UI remain separate
builder work. New blank drafts can be saved with a title. No placeholder AI or
preview-save actions appear in the connected form.

The form preserves existing questions/options/keys and hidden settings, uses
Philippine date pickers with UTC writes, prompts on unsaved navigation and keeps
edits after failures. A started quiz exposes only title and closing-time edits.
Archived or unavailable classes are read-only; offline saves/creation/deletion
are disabled with a connection reason. A cached assessment can be opened offline;
a never-opened assessment offers reconnection/retry rather than blank content.

Row deletion calls deleteQuiz(classId,quizId): recheck ownership/archive/lock,
soft-delete through the existing quizzes UPDATE grant with locked_at IS NULL,
then remove confirmed local snapshots/list entries. Hide Delete for started or
archived assessments and offline. A start racing confirmation is refused and
reconciled; uncertain responses retain a recovery path rather than optimistic
success. No backend schema/grant/RPC or package changes.

Implementation and source/formatting review only. No tests, analysis, validation
builds, SQL, live API or device checks were run for this task. Owner acceptance
is pending for mixed rows/filters/time chips, navigation, deletion races,
archived permissions and persisted airplane-mode lists. No disposable testing
materials were created; existing unrelated frontend changes were preserved.


## M7-FE-02 reconnect and manual-refresh recovery - 2026-10-21

Owner reports that after airplane mode/Wi-Fi reconnection, pull-to-refresh and
Retry do not recover until a force-close. Source confirms instructor pull used
a cached offline flag to return before checking Android, and Retry was disabled
by that same flag. The refresh providers also lacked a connectivity dependency.

ConnectivityMonitor now shares platform events, resume checks and explicit
recheck() through the existing connectivityProvider StreamProvider<bool>
interface. Checks are bounded, older check results cannot overwrite newer
platform events, and error recovery emits a valid result even when it equals
the last successful value (the previous stream distinct filter could suppress
that recovery). Unchanged successful results remain deduplicated to avoid
unnecessary authentication/cache invalidation. A recheck does not recreate the
connectivity stream or change verified-session/role/server authorization rules.

Instructor Classwork pull and Retry now recheck Android first, allow Retry while
the cached signal is offline/unknown, coalesce repeated gestures and show real
refresh activity. Network-wait timeout restores the retry action while shared
background reads can finish; cached rows remain visible. Assignment/quiz refresh
providers react to connectivity changes, and failed cache subscriptions can be
reopened on manual retry. Class Stream/Files pull and existing student Classwork
pull also recheck rather than trusting a stale hint. Availability still does not
prove internet reachability: actual requests may fail and retain their retry path.
Archived classes remain read-only and authoring is never queued offline.

Added maintained connectivity regression tests for missed reconnect events,
stale initial checks and same-value recovery after errors. Tests, analysis,
builds, device and live API checks were not run; owner reproduction/retry and
archive/offline acceptance remain pending. No disposable materials created.


## M7-FE-02 owner acceptance - 2026-10-21

Status: Complete - accepted by owner. Owner states "okay accepted all" after
handoff of the instructor assessment-list checklist and the Wi-Fi/pull/Retry
recovery correction. This accepts the requested instructor Classwork list scope:
mixed assignment/quiz/exam rows, chips/details/date order, filters, new/edit form
entry, guarded deletion, cached/offline behavior, reconnection recovery and
archived read-only behavior. This supersedes earlier pending owner-acceptance
statements for M7-FE-02. Acceptance is owner-reported; no assistant device/live
verification or execution of the added regression tests is claimed. Full
question editing, publishing UI and student quiz-list integration remain separate
tasks and are not included in this completion. No retest requested absent new
changes or failures.


## M7-FE-04 question cards - 2026-10-22

Implemented in the connected instructor form; owner acceptance pending. Four
question types now use collapsible lazy reorderable cards with stable local
identities, explicit Save draft / Save changes, per-card status, totals,
duplicate/delete and accessible move actions. Validation covers unmounted cards
and unfinished accepted-answer input. MC: 2-10 nonblank options, 500 characters
each, one correct key. Identification: 1-10 accepted-answer chips, no new length
cap. Common limits: prompt 1000, integer points 1-1000 (default 1), explanation
500. Type is chosen on add; existing preview limitations are superseded here.

Delete copy: "Delete this question?" / "This question will be removed when you
save." / "Delete" / "Cancel". Card states: "Unsaved changes", "Saving...",
"Saved", "Save not confirmed". Invalid points show "Points need attention".
Typed accepted answers must be added or cleared before saving.

Public RPC contracts unchanged. Repository save adds optional local-ID progress
reporting. New AI duplicates retain provenance using the existing questions
update grant after save_question; uncertain writes preserve edits and require
reconciliation. Save retains expansion and scroll. Offline writes remain
disabled; unfinished edits are memory-only. Light theme and 130% text are the
agreed scope. Dark mode, generation, bank and publishing UI remain separate.

Maintained regression tests added, not executed. No tests, analysis, builds,
device, SQL or live API verification. Owner checks pending: all types/boundaries,
reorder/duplicate/delete, reopen persistence, failure/reconciliation/retry,
lock/archive restrictions and 50-question Redmi scrolling at 130% text.


## Assessment builder screenshot polish - 2026-10-22

Owner Redmi screenshots showed crowded combined number/type headings, no clear
collapse affordance, oversized pill inputs and date text wrapping beside labels.
Presentation-only changes: separate number/type rows, visible expand arrow,
icon-and-word save state, 16 dp card inset, two-line prompt entry, builder-local
14 dp input corners and compact padding, stacked date labels/values, stronger
switch labels with secondary hint text, bordered Add question menu affordance.
Light palette, Nunito, approved wording, counters, responsive heights, existing
save/RPC/permissions/offline handling retained. No global theme changes.
Source inspection/formatting only; no tests, analysis, builds, app/device checks
or live verification. Owner visual acceptance pending for all question editors,
130% text, keyboard, long dates/content, error/read-only states and saved reopen.
No disposable materials created.


### Add question placement - 2026-10-22
Moved the existing four-type Add question menu into a footer sliver after all
question cards, including the empty list. New questions still append and expand;
save/read-only/lock handling is unchanged. Formatting/source review only, no
runtime checks. Owner: add several types consecutively, verify the action stays
after the last editor, empty-list availability, disabled state and save/reopen.


## Three-page assessment builder - 2026-10-22

Connected builder now opens on Details (title/type/time limit/instructions),
then Settings (dates/shuffle/answer visibility/passing score), then Questions.
One route and draft; mounted page forms and separate scroll controllers retain
unfinished text and scroll offsets. Numbered step chips return to visited pages;
forward navigation validates intervening Details and Settings. Optional schedule
remains optional for drafts. Next does not save or make network requests.

Save draft / Save changes appears only on Questions and saves the entire draft,
including zero-question drafts. All-page validation opens the first invalid
page; invalid questions expand/reveal. Confirmed save stays on Questions. Back
and system Back return to the previous step; leaving Details uses the existing
unsaved-change confirmation. Read-only pages remain browsable; started content
restrictions, published warning, explicit saving, offline/reconciliation behavior
and light-theme/130 percent text support are retained. No new API or dependencies.
Unfinished edits remain memory-only. No publishing/auto-save added.

Maintained step-navigation/input-retention/zero-question-save regression test
added, not run. Formatting/source inspection only; no tests, analysis, builds,
device/SQL/live checks. Owner acceptance pending for forward/back/visited steps,
invalid settings and question redirects, text and scroll retention, save/reopen,
leave confirmation, offline/reconciliation, locked/read-only, keyboard/130 percent
text and 50-question Redmi scrolling. No disposable materials created.


### Builder navigation simplification - 2026-10-22
Owner rejected the step chips. Replaced them with a plain page heading and
Step N of 3 label. Next/Back and system/app Back now provide step navigation;
there are no clickable step chips. Shared draft/input/scroll retention,
validation and final-page saving remain unchanged. Formatting/source review
only; owner check navigation and header at 130 percent text. No tests run.


2026-10-22: Removed redundant Settings body heading; retained the single page header, timezone hint and all controls. Source review/formatting only; owner visual check pending.

2026-10-22: Removed duplicate Questions body heading and its spacer; retained page header, totals, cards and Add question footer. Source review/formatting only; owner visual acceptance pending.


### Exact validation targets - 2026-10-22
Next and final Save now reveal/focus the first invalid setup field rather than
scrolling to the page top. Save still validates Details, Settings, then Questions
and switches to the affected page. Question errors expand the card and reveal
the specific invalid prompt/points/option/explanation; accepted-answer issues
reveal the answer editor/error, and missing radio keys reveal their inline error.
Closing-time ordering failures reveal the closing-time control. Field values
remain intact; focus uses Flutter keyboard scrolling and immediate scrolling
respects reduced motion. Existing RPC and offline/save restrictions unchanged.
Maintained exact-field focus/reveal regressions added, not executed. Owner checks:
invalid time limit/passing score from scrolled positions, cross-page Save errors,
collapsed/offscreen invalid questions, missing answer keys/chips, keyboard and
130 percent text, and successful retry after correction. No runtime checks run.


### Builder arrow destination - 2026-10-22
Owner changed app-bar arrow behavior: Back to classwork exits the builder from
any step, preserving unsaved-change confirmation and save-in-flight guard.
Bottom Back still moves one step; system Back retains previous-step behavior.
This supersedes earlier app-bar previous-step descriptions. Maintained regression
checks arrow prompts from Questions and Keep editing preserves that step; not run.
Owner check arrow from all steps (clean/dirty), Cancel/Discard and bottom/system
Back. Formatting/source review only; no runtime verification.


## M7-FE-04 owner acceptance - 2026-10-22

Status: Complete - accepted. Owner explicitly reported "okay all runtime accepted"
for question cards and follow-up three-page builder, screenshot design changes,
Add question footer, simplified headings, exact validation targets and app-bar
Classwork destination with unsaved protection. Acceptance is owner-reported;
assistant did not independently run tests, builds, analysis or device/live checks.
Maintained question-card and step regressions remain unexecuted by the assistant.
Graphify publication remains blocked by five unrelated semantic source changes.
No disposable task materials, automatic staging, commit or push.


## M7-FE-05 save, publish and edit rules - 2026-10-22
Implemented; owner runtime acceptance pending. Questions adds Publish with all
schedule/empty/form/question errors and links to affected fields/cards. Confirmation
uses current totals and independent plurals. Confirm saves all edits first; failure
never proceeds to publish_quiz. Existing valid zero-question drafts remain supported.
Explicit RPC rejections use friendly messages; uncertain responses reconcile state
or require reload before replay. Success refreshes detail/list; chips use saved dates.
After a lock refusal, refreshed server state limits editing to title/closes_at.
Rejected local content remains visible read-only; subsequent save uses a fresh saved
baseline plus title/close only. Reload retains explicit discard confirmation.
Classwork retains edit/delete confirmations, guarded soft deletion and offline/archive
rules, with friendly deletion errors and an offline reason. No RPC/schema/dependency
changes, autosave or offline queue. This supersedes earlier publishing-UI deferrals.
Maintained publish unit tests and step widget coverage added, not run. Formatting and
source review only; no tests, analysis, builds, app/device, SQL or live API checks.
Owner checks: all error links/markers; essay/false keys; summary/cancel/save-before-publish;
status; failures/reconciliation/retry; start/save/delete races; locked title/close-only
save; offline/reconnect/archive; enlarged text. No disposable materials or Git actions.


### Assessment status and footer hierarchy - 2026-10-22
Owner requested separating Draft from the Details title field and prioritizing
Publish. Moved the saved-status chip into the shared page header beside the
heading/step count, outside the scrolling form. Questions now uses a full-width
primary Publish button, then a row with Back and secondary Save draft. Published
assessments retain primary Save changes and Back; read-only retains Back only.
Existing write, confirmation, validation, offline and lock guards retained.
Formatting/source inspection only; no tests, analysis, builds or app checks.
Owner visual acceptance pending at normal/enlarged text, keyboard, offline/busy,
published and read-only states. No disposable materials created.


### Primary action at bottom - 2026-10-22
Owner correction: Questions footer now places Back/secondary Save draft above
full-width primary Publish (or Save changes when published), consistent with
Next on preceding pages. Existing guards/handlers unchanged. Formatting and
source review only; owner checks button order, enlarged text and disabled states.
No tests or runtime checks run; no disposable materials.


## M7-FE-05 owner runtime acceptance - 2026-10-22
Status: Complete - accepted on owner report "btw all the runtime are accrepted".
Acceptance covers the requested draft saving, publication validation/confirmation,
friendly errors, status, published editing, locked title/closing-time rules,
delete/offline/archive behavior and follow-up header/footer layout (status chip in
page header; Back/Save draft row above bottom primary Publish/Save changes).
This supersedes the task's earlier runtime/visual acceptance-pending notes.
Evidence is owner-reported acceptance; assistant did not independently execute
tests, analysis, builds, device, SQL or live API checks. No broad acceptance of
unrelated tasks is inferred. No disposable materials, staging, commit or push.


## M7-FE-06 question bank - 2026-10-22

Implemented frontend instructor-own online-only bank reads/create/edit/soft-delete.
Assessment overflow opens the manager until Settings exists. Question menus save
validated current content independently of quiz saving. Picker searches prompts,
filters all four types and retains multi-selection across filters; selected copies
append in bank order and persist only through the existing explicit assessment
save/publish path using save_question. Copies have fresh local IDs and no bank,
question or option IDs. Bank edits/deletion never rewrite quiz copies.
Stable client UUID and frozen content snapshot reconcile uncertain bank creation
before retry, without overwriting an existing bank entry. Failed updates retain
editor input; deletion failures require refresh. No offline bank reads or queue.
Light theme, shared question fields/validation and Filo controls reused. No backend,
RPC, migration, dependency or Settings additions. Maintained conversion/picker/error
regressions added but not executed. Owner runtime acceptance pending; no tests,
static analysis, builds, device, SQL or live verification run. No disposable materials.


## M7-FE-06 owner runtime acceptance - 2026-10-22
Status: Complete - accepted on owner report "okay all runtime accepted".
Covers requested question-bank save/reuse across quizzes, all four question types,
copy independence under edits/deletion, search/type-filter/multi-selection, explicit
assessment saving, online/error/retry and lock/archive rules, plus shared modal
layout/height, scrolling, keyboard/enlarged text and dismissal follow-ups. Supersedes
earlier M7-FE-06 runtime/visual acceptance-pending notes. Evidence is owner-reported;
assistant did not run automated tests, analysis, builds, device, SQL or live checks.
No unrelated task acceptance inferred. No disposable materials or Git mutations.

## M8-BE-01 — exam answer text limit — 2026-10-22

Prepared migration `20261022100000_exam_answer_text_limit.sql` retains the existing `save_answer` signature and timestamptz result. For identification and essay questions, `p_text` may contain up to 10,000 characters (characters, not UTF-8 bytes). Longer text raises SQLSTATE `22001` with `Answer must be at most 10000 characters`; the previous answer remains unchanged. This replaces silent truncation. Caller/session/question checks still precede text validation; the existing deadline plus 15-second inclusive grace rule remains unchanged. No frontend save_answer caller currently exists in the source search. Future callers should retain unsent text and request shortening rather than retrying the same oversized payload. Owner-reported DEV exam regression accepted on 2026-10-22: 178 PASS, 0 FAIL, overall PASS, failures []. This establishes the requested SQL behavior on owner evidence; the assistant did not independently verify deployment or migration history.
