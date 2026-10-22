# Filo Project Decisions

## M3 post rules and developer handoff - 2026-10-17

Sources read: FLOW F4 (`docs/MD Files/03-app-flow-document.md`), SCHEMA 4.3 and 9 (`docs/MD Files/05-background-schema-document.md`). Source inspected: migrations 0003, 0006 and 0008 and `frontend/lib/features/posts/presentation/create_post_screen.dart`. This is a requirements/task handoff, not implementation completion.

### Confirmed rules and accepted decisions

- **M3-D01 - Decided: derive type from content.** Require submission on means Assignment, regardless of attachments. Otherwise attachments (files or links) mean Material; otherwise Announcement. No manual type selector. Assignment points and due date/time are required; Points defaults to 100. Non-assignment points/due date are null. Accept late submissions is shown for assignments.
- Maximum 10 live attachments per post, files and links combined; maximum 25 MB (26,214,400 bytes) per file. Video uploads are blocked by SCHEMA 9 extensions, case-insensitively: mp4, mov, avi, mkv, webm, m4v, 3gp, wmv. Video links are allowed. Exact FLOW copy: "Videos can't be uploaded. Add a link instead." and "This file is too large. The limit is 25 MB."
- Publish immediately; no scheduled posts or saved post drafts. Assessment and student-submission drafts are separate features. Post deletion affects server copies; existing phone downloads remain.
- **M3-D02 - Decided: supplement FLOW F4 with assignment file controls.** With Require submission on, show **Allow file uploads** (default on, `posts.allow_files`) and **Max files** (integer 1-5, default 5, `posts.max_files`). Disable Max files when uploads are off, retaining a valid stored value. These govern student submission files, not the instructor's post attachments. Links/text remain available when file uploads are off. These controls exist in SCHEMA/database but are omitted from FLOW F4.
- **M3-D03 - Decided: accept visible posts before file uploads finish for the school project.** Publish the post record first; show pending files as **Uploading...**, ready files as available, and failed files as **Upload failed** with instructor **Retry** and **Delete**. Students see pending/unavailable state without an active download action. Saving the post does not mean every file is ready.
- Retry reuses the post/attachment identity and path, avoiding duplicate posts, attachments and new-post notifications. Delete removes the failed attachment and any partial server object; cleanup failures offer retry. Keep the published post. Recalculate content-derived type on attachment changes, with Assignment taking precedence. Pending/failed files occupy the 10 slots until deleted. Refresh after an uncertain save before retrying publication.
- Posting requires connectivity. Connection loss after publication leaves the post visible with pending/failed files; Retry resumes when online. In-memory upload recovery is sufficient for this school-project scope; durable background resume after app termination is not promised. Reopened unfinished files remain visibly unavailable/removable and may require local-file reselection. BE/FE must agree and document readiness representation: current `post_attachments` has no upload-status column. These states are not post drafts.

### Existing implementation

Migration 0003 already defines posts/attachments, assignment-field constraints, allow_files=true, max_files=5 with range 1-5, and 25 MB attachment metadata limits. Migration 0006 defines a 10-attachment trigger and insert-time new-post inbox notifications; 0008 defines private materials paths under class_id/post_id/file. These are source definitions, not fresh deployment/runtime evidence. The current create screen is preview-backed, with string attachment placeholders, a 10-item UI cap and derived type. It defaults points to 20 and lacks both file controls and real uploads/Retry. Complete these paths rather than recreate tables or treat preview posting as live.

### Seven developer tasks - board handoff complete (owner-reported)

Recorded board: https://dailywork.pro/tasks-assignee=me&task=803 . Browser inventory is empty; plugin discovery returned no DailyWork connector, and connected Notion search returned no Filo result. No live M3 records were created, assigned or verified. The project owner confirmed on 2026-10-17 that Rose Jean Tupaz owns M3-BE-01 and M3-BE-02, and Kent Aian Tabuelog owns M3-FE-01 through M3-FE-05. The project owner subsequently confirmed on 2026-10-17 that the remaining board work was completed: all seven tasks are on the board with owners and dates. Board completion is accepted on that owner report; the assistant did not create or independently inspect the records. Exact board IDs/links and actual due-date values were not supplied. The dates below remain the original proposals, not a transcription of the completed board.

| ID | Task | Confirmed owner | Proposed due (Asia/Manila) | Depends on | Done when |
| --- | --- | --- | --- | --- | --- |
| M3-BE-01 | Post persistence, derived kind and access | Rose Jean Tupaz | 2026-11-23 | M2 class/access contracts | Complete real create/read/edit/delete; derive kind including link-only materials and assignment precedence; enforce title 120/body 5000, assignment fields and file controls; verified owning instructor writes only to open classes; authorized reads and deleted/removed/archived restrictions; immediate publication with no draft/schedule; record actual contracts in API_CHANGES. |
| M3-BE-02 | Attachment lifecycle and private storage | Rose Jean Tupaz | 2026-11-24 | M3-BE-01 | Document readiness contract with FE; enforce shared 10-slot limit including concurrent writes, 25 MB and video block; authorized private class/post paths and signed access; idempotent Retry/Delete, partial-object cleanup, type recalculation and no duplicate notifications; document failures and uncertain-outcome recovery. |
| M3-FE-01 | Live Stream, cards and post detail | Kent Aian Tabuelog | 2026-11-24 | M3-BE-01 | Replace preview reads with authorized cached/live posts; distinguish all three kinds; assignments surface in Classwork and student To-do; loading/confirmed empty/error with Retry/offline cache states; pending files have no working download action. |
| M3-FE-02 | Create/edit form and assignment controls | Kent Aian Tabuelog | 2026-11-25 | M3-BE-01 | Enforce title/message limits and derived kind; default Points 100, required assignment due date/time, Accept late submissions, Allow file uploads and Max files 1-5; correct non-assignment payload; real immediate save with busy/offline/uncertain-save guards; no draft/scheduling controls. |
| M3-FE-03 | File picker, upload progress, Retry/Delete | Kent Aian Tabuelog | 2026-11-26 | M3-BE-02, M3-FE-02 | Real selection, shared attachment cap, 25 MB/video rejection with exact FLOW messages; visible post during upload; per-file uploading/ready/failed states; Retry/Delete without duplicates; handle disconnect, partial objects, cleanup failure and reopen/reselection per M3-D03. |
| M3-FE-04 | Links and Drive preview | Kent Aian Tabuelog | 2026-11-27 | M3-FE-02-03 | Valid links share the 10-slot cap; link-only means Material and video links allowed; best-effort Drive icon/type/name preview without Drive permissions; hint: "Set sharing to Anyone with the link so students can download it." Preview errors/offline keep the link and allow fallback/retry without blocking publication. |
| M3-FE-05 | Edit/delete, refresh and access states | Kent Aian Tabuelog | 2026-11-28 | M3-FE-01-04, M3-BE-01-02 | Owner card menu edits/deletes real posts; attachment edits maintain derived type; due changes refresh reminders; delete copy explains retained phone downloads; archive/revoked-access restrictions; consistent Stream/detail/Classwork/To-do refresh; safe Retry and refresh after offline/unknown outcomes. |

Requirements/decision and developer-board handoff complete on the owner's 2026-10-17 confirmation. This does not mark the seven implementation tasks themselves done. No app changes, tests, static analysis, builds or live API verification run. Runtime acceptance pending owner checks after implementation: all three kinds including link-only/removal; 10/11 attachments; 25 MB/video boundaries; Max files 1/5/invalid and uploads-off; student-visible uploading; interrupted Retry/Delete without duplicates; offline recovery; edit/delete/access and reminder refresh. No disposable testing materials created.

## Development Supabase project

- Recorded: 2026-10-13
- Environment: Development
- Project name: `filo-app`
- Region: Northeast Asia (Seoul), `ap-northeast-2`.
- Dashboard URL: https://supabase.com/dashboard/project/fiobwfzmqcffbpixzvbq
- Dashboard access and healthy project status: confirmed by project owner's screenshot on 2026-10-13.
- Project reference ID: `fiobwfzmqcffbpixzvbq`
- Project URL: https://fiobwfzmqcffbpixzvbq.supabase.co

API keys are stored in the ignored `backend/.env` file within the unified `filo-app` repository and are excluded from this document.

## Development Firebase project

- Recorded: 2026-10-13
- Project ID: `filo-app-58815`
- Project number: `93454787470`
- Android application ID: `com.filo.filo`
- Firebase Android app ID: `1:93454787470:android:cd86514f46ede6d246fadf`
- Dashboard URL: https://console.firebase.google.com/project/filo-app-58815/overview
- Android configuration: ignored `frontend/android/app/google-services.json`
- Cloud Messaging API (V1): enabled, confirmed by project owner on 2026-10-13.
- Firebase service account key: created by project owner; file presence verified on 2026-10-13 at `C:\Users\Dell\Filo Private Keys\firebase-dev-service-account.json`, outside the Git repository. Key contents are not recorded here.
- Dashboard access: Firebase settings accessed by project owner during setup; Supabase dashboard access confirmed by screenshot on 2026-10-13.

## Development cloud setup status

- Setup complete on 2026-10-13: both dashboards accessible, Android app registered, Cloud Messaging API (V1) enabled, credentials stored outside Git, and non-secret project details recorded locally in this document.
- SQL migrations and Flutter Firebase integration are subsequent tasks.

## Google sign-in and Android signing setup

- Google Cloud project ID: `filo-app-58815`.
- Android application ID: `com.filo.filo`.
- Android debug SHA-1: `CA:E6:6D:34:A4:FF:2E:24:85:A3:DA:66:A4:6B:B5:47:10:D3:FF:0D`, supplied by project owner on 2026-10-13.
- OAuth consent configuration: created, confirmed by project owner's screenshot.
- Downloaded OAuth client ID: `93454787470-mpk4b155p6jhk7htj14cbesvg8unfmip.apps.googleusercontent.com`. Export uses `installed` configuration and contains no client secret; confirm Android client type in Google Auth Platform.
- Web OAuth client ID: `93454787470-eqkitfol589l05if4gdqr3boe7b3at45.apps.googleusercontent.com`, verified from the web client export on 2026-10-14.
- Authorized OAuth redirect URI: `https://fiobwfzmqcffbpixzvbq.supabase.co/auth/v1/callback`, verified from the export.
- Web client secret: export stored outside the repository in `C:\Users\Dell\Desktop\Filo Development`; password manager storage confirmed by project owner on 2026-10-14. Secret value is excluded from this document.
- Google provider setup in Supabase: enabled and saved, confirmed by project owner on 2026-10-14; sign-in integration testing is pending.
- Release keystore: created by project owner; intended location `C:\Users\Dell\Filo Private Keys\filo-release.jks`, alias `filo-release`.
- Android release SHA-1: `77:57:5D:7B:9F:45:34:D8:57:DD:06:AA:4A:C1:09:BF:E2:0F:3E:0C`, supplied by project owner on 2026-10-14.
- Release Android OAuth client ID: `93454787470-4s5dvf9tdmtfodcpeq92pdnvvo5jkoul.apps.googleusercontent.com`, supplied by project owner on 2026-10-14.
- Release keystore password: saved in password manager, confirmed by project owner on 2026-10-14.
- Two encrypted keystore backups: one on USB and one in a private cloud folder, both tested; confirmed by project owner on 2026-10-14.

## OTP email and AI credentials

- Dedicated Gmail sender, 2-Step Verification, private recovery codes, and `Filo OTP Backend` app password: completed; credentials saved in password manager, confirmed by project owner on 2026-10-14.
- Gemini API key: created and saved in password manager, confirmed by project owner on 2026-10-14.
- Secret values are excluded from this document.

## Pre-M1 credential setup status

- Completed on 2026-10-14 based on project owner confirmations: OAuth client IDs recorded, Google provider enabled in Supabase, Gmail OTP and Gemini credentials saved in password manager, release SHA-1 recorded, and two encrypted keystore backups tested.
- Application integration and end-to-end sign-in, OTP email, and AI tests remain subsequent implementation tasks.

## M1 sign-in rules and developer handoff

- Recorded: 2026-10-14 (Asia/Manila).
- Project owner reported this activity complete and requested that it be logged. This records that report; board completion has not been independently verified.
- Sources read: `docs/MD Files/03-app-flow-document.md`, FLOW F1; `02-technical-requirements-document.md`, TRD 5; and `05-background-schema-document.md`, SCHEMA 4.1 and 7.

### Confirmed requirements

- OTP: exactly 6 digits, 10-minute expiry, maximum 5 attempts, and 60-second resend cooldown. These exact values resolve TRD 5.2's approximate, assumption-marked timing using the project owner's instruction and SCHEMA 4.1. Store only the code hash; consumed or expired codes cannot verify a session.
- Require OTP on first login and new devices. Trusted devices can skip the code entry on later logins, but the new login session must still be verified on the server before accessing protected data. Use `trusted_devices` and server-only `verified_sessions`, keyed by the authenticated token's session ID. An unverified session must not access protected data; enforce this in database security, not just navigation.
- Role: choose Student or Instructor on first login, confirm the selection, then lock it in the database. Profile email and role are read-only. Display FLOW F1's warning: "You can't change your role later. If you pick the wrong one, you'll need to delete your account and sign in again."
- Wrong or expired OTP message: "That code isn't right or has expired. Try again or request a new one."
- Privacy consent: show the collected data (name, email, photo, submissions, grades, and leave-app counts) and disclose that AI features send text to Google Gemini. Require consent at the details overview and store `privacy_accepted_at`.

### Consent wording and remaining verification

The source documents specify consent content but do not supply a complete verbatim checkbox label. Suggested implementation copy, pending project owner confirmation: "I have read and accept the privacy notice. Filo collects my name, email, photo, submissions, grades, and leave-app counts. When I use AI features, text I submit is sent to Google Gemini for processing."

SCHEMA 7 identifies `send-otp` and `verify-otp` as the server functions for creating/checking codes, trusting devices, and verifying sessions. Token session-ID availability and SMTP delivery remain implementation checks, not completed integration tests.

### Developer task board status

Required tasks: `M1-BE-01`, `M1-BE-02`, `M1-BE-03`, `M1-BE-04`, `M1-FE-01`, `M1-FE-02`, `M1-FE-03`, `M1-FE-04`, and `M1-FE-05`.

The implementation plan calls for a GitHub Projects board with Backlog, Ready, In progress, In review, Testing, and Done columns. The repository is `https://github.com/rogiie234/filo-app`. The local documents do not define these nine M1 task descriptions, named owners, due dates, or a board URL; their existing Phase 1 identifiers use `P1-*`. Team roles and schedule are explicitly assumptions.

### Task board screenshot evidence

The project owner supplied two task-board screenshots on 2026-10-14. Together they confirm all nine developer task records in Backlog with displayed due dates. Eight have named owners in the screenshots. The project owner subsequently confirmed that all FE tasks, including M1-FE-05, are assigned to Kent Aian Tabuelog. The screenshots omit the year; the dates below preserve the displayed values.

| Developer task | Board ID | Owner | Due date shown |
| --- | --- | --- | --- |
| M1-BE-01 | FAALM-00015 | Rose Jean Tupaz | Oct 28 |
| M1-BE-02 | FAALM-00016 | Rose Jean Tupaz | Nov 4 |
| M1-BE-03 | FAALM-00017 | Rose Jean Tupaz | Nov 6 |
| M1-BE-04 | FAALM-00018 | Rose Jean Tupaz | Nov 6 |
| M1-FE-01 | FAALM-00019 | Kent Aian Tabuelog | Oct 30 |
| M1-FE-02 | FAALM-00020 | Kent Aian Tabuelog | Nov 2 |
| M1-FE-03 | FAALM-00021 | Kent Aian Tabuelog | Nov 8 |
| M1-FE-04 | FAALM-00022 | Kent Aian Tabuelog | Nov 12 |
| M1-FE-05 | FAALM-00023 | Kent Aian Tabuelog | Nov 13 |

The screenshot also shows QA task `M1-QA-01` (`FAALM-00014`), assigned to Jhondel Cabugsa and due "Tomorrow"; it is outside the nine developer tasks.

The supplied board is evidence of existing task records; its platform and URL are not established by the screenshots. No developer tasks were created or assigned during this logging update. All nine developer task records and due dates are supported by screenshot evidence, and all nine owners are established by the screenshots plus the project owner's confirmation. The task-board handoff is recorded as complete on that basis. M1-FE-05 appeared unassigned in the earlier screenshot; its owner is recorded from the later confirmation, without a live board update or recheck. Final consent wording remains pending confirmation.

## Supabase migration setup â€” 2026-10-14

- Initialized `backend/supabase` using `supabase init` successfully.
- Staged the eight draft migrations, 0001 through 0008, from `docs/SQL files` in `backend/supabase/migrations`, retaining their order and contents. Migration 0009 is outside this task and was not staged.
- Attempted to link to development project `fiobwfzmqcffbpixzvbq`. Supabase rejected the request: the current CLI account lacks the necessary privileges to access the project endpoint.
- No remote migrations were applied. SQL fixes and live verification of tables, policies, and the four private storage buckets remain pending authorized project access.


### Supabase migrations applied â€” 2026-10-14

- After the project owner logged in to the CLI, linking to `fiobwfzmqcffbpixzvbq` succeeded.
- `supabase db push --dry-run` showed exactly migrations 0001 through 0008 pending, with no remote migration entries.
- `supabase db push --yes` applied all eight files in order without errors. No SQL fixes were required.
- `supabase migration list` subsequently confirmed matching local and remote versions 0001 through 0008.
- Read-only verification using `supabase db query --linked` confirmed all 24 public application tables with row-level security enabled, 33 public policies, and 16 storage object policies.
- Confirmed all four private buckets: `avatars` (524288 bytes), `banners` (2097152 bytes), `materials` (26214400 bytes), and `submissions` (26214400 bytes).
- Verification used the linked project's live database through the Management API. A visual dashboard check remains pending because no browser surface is available in this session.
- Migration 0009 was not applied; it is outside the requested scope.


### Dashboard confirmation and task completion â€” 2026-10-14

- The project owner confirmed seeing the deployed tables, policies, and storage buckets in the Supabase development dashboard after completing the requested visual check.
- This dashboard confirmation is owner-reported; the live database inventory and matching migration history were independently verified through the CLI as recorded above.
- Task status: complete. Backend initialized and linked to the development project, all eight migrations (0001â€“0008) applied in order without errors, and dashboard verification confirmed. No SQL fixes were required.



## M2 class rules and task handoff - 2026-10-15

Sources read: FLOW F2, F3, F15 (`docs/MD Files/03-app-flow-document.md`); SCHEMA 4.2, 7.1 (`docs/MD Files/05-background-schema-document.md`).

### Confirmed rules and decisions

- Join code: server-generated, unique, case-insensitive, exactly 6 characters from letters/digits without look-alikes. It never changes, including after archive or recovery.
- Instructor approval is required. Pending students have a non-openable Waiting for approval card. Only the owning instructor manages approvals and removals.
- Removal retains submissions, grades and the membership row; access is revoked. Downloaded files stay on the device.
- Students can leave after confirmation. Work stays with the instructor and downloaded files stay locally. Rejoining requires approval.
- Archive is read-only: existing members can read materials and grades, but no one can post, submit or take quizzes. The instructor can restore the class.
- Delete requires typing the section exactly, sets deleted_at, and is recoverable by the owner within 14 days. Permanent content/storage cleanup follows the recovery period.
- **M2-D01 - Decided: declined students can request again.** Resolve FLOW F2's assumption as yes, matching SCHEMA 4.2/7.1. Reuse the same membership row: declined, removed or left becomes pending, with instructor approval required again. Retain prior work.
- **M2-D02 - Decided: archived classes refuse new requests.** Resolve FLOW F2's assumption as yes, matching SCHEMA 7.1's archived result. Message: "This class is archived and no longer accepts new students." Restoring the archive permits new requests again. Pending requests must not bypass archived read-only restrictions.

### DailyWork handoff - prepared, not created on board

Board supplied by owner: https://dailywork.pro/tasks-assignee=me&task=803 . This link does not establish that M2 task records exist. Browser inventory is empty; in-app browser and Chrome are unavailable. No DailyWork connector was found. No live tasks were created or assigned in this session.

The project owner confirmed on 2026-10-15 that Rose Jean Tupaz owns all four M2 backend tasks and Kent Aian Tabuelog owns all five M2 frontend tasks. These are confirmed handoff owners; live DailyWork assignment is still unverified. Due dates are pending input or live-board scheduling context. These class-only M2 task IDs are a new breakdown; implementation-plan P2 IDs also cover posts and are not a direct numbering match.

| ID | Task | Confirmed owner | Due date | Depends on | Done when |
| --- | --- | --- | --- | --- | --- |
| M2-BE-01 | Class creation, metadata and immutable code | Rose Jean Tupaz | Pending | M1 session gate | Instructor creates Course/Section/School Year and default/preset/upload banner; code is unique, case-insensitive, exactly 6 characters and immutable; owner/code edits and unauthorized creation are refused. |
| M2-BE-02 | Join requests and approval RPCs | Rose Jean Tupaz | Pending | M2-BE-01 | Preserve SCHEMA 7.1 contracts; test requested/not_found/already_member/already_pending/archived; declined/removed/left reuse row as pending; owner-only approve/decline/approve-all; notification records; archived joins refused. |
| M2-BE-03 | Membership access, remove, leave and classmates | Rose Jean Tupaz | Pending | M2-BE-02 | Remove/leave revoke access and keep work/member rows; rejoin needs approval; implement/verify role-checked list_classmates per implementation plan 5.1 and update API_CHANGES for planned addition; unauthorized/cross-class checks pass. |
| M2-BE-04 | Archive, soft delete, restore and retention | Rose Jean Tupaz | Pending | M2-BE-01-03 | Server enforces archive read-only; archive restore works; exact section required to delete; recovery works before 14-day deadline and fails at/after it; verify database/storage purge after retention; save lifecycle/security smoke tests in backend/tests. |
| M2-FE-01 | Classes list, search and membership states | Kent Aian Tabuelog | Pending | M2-BE-01-02 | C1 shows real role-appropriate classes, search, non-openable pending cards and Archived section; handle cached/loading/empty/error/offline states and access changes. |
| M2-FE-02 | Join sheet and all request outcomes | Kent Aian Tabuelog | Pending | M2-BE-02, M2-FE-01 | C2 handles all five RPC outcomes with FLOW F2 messages; declined/removed/left can request again; wrong code keeps sheet open; offline Join disabled with reason; approval/decline refresh updates cards. |
| M2-FE-03 | Create class, details, copy code and banner | Kent Aian Tabuelog | Pending | M2-BE-01, M2-FE-01 | C3 creates required fields/default or chosen banner and opens Stream shell; C4 shows permanent code and Copy; C7 updates banner; error/offline states handled. |
| M2-FE-04 | Requests, students, classmates, remove and leave | Kent Aian Tabuelog | Pending | M2-BE-02-03, M2-FE-01 | C5 approve/decline/approve-all and pending indicators work; C6 shows authorized classmates; remove/leave confirmations explain retained work/files; revoked access closes class and refreshes list. |
| M2-FE-05 | Archive, read-only UI, delete and recovery | Kent Aian Tabuelog | Pending | M2-BE-04, M2-FE-01, M2-FE-03 | C7/C8 archive/restore preserve code and read-only files/grades; writes/quizzes and archived joins disabled; exact section gates delete; recovery only within 14 days; instructor/student lifecycle checks pass. |

Completion gate remains open: verify all nine IDs on DailyWork with actual owners and due dates, then record board IDs/links here. Prepared task descriptions are not board completion or implementation completion. Docs remain Git-ignored under the existing repository rules.




## M2 join/approval SQL verification preparation ? 2026-10-16

- Branch inspected: `backend`. Read the Graphify reports, queried class RPC relationships, checked all indexed file fingerprints (zero mismatches), and inspected current migrations and canonical Markdown requirements for join, approval, removal and notification rules. Graphify is navigation evidence, not remote deployment proof.
- Prepared `backend/tests/class_join_approval.sql` and its adjacent `README.md`. Covers wrong code, valid join, duplicate pending join, approval, existing member join, removal/rejoin to pending, decline/re-request, archived join, and bulk approval with two pending students and an empty repeat.
- Assertions cover retained membership identity, decision metadata, exact notification counts and payloads, instructor/student recipients and authenticated inbox isolation. RPCs execute with the authenticated role and disposable verified-session JWT claims; fixture setup and complete-row inspection use postgres. The transaction ends with ROLLBACK.
- Status: PREPARED, NOT EXECUTED. Per project owner instruction, no SQL tests, live dev calls, migration deployment or automated test execution were performed. Real dev acceptance and permission to rely on these RPCs remain pending the owner's run and reported results. This is SQL-level verification preparation, not login, push-delivery, concurrency or screen acceptance.
- No confirmed sequential-flow defect was identified by source review, so no speculative migration was added. Any failure reported from the dev run must be investigated and fixed in a new migration, preserving existing migration history; then the owner reruns the script.
- Results reported by project owner on 2026-10-16 (Asia/Manila): all 92 result rows PASS, steps 1 through 92, for the supplied dev run guide targeting project `fiobwfzmqcffbpixzvbq`. Evidence: complete CSV pasted into this conversation. The output itself does not identify the project or independently attest transaction completion. This supersedes the preparation status above: requested SQL scenario verification is accepted on owner-reported dev evidence; the assistant did not execute tests. All nine scenarios, notification payload/count assertions and three actors' inbox RLS checks passed. No failing behavior was reported and no corrective migration is required. Push delivery, screen behavior and concurrency remain outside this run.


## M2 lifecycle/security corrections - 2026-10-16

Inspected branch backend, Graphify reports/query, canonical docs and current migrations. Initial indexed fingerprints matched. Source review found deleted-class member visibility, normalized section deletion, former-member work/grade/storage and exam RPC access, and archived write/approval gaps. Added 20261016100000_class_lifecycle_access.sql without editing old migrations or changing RPC signatures. Extended the existing join/approval script with lifecycle and security checklist 1/4/8 assertions and positive controls.

Status: PREPARED, NOT EXECUTED OR DEPLOYED. The owner requested exclusive test execution. Earlier 92 PASS evidence covers only the original script. Follow backend/tests/README.md. Download retention, UI refresh, Storage HTTP access and scheduled cleanup need owner verification. No test success or security checklist acceptance is claimed.


## Owner-reported lifecycle SQL acceptance - 2026-10-16

Owner supplied complete CSV with 244 sequential result rows, all PASS, after the corrective get_result alias migration. This supersedes the pending SQL run and earlier failure status. Covers original join/approval checks, archive/read-only/restore, exact section deletion, deleted-class owner/member visibility, recovery before 14 days and refusal at/after the boundary, removal/leave, retained work, rejoin approval, and SQL security checklist items 1, 4 and 8 access controls.

Evidence is owner-reported execution following the same DEV run instructions; CSV does not independently identify the database, attest final rollback, or reconcile migration history. The assistant did not run SQL tests. Checklist 8's device download-retention portion remains pending a phone check; UI refresh, Storage HTTP/signed URLs, concurrency and scheduled purge remain outside this SQL evidence. Backend SQL acceptance is complete on supplied evidence; do not describe phone or scheduled cleanup acceptance as complete.


## 2026-10-17: Class membership frontend completion

Source implementation: the existing class shell, tabs, instructor code/Copy, request Approve/Decline/Approve all and cache-backed pending dots are retained. Added separate role menus and details (code/Copy instructor only), student Classmates and Leave, instructor Students and Class settings (archive/restore). Enrolled students now have Remove with the retained-work/downloads and approval-on-rejoin confirmation. Mutations use existing repositories and refresh the cache; offline/busy/archived guards apply to instructor membership management. Unknown outcomes instruct the owner to refresh before retrying.

Classmates calls list_classmates(p_class), excludes the signed-in student, and distinguishes loading, confirmed empty, offline and fetch/permission failure with Retry/pull-to-refresh. It uses no synthetic membership rows and does not persist the roster. Names and placeholder avatars are displayed; private photo signing and banner editing in Settings are outside this change. Existing content placeholders and preview data are preserved. No push/realtime implementation added; pending dots update on the existing refresh lifecycle.

No tests, static analysis, builds, device checks or live API calls run. Runtime acceptance is pending the owner's instructor approval/removal and student classmates checks, including offline/errors/retries and access after removal/leave.


## Post SQL acceptance preparation ? 2026-10-17

Status: implementation prepared; NOT executed or deployed by the assistant. Dev acceptance and security checklist items 1, 4 and 8 remain pending the owner.

Existing migrations already enforce assignment-only points/due dates, authenticated owner writes, active membership reads, archived-class write refusal, editable-column grants (kind is immutable), and notify_new_post inbox fanout. Added maintained rollback-only backend/tests/posts.sql with disposable verified-session fixtures, real authenticated role execution, fail-fast SQLSTATE/row-count assertions, and privileged persisted-effect checks. Covers all three kinds, assignment fields, allowed/forbidden edits, ten attachment slots and restore overflow, soft-delete tombstones, active/pending/removed members, foreign instructor isolation, archive refusal, exact notification recipients/counts and no notification on edit/delete/failure. Checklist 1 includes actual peer submission, returned grade and exam-session fixtures; checklist 4 exercises foreign instructor reads/writes; checklist 8 removes a previously active student before checking reads again.

Source review found the attachment trigger counted only inserts without serializing concurrent additions and did not guard restores. New migration 20261017100000_post_attachment_limit.sql locks the parent post before counting live attachments, excludes the current attachment, applies to insert and deleted_at/post_id updates, and raises SQLSTATE 23514 on overflow. Ten means live attachments; soft-deleted slots can be reused. Post soft deletion retains the row/tombstone for existing sync contracts; this task does not alter tombstone read semantics. Type derivation and later attachment lifecycle work remain separate M3 tasks: this acceptance scope keeps the existing immutable kind contract, despite the broader M3 derived-type editing requirement.

Owner: apply the new migration on DEV, then run the whole posts.sql file as postgres in one SQL Editor execution. Every result must be PASS with no exception and the transaction must reach ROLLBACK. Separately verify two concurrent connections competing for the tenth attachment (only one succeeds), restore overflow, and retained device downloads after removal. Retry failed overflow after freeing a slot; refresh after uncertain saves before retrying to avoid duplicate posts/inbox rows (raw inserts are not idempotent). Inbox assertions do not prove push delivery, UI/offline behavior, or Storage access. No tests, static analysis, builds, SQL scripts or live API checks were run. No disposable local testing materials were created; the requested SQL script is maintained regression coverage.


## Owner-reported DEV post SQL acceptance - 2026-10-17

Owner supplied 86 sequential results from backend/tests/posts.sql; every row is PASS. This supersedes the pending SQL acceptance status above. Covers assignment-only fields, all three post kinds, exact active-student inbox fanout, peer submission/returned-grade/exam-session isolation (checklist 1), editable columns and immutable kind, ten live attachments, slot reuse and restore overflow, foreign instructor isolation (checklist 4), active/pending/removed member access including removal of a previously active student (SQL portion of checklist 8), physical-delete refusal, soft-delete tombstones, no repeated notifications on edit/delete, and archived-class write refusal. The requested DEV SQL gate is accepted on owner-reported evidence, not independent assistant execution or remote migration-history inspection.

Still unproven by this output: two-connection attachment concurrency, retained downloaded files on a removed student's phone (device portion of checklist 8), UI/offline/retry behavior, Storage URLs and push delivery. The script ends in ROLLBACK; supplied result rows alone do not independently establish cleanup completion. No assistant tests, SQL execution, static analysis, builds or live API verification run. No disposable testing materials created.

## Materials storage hardening - 2026-10-17

Source review found migration 0008 already defines private materials, 26,214,400 bytes per object, owner writes, owner/active-member reads and extension video blocking on insert. Migration 20261017110000_materials_storage.sql reasserts bucket privacy/size, requires exactly class_id/post_id/file referencing a visible non-deleted post in that class, and extends the canonical eight-extension block to updates/renames/upserts. Existing verified-session and class lifecycle policies remain authoritative. This is prepared source, not a deployed-bucket inspection or runtime acceptance.

Supabase Free includes **1 GB file storage**, shared across storage buckets, per official documentation checked 2026-10-17: https://supabase.com/docs/guides/storage/pricing . This is separate from the app's 25 MiB per-file limit. **Current object metadata usage (owner-reported 2026-10-17): banners, 2 objects, 279,418 bytes (approximately 272.87 KiB).** The owner supplied one row from the per-bucket query below. If this is the complete result, total recorded object size is 279,418 bytes and materials has no recorded objects; absent rows do not establish bucket existence or configuration. Dashboard billing Storage Size remains unreported. No independent live API verification was performed. For a current per-bucket metadata snapshot, the owner may run `select bucket_id, count(*) objects, coalesce(sum((metadata->>'size')::bigint),0) bytes from storage.objects group by bucket_id;` in Dashboard SQL Editor. This snapshot is not the billing period's time-averaged usage.

Owner verification uses ordinary user JWTs that passed the app's verified-session gate, never service-role credentials (which bypass RLS). Signed download URLs are bearer capabilities: a non-member must be unable to mint a URL or download through the authenticated endpoint, but a copied valid signed URL remains usable by anyone holding it until expiry. Use 60 seconds for the owner expiry check and a fresh uncached request after expiry. See https://supabase.com/docs/guides/storage/serving/downloads . No custom signing endpoint or frontend upload integration is claimed by this migration. Video blocking follows SCHEMA 9 extensions mp4/mov/avi/mkv/webm/m4v/3gp/wmv, not content inspection; renamed video bytes with a permitted extension are outside this contract.

No tests, builds, static analysis, SQL execution or live API checks run. Deployment and runtime acceptance remain pending owner checks; object metadata usage is recorded from owner output above. Disposable fixture instructions are supplied in chat; no fixture files or one-off test scripts were created or committed.

### Materials bucket configuration accepted on owner output - 2026-10-17

Owner supplied `id,public,file_size_limit` with `materials,false,26214400`. Bucket existence, privacy and configured 25 MiB object limit are accepted on this owner-reported SQL result. This does not prove migration 20261017110000 was applied, path policy enforcement, actual upload/download permissions, video rejection or signed-link expiry. Those runtime checks remain pending. Assistant did not run tests or live verification; no disposable materials created.

### Materials Storage HTTP acceptance - owner reported 2026-10-17

Owner performed Postman checks; assistant did not execute tests or live API calls. Supplied screenshots show successful owner PDF upload at ec530959-2b26-4e08-96a0-110211991f2f/30ab5c48-1643-468e-9a6a-6f522cec0061/check.pdf, successful signing reported under active student, PDF retrieval with 200 OK, expired signed URL rejection (exp timestamp check failed), and non-member signing returning Object not found with no URL. Account roles were supplied by owner; screenshots do not independently authenticate each role. Later PDF/video controls used original class a763cc8d-fd13-4898-bde6-4c79470924d2 and post 310660e2-805c-40ab-bf9a-86ade81fed4a after owner/account mismatch was diagnosed. Initial duplicate-path, wrong-account and oversized-video errors were not counted as video acceptance.

Owner subsequently confirmed MP4 and MOV AccessDenied, then replied "done all" to remaining avi/mkv/webm/m4v/3gp/wmv/uppercase MP4 denials plus successful same-owner PDF control. Core upload/read/non-member/expiry/video-extension checklist accepted on owner screenshots and report. Oversized upload rejection also observed. Exact size boundary, malformed paths, update/rename/upsert restrictions, revoked/pending users, offline retry and frontend wording were not separately accepted by this evidence; remote migration history was not inspected. Extension checks do not inspect file bytes.

Usage remains the earlier owner snapshot: banners 2 objects, 279418 bytes before these uploads, not a new current total. Owner should repeat the per-bucket usage query after cleanup for final current usage. Published Free allowance remains 1 GB as recorded above.

Cleanup pending owner action: delete only task-uploaded check.pdf/control.pdf/control2.pdf/pdf-final-control.pdf (where present) and any accidentally accepted video-check fixtures under the two exact class/post prefixes above via Storage API or Dashboard, preserving unrelated objects. Then soft-delete only temporary post 30ab5c48-1643-468e-9a6a-6f522cec0061 titled Temporary storage check. Preserve pre-existing Attachment concurrency test post 310660e2-805c-40ab-bf9a-86ade81fed4a, both classes, original user PDFs/videos, migration and maintained regression tests. Assistant created no local disposable fixtures/scripts; none removed. Remote cleanup has not been performed or claimed. Unrelated existing frontend edits preserved.

### Final materials cleanup and usage - owner supplied 2026-10-17

After cleanup instructions, owner supplied the full per-bucket result: banners, 2 objects, 279418 bytes. Final recorded object metadata total is 279,418 bytes (approximately 272.87 KiB); no materials objects appear in this result. Materials object cleanup is accepted on this owner output, with original banner objects retained. This supersedes the pending final usage/storage cleanup notes above. Free storage allowance is 1 GB, as sourced above; this is an object metadata snapshot, not billing-period average usage.

Owner also supplied a screenshot of the narrowly scoped temporary-post soft-delete UPDATE completing without error. Because it omitted RETURNING, affected-row count and final deleted_at were not established; no independent final-state verification claimed. Core materials acceptance remains complete on owner reports; no assistant tests/live checks or remote cleanup execution. No local disposable files created or removed. Migration, lasting docs and unrelated work retained.

### Local disposable materials removed - 2026-10-17

At owner request, removed exactly sample.txt, 26214400.bin and 26214401.bin from the verified Windows temporary Filo-materials-check directory, then removed the empty directory. Content/names matched chat fixture generation; source search found no app/script references. Preserved original user PDFs/videos, maintained tests, migration, docs and unrelated frontend changes. Git remains on main; no staging, commits or branch switch performed. Provided owner commands to stash unrelated tracked frontend edits, switch existing backend branch and explicitly commit only materials migration. docs/ remains ignored by existing repository policy. No tests run.


## Submission SQL acceptance prepared - 2026-10-18

Owner requested tests only and will run dev verification. Added maintained backend/tests/submissions.sql: rollback-only postgres fixtures, authenticated-role calls, per-case PASS/FAIL and overall summary. Covers draft creation/retry, archived/closed refusal, item caps and uploads-off, locked items, on-time/deadline-capped/late turn-in fields, unsubmit windows and returned-grade lock, student/peer/instructor submission and item visibility, admin-inserted grade visibility before/after return, peer exam isolation and unreleased/released get_result controls (security checklist 1, 3, 6). Timestamps are controlled fixtures because now() is transaction-stable; no sleeps or real storage uploads.

Source review identified an expected boundary failure: current unsubmit uses now() > unsubmit_until while late turn_in sets unsubmit_until=now(). Immediate unsubmit in the same transaction can therefore succeed despite no late window. A regression assertion deliberately expects refusal. No corrective migration added under the owner's tests-only scope; no dev results, checklist acceptance or runtime success claimed. Owner must run the whole file, inspect FAIL detail and overall summary, and confirm ROLLBACK. Unexpected setup exceptions require ROLLBACK then a complete rerun. No tests, SQL execution, static analysis, builds or live verification run. No disposable materials created; maintained regression script retained.


### Owner submission SQL results and assertion correction - 2026-10-18

Owner supplied 55 PASS / 4 FAIL and exact failing rows. Steps 32-34 correctly refused turned-in file/link/text inserts with P0001: This submission is locked; the script incorrectly expected 42501. Corrected these three expectations to exact trigger code/message. Step 56 returned 00000 for immediate late unsubmit, confirming the source-identified zero-window equality defect on the owner run. Added failures JSON to the final summary so SQL Editor exposes failure details without a separate query after rollback. Expected corrected result on unchanged dev is 58 PASS / 1 FAIL, an inference pending rerun. Checklist 1 and 3 assertions passed on owner report; checklist 6's reported item denials and sixth-file check passed behaviorally, with corrected assertion rerun pending. Overall lifecycle acceptance remains incomplete. Tests-only scope retained; no migration added, no assistant tests/live checks run, no disposable materials created.


### Unsubmit boundary correction prepared - 2026-10-18

Owner reran the corrected script and supplied 58 PASS / 1 FAIL; only step 56 (immediate late unsubmit) returned 00000. Security checklist 1, 3 and 6 assertions passed on this owner report. Added 20261018090000_unsubmit_window_boundary.sql replacing unsubmit with the same session, ownership, status and returned-grade guards, but refusing null windows and now() >= unsubmit_until. Equality is outside the documented strictly-before window; this also closes late turn-in's zero-length window. Existing migration history and RPC signature/grants unchanged. Source inspection only; migration not applied and no assistant tests, SQL execution, static analysis, builds or live checks run. Owner applies this migration on dev then reruns all of backend/tests/submissions.sql; expected 59 PASS, 0 FAIL, failures []. Acceptance remains pending that output. Maintained regression script retained; no disposable materials created.


### Submission SQL acceptance - owner reported 2026-10-18

After instructions to apply the boundary migration and rerun, owner supplied 59 PASS, 0 FAIL, overall PASS, failures []. SQL lifecycle and security checklist 1, 3 and 6 accepted on owner-reported dev execution. This supersedes the pending acceptance above. Remote migration ledger was not inspected; SQL Editor application does not prove migration-history registration. Assistant did not run tests or live checks. Maintained migration/regression script retained; no disposable materials created.

### Submission Storage owner verification and capacity - 2026-10-18

Owner confirms PNG/PSD uploads and account read checks completed, video-extension refusal already verified, and oversized upload rejected. A write-denial screenshot shows AccessDenied / row-level security violation; the screenshot alone does not identify the actor for each account. Accept owner-confirmed outcomes without repeating tests. Student A's first DELETE was blocked by the OTP session gate; after using the verified session, DELETE returned 200 with check.png listed and the subsequent authenticated GET returned Object not found / NoSuchKey. Own-file deletion is verified by owner execution. This is real Storage coverage, separate from the earlier 59-PASS database regression.

Owner supplied the complete post-check usage result: banners, 2 objects, 279418 bytes. Total recorded object metadata size is **279,418 bytes (272.87 KiB)**; no submissions or materials objects appear in this snapshot. Supabase Free file Storage allowance remains **1 GB**, shared across buckets, checked against https://supabase.com/docs/guides/storage/pricing on 2026-10-18. This snapshot is not billing-period average usage and does not establish bucket configuration.

Capacity estimate uses a conservative decimal 1 GB budget (1,000,000,000 bytes), less the reported 279,418 bytes: 999,720,582 bytes remain. Each maximum-size file is 26,214,400 bytes (25 MiB, labelled 25 MB). This fits **38 one-file student submissions**, or **7 full five-file student submissions** (131,072,000 bytes each). A whole-class assignment with N students and F maximum-size files each fits floor(999720582 / (N * F * 26214400)) times; for 30 students, one file each fits one full assignment, while five files each exceeds the allowance. Actual smaller files increase capacity; future banners/materials consume the same budget.

Source-review follow-ups remain separate from accepted owner checks: exact class/post/student/file path validation and post-to-class association are not fully enforced by the submissions baseline; UPDATE/rename lacks an explicit video-extension check. Exact-limit acceptance at 26,214,400 bytes was not separately reported; oversized refusal was. No new storage hardening migration or deployment is claimed. Assistant ran no tests, builds, static analysis, SQL or live API checks. No disposable testing materials were created or removed.

### Owner acceptance: upload settings changed after draft - 2026-10-18

Owner confirmed the latest four regression checks passed: saved draft files remain visible/removable after the instructor disables Allow file uploads, Turn in is blocked with an explanation, removing files permits a link/text submission, and changing the setting while the confirmation is open refuses the file submission. Acceptance is based on the owner's explicit yes, not assistant execution. This accepts the reported uploads-off regression; it does not establish completion of every M4 checklist, lowered-cap/concurrency stress checks, or independent remote migration-history verification. Assistant ran no tests, SQL, analysis, builds or live checks. No disposable materials created.

### Owner acceptance: late and closed deadline states - 2026-10-18

Owner explicitly confirmed both cases passed: late work with Accept late submissions enabled can be turned in, displays Late and offers no Unsubmit window; with late submissions disabled, Turn in is disabled after the deadline and shows Submissions closed on the actual deadline. This is owner-reported acceptance of these two cases only, not blanket acceptance of all M4 work. Assistant ran no tests, SQL, analysis, builds or live checks. No disposable materials created.


## M5-BE-01 / M5-BE-02 preparation ? 2026-10-18

Existing save_grade, return_grades, return_all_graded, grade visibility RLS and class/post/submission indexes were source-inspected. Added maintained rollback-only backend/tests/grading.sql covering score bounds, draft refusal, callers, same-row updates, direct-write denial, Save/Return visibility, instructor/peer isolation, bulk eligibility, foreign-owner IDs and inbox deduplication. Source review found null scores accepted and saved grades on reverted drafts eligible for Return. New 20261018120000_grading_guards.sql rejects null scores and invalid posts, locks submissions for Save/Return against unsubmit, and excludes drafts/null scores/deleted posts/closed classes from Return. Existing applied files are unchanged. return_grades has no class argument: it ignores foreign-owner IDs, but intentionally retains existing ability to return IDs across classes owned by the same caller; frontend selection must scope IDs.

Added rollback-only backend/seed/gradebook_40x10.sql with synthetic verified instructor, 40 students, 10 assignments, 400 graded turn-ins, authenticated RLS EXPLAIN ANALYZE for four query shapes, and dimension output. backend/API_CHANGES.md records bulk PostgREST shapes, pagination, relevant existing indexes and <1000 ms assumption. No speculative index added: no dev timing evidence exists. Neither migration nor scripts were run, applied or live verified by assistant. Security checklist 1, 3 and 4, actual timings/index plans and runtime acceptance remain pending owner execution; no PASS results claimed.

Owner explicitly confirmed M5-SA-01 accepted on 2026-10-18 in this task. Implemented new 0011_grade_missing.sql: verified owner, live/open past-due assignment, active/left/removed membership, valid score, creates or converts draft into timestamp-free turned_in work with no item metadata/comment; existing turn-in refused. Uses save_grade and normal Return visibility. Draft item metadata is discarded; existing Storage blobs are not deleted by SQL and remain for class purge. Former-member visibility remains subject to existing active-membership RLS. Added owner/caller/membership/deadline/bounds/draft/new-row/return/lock regression cases and API/Background Schema documentation. Also replaced unsubmit in the corrective timestamp migration to acquire the submission lock before checks, making Save/Return serialization effective. No migration deployment or test execution by assistant; M5-BE-03 dev acceptance pending owner. Maintained SQL deliverables retained; no disposable materials created.

## M5 frontend and student To-do owner acceptance â€” 2026-10-18

Owner confirmed the instructor duplication correction is done and reported testing all ten supplied checklist groups one by one: statuses/graded-only totals; submissions/search/filter/count/avatar/score marks; grade content/score and feedback validation; Previous/Next and unsaved navigation; confirmed missing-work scoring; single/bulk Return, cancellation, returned edits and notification behavior; cross-class To review/badge; private returned-only My grades/offline; Gradebook list/detail/table/former students/CSV; and student cross-class To-do/due groups/Done. Record as owner-reported frontend acceptance: M5-FE-01 through M5-FE-09 and M4-FE-06 are complete. The repeated M5-FE-04 is one task. The pagination ordering correction and duplicate cache protection are included in this confirmation.

No assistant testing, static analysis, builds, devices, SQL or live verification was performed for this acceptance entry. No raw per-case execution logs or measurements were supplied; do not infer independent Redmi timing, backend migration ledger, backend security-suite acceptance, or real push-delivery acceptance from this frontend confirmation. Existing backend acceptance and human document-review registers retain their own scope. No disposable materials created.

## M6 backend storage, sync and conditional Drive - 2026-10-18

Status: implementation prepared locally; owner testing, deployment and timings pending. No assistant tests, static analysis, builds, SQL execution or live project verification. Earlier owner materials signing/expiry/non-member evidence remains recorded above; pending/removed access and exact-size timing still need M6 acceptance.

- Materials signed-link lifetime: **60 minutes / 3,600 seconds**, using Storage createSignedUrl. A copied valid URL remains usable until expiry; revocation prevents new signing, not immediate revocation of already issued URLs. Use a separate 60-second link for quick expiry checks plus a real 3,600-second link for acceptance.
- Free storage allowance: **1 GB**, shared across buckets, official pricing rechecked 2026-10-18: https://supabase.com/docs/guides/storage/pricing . Latest available owner-reported snapshot (2026-10-18): **279,418 bytes**, banners only; current live usage is **not measured**. Run backend/tests/storage_usage.sql for current per-bucket, per-class and total metadata numbers; Dashboard billing can differ from an instantaneous metadata sum.
- Conservative capacity assumption: decimal 1,000,000,000-byte budget, ten 25 MiB materials per class = 262,144,000 bytes/class. Historical headroom 999,720,582 bytes fits **3 such classes**, before submissions, avatars, new banners and safety headroom. This is a planning assumption, not a fixed class quota. Recalculate floor((1,000,000,000 - current_total_bytes - reserve_bytes) / expected_bytes_per_class). Download target is exactly **26,214,400 bytes (25 MiB)**; Wi-Fi elapsed seconds/throughput are pending owner measurement.
- Sync: **200 rows/page**, inclusive completed timestamp boundary, ascending timestamp + PK keyset cursor and PK upserts. Server now() sets INSERT and UPDATE timestamps; notification read marks now participate. Active students can receive deleted class metadata to invalidate caches; removed/left users keep only their own membership row and lose class content. Snapshot reconciliation handles access changes, hard deletes and late commits; timestamp paging alone is not a lossless change feed. New migration: 20261018130000_sync_pull_support.sql, DEV application unconfirmed. Query shapes are in backend/API_CHANGES.md and backend/tests/sync_pull_queries.sql.

### Drive backup gate and frontend contract

No explicit M6-SA-01 keep/drop decision was found. Existing PRD/TRD/FLOW retain Drive backup as optional Could scope; this does not establish M6 approval. **M6-BE-03 is conditional, not completed.** No Cloud API/consent changes or Android Drive authorization were performed. Existing Android Google sign-in is present; Drive authorization/uploader integration is absent.

If retained: one-way device-to-personal-Drive backup; normal app-created folder **Filo Backup** (application/vnd.google-apps.folder), scope **https://www.googleapis.com/auth/drive.file**, method **Drive v3 resumable upload** (`POST https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable`, metadata parents=[folderId], then PUT bytes to Location). Persist folder/file IDs per Google account; names are not unique. Resume interrupted uploads with a status query and server Range; 308 means incomplete, 200/201 means finished. Use chunks in multiples of 256 KiB except the final chunk; restart expired sessions after reconciling the existing file to avoid duplicates. A 20 MiB / 20,971,520-byte timing remains unmeasured.

Verification answer, official Google docs checked 2026-10-18: **drive.file is non-sensitive**, requiring basic OAuth app verification rather than sensitive/restricted-scope review or restricted-data security assessment. This is not a promise that any Google account can use an app still in Testing: publishing status, configured audience/test users, branding/domain requirements and Workspace administrator restrictions still apply. Reference: https://developers.google.com/workspace/drive/api/guides/api-specific-auth . Upload protocol: https://developers.google.com/workspace/drive/api/guides/manage-uploads .

Scope precision: drive.file permits app-created files AND files explicitly opened/shared with the app through supported pickers. It does not mean strictly created-only. Uploading manually through drive.google.com does not grant Filo access, even inside its folder. Create/upload through Filo's OAuth client/API and inspect the result in Drive web UI; use an unrelated web-created file as the negative control. Never broaden to drive or drive.readonly to pass the test.


### M6 owner deployment history and storage total - 2026-10-18

Owner supplied CLI migration list with all local versions matched in Remote through 20261018130000, including the corrected draft policy migration. Accepted as owner-reported migration-history alignment; not independent schema verification or functional acceptance. Owner supplied storage_usage.sql total result: objects=9,total_bytes=1056514. Latest recorded metadata snapshot is **1,056,514 bytes (1.01 MiB) across 9 objects**, superseding 279,418 bytes as the latest total. Bucket/class attribution results not yet supplied. Against the documented conservative 1,000,000,000-byte planning budget, headroom is 998,943,486 bytes; the ten25MiB-files-per-class assumption still fits3 classes before reserve/additional usage. Signed-link role/expiry checks,25MiB download timing, sync correctness/performance and conditional Drive acceptance remain pending. No assistant SQL/tests/live checks run; no disposable materials created.


## Drive backup retained by owner; implementation preparation - 2026-10-18

Owner explicitly instructed "Drive backup is still unimplemented and untested. proceed with this". This authorizes retention/implementation and supersedes the earlier retention gate for this work; it is not attributed to an M6-SA-01 reviewer. No formal SA review was supplied.

Implemented source: account avatar menu > Drive backup, incremental Android Google authorization for **https://www.googleapis.com/auth/drive.file**, same-Google-email matching against the signed-in Filo account and persisted Google subject binding, normal Drive folder **Filo Backup**, and **Drive v3 resumable uploads** in1MiB chunks (multiples of256KiB; final chunk may be smaller). Scope non-sensitive/basic OAuth verification finding above remains authoritative, checked against official Google documentation again2026-10-18. Publishing/audience/Workspace administrator limits remain separate from scope classification. No broader Drive scope is requested.

The local account SQLite schema is now v3: drive_backup_settings and drive_backup_jobs form a dedicated durable backup outbox, separate from the existing generic Outbox. It stores non-secret folder/file IDs, immutable queued file snapshots, digests, server-confirmed offset and completion records. Upload session URLs are in FlutterSecureStorage under per-Filo-account keys; Google tokens remain in memory/native Google SDK, never in Supabase/SQLite/logs. IDs allocated by Drive are persisted before creation, so retries reconcile the same remote file and verify its size+MD5 rather than blindly creating duplicates. Expired sessions restart against the same remote ID; permission expiry refreshes once without prompting, then requires explicit reauthorization. Repeated content within one Filo account deduplicates by MD5. Folder/file trash requires user restore before retry.

Decisions resolving earlier copy questions: Wi-Fi-only defaults ON, including manual uploads. Backup OFF pauses pending work and leaves existing Drive copies untouched. Foreground app reconnect/resume and a one-minute foreground retry trigger attempt the durable queue. No background Android worker, upload while Filo is terminated, two-way sync or restore is promised. Last-success means all currently selected queued files completed, not a whole-device library backup. Per-file elapsed time is the latest upload attempt, excluding earlier interruptions/retries; measure end-to-end20MiB timing separately during owner acceptance.

Integration limit: Class Files is still a preview and no app-managed downloaded-file library exists. This implementation offers Android file-picker selection of already downloaded local files, copies them privately for durable retry, and exposes enqueue(File,name) for future library integration. It does not silently back up every download. Local queue copies are deleted after verified upload; original source files remain intact. Disabling backup retains pending private copies for retry. Empty files are refused. Only selected files are uploaded, and account switching stops requests for the previous account.

Cloud setup is **pending**, not performed: the console/browser tool failed to initialize (kernel asset path missing), and gcloud is unavailable. Use existing Google Cloud project **filo-app-58815**, enable Google Drive API, add only drive.file under Google Auth Platform > Data Access, and add the chosen account under Audience > Test users while publishing status is Testing. Keep existing Android package/SHA and Web OAuth client configuration. No OAuth client secret belongs in the Android app, and no Supabase migration is needed for Drive. Do not mark M6-BE-03 complete until owner confirms actual authorization, folder creation, isolation and20MiB resumable upload/timing.

Official references: https://developers.google.com/workspace/drive/api/guides/api-specific-auth ; https://developers.google.com/workspace/drive/api/guides/manage-uploads ; https://developers.google.com/workspace/drive/api/guides/create-file . Owner checks: deny consent stays OFF; grant and upload small local file appears in Filo Backup; upload20,971,520-byte file over Wi-Fi and record elapsed/result; interrupt/reopen/retry without duplicates; Wi-Fi-only queues on mobile; permission revoke/regrant; wrong-account refusal and per-account queue separation; last-success unchanged after partial failure; unrelated web-created file metadata denied under drive.file. Use app API token only locally if checking scope with Postman; never paste tokens/session URLs into chat or logs. Android system file picker selection is not Google Picker authorization for unrelated Drive resources.

No tests, static analysis, builds, device actions, SQL execution, live Drive API calls, Google configuration changes or timing measurements were run by the assistant. Only source review and Dart formatting. Runtime acceptance is pending owner checks. No disposable testing files were created. docs/decisions.md remains ignored by pre-existing Git configuration.


## M6-BE-01 and M6-BE-02 acceptance - 2026-10-18

Owner explicitly instructed "BE-01 and BE-02 have good core coverage, but full-table/performance acceptance remains pending. accept it all". Record **M6-BE-01 Complete - accepted** and **M6-BE-02 Complete - accepted**, including the previously outstanding full-table/performance acceptance. This supersedes earlier pending acceptance notes for those two tasks. It is owner acceptance of the delivered scope and remaining evidence limitations, not a claim that every pending case was executed or every performance target measured.

Available owner evidence includes aligned migration history through20261018130000; bucket/class totals reconciling9 objects/1,056,514bytes; signed download/expiry and pending/removed refusals;25MiB file saved at26,214,400bytes over Wi-Fi with1.38s compressed-text response;16 indexes and32 timestamp triggers plus server now() definition; core-table changed rows/tombstones, removed/left restrictions, active-student posts/attachment/item reads, inclusive boundary/next-page cursor, and synthetic401-row timestamp-tie paging200+200+1. Later test uploads mean the storage total is a historical snapshot, not a new live measurement. No invented additional per-case PASS results, representative full-table performance numbers, non-member response details or60-minute expiry evidence.

M6-BE-03 Drive backup is excluded from this acceptance and remains pending Cloud configuration and owner runtime checks. No assistant tests, analysis, builds, SQL/live API verification were run. No implementation changes or disposable materials for this acceptance entry.


## M6 frontend files, offline library, sync and backup implementation - 2026-10-18

Scope: M6-FE-01 through08 implementation prepared locally; **runtime acceptance pending**. Existing account databases, class/post caches, locked-link RPC and native Google/Drive resumable service were reused. Earlier BE-01/02 Complete - accepted labels remain unchanged. Drive Cloud enablement/consent and backend BE-03 live acceptance still await the owner; none was performed here. No formal SA/copy review is invented.

Data/storage: Drift schema **v4** adds SCHEMA10.3 local_folders/local_files with name/folder indexes and unique non-null class-folder/source-attachment indexes. Local rows deliberately have no cloud-cache FK, retaining downloads after leave/removal/deletion. Class folders display the class **Section**; physical folders use stable IDs under application-support/files/USER_ID/folders/FOLDER_ID; loose files use blobs/FILE_ID.ext. User-controlled names never become traversal paths. Final bytes are renamed atomically from private temporary files only after successful stream completion; only then is the DB row committed. Missing copies can be re-downloaded while source access remains. Name clashes get suffixes; moves reject folder cycles; file deletion stages bytes and recovers interrupted deletes. Folder deletion can make partial progress on an I/O failure; Retry handles remaining items. Pending private backup snapshots are cleaned when the source is deleted, with safe per-account path checks and outbox cleanup retry; an already in-flight upload may finish. No Drive deletion is issued.

Downloads: Dio5.11.1; live RLS metadata and3600-second signing, one fresh-link retry on400/401, streamed bytes with progress/Cancel, partial cleanup, attachment-ID reuse, server-size check and Android StatFs free-space preflight plus reserve/stream checks. Gzip transfer size is not mistaken for decoded file size. Personal imports use the system multi-file picker and a26,214,400-byte (25MiB, UI25MB) limit. No broad media/storage permissions are needed: merged open_filex permission declarations are explicitly removed; external viewing/sharing uses temporary content-URI grants. The one-time account storage notice is acknowledged only after successful download.

Screens: live Class Files lists post file attachments (not links/submission uploads), newest attachment first, with source post title/date/size, shared download state, scrolling/fading filters, skeleton/loading/Retry/offline/cached states. Real account Files navigation opens My Files for both roles, class/personal folders, breadcrumbs, global name search, Name/Date/Size sorting and offline import/create/rename/move/delete/open/export. Post/assignment material cards use the same manager/viewer; sample preview remains separate.

Viewer decision: TRD listed **pdfrx** as the PDF candidate but no final M6-SA viewer selection was recorded. Selected installed **pdfrx2.6.5** for implementation, with paged native rendering, scroll/pinch zoom and page number. No Redmi25MiB smoothness claim before owner measurement. Images support pinch/double tap; UTF-8 text is presented in bounded64KiB parts to avoid loading a large file into one text widget. Office/other formats use an info page and open_filex4.7.0; share_plus exports a copy. Viewer follows system rotation/theme; a token-based dark theme is supplied. Dio, pdfrx and Workmanager package sources report MIT; open_filex carries its license in the dependency package. PDFium/native third-party notices remain part of the package distribution. References: https://pub.dev/packages/dio ; https://pub.dev/packages/pdfrx ; https://pub.dev/packages/open_filex ; https://pub.dev/packages/workmanager .

Drive links: best-effort public drive.google.com file-ID conversion to drive.usercontent.google.com/download, response filename parsing, HTML/login/403/404 sharing refusal, actual confirmation-page fallback to the original browser link, and video/folder/other-link browser-only behavior. report_locked_link targets the parent post, offers student-only confirmation and distinguishes UTC-day duplicates. No OAuth scope is requested for public link download. Google can change HTML/redirect behavior; success, locked, confirmation and video outcomes have not been probed here and remain owner checks.

Offline restart: existing gate/profile lookup required online RPCs. Added a secure local marker bound to the **previously server-verified Supabase session_id + device hash**, per user. It unlocks only that account's local cache when offline (or a known network timeout/socket failure); a new/unverified session cannot use it. The profile screen reads its cached profile offline. Connectivity changes trigger fresh server verification; explicit server denial clears the marker. Backend RLS is unchanged and remains authoritative for network requests. No offline first-time sign-in, new OTP verification or cross-account cache access is promised.

Sync: one foreground coordinator is reused by class/post refresh lifecycles. It pulls applicable16 timestamp tables in200-row timestamp+PK pages, retains full server timestamp strings in sync_cursors/sync_payloads, applies tombstones and server last-change-wins checks, isolates per-table failures and reconciles visibility/hard deletes on startup/access changes/periodically. Typed cache FKs require parent rows first; auxiliary device/settings/instructor question/exam/bank rows use the per-account JSON cache. Student exams/answers remain RPC-only; answer keys are never fetched for students. Existing result cache entries refresh only through get_result, preserving cached results on network failure and removing confirmed-forbidden results. Removed/left membership evicts class content caches while local files/folders remain independent. Existing class inventory/profile reconciliation is retained; bulk grading snapshots remain under their own repository and RLS. Snapshot reconciliation remains necessary for late commits and new access to old rows; timestamp polling is not a commit-ordered change feed.

Outbox: notification_read (fixed read_at), leave_event (stable RPC event UUID), drive_backup (stable per-account/local-file UUID) only; assignment/quiz submissions are never queued. Atomic SQLite claims have a30-minute lease for crash recovery; processing is ordered by created_at/id among due actions. Actual failures retry5,10,20,... seconds, capped at1hour, stop after8 tries, and record a sanitized last error. Connectivity/Wi-Fi/authorization deferrals preserve the allowance. Retry sync resets failed actions explicitly. Required retry/replay/deferral and failed-table-isolation tests were written but **not run**.

Background: Workmanager0.10.10 initializes a top-level dispatcher and schedules network-constrained15-minute Android work, with OS timing/battery restrictions applying. Foreground open/reconnect/resume and30-second ticks flush; headless work reuses SDK-persisted Supabase auth and rechecks the active-account marker/server verification before account DB access. Background tasks never prompt for Google authorization; unavailable silent Google access defers until app reopening. Foreground/background duplicate claims use SQLite leases. Forced process death can defer a claimed job until lease expiry. No guaranteed background deadline is promised.

Drive library integration supersedes the earlier picker-only bridge: Files menu provides backup enable/Back up now/Wi-Fi-only; every local file with backed_up_at null is queued in the **generic outbox**, including imports/downloads made offline. Existing Drive jobs retain resumable byte/session bookkeeping and encrypted session URLs. Stable IDs, offset recovery and size+MD5 confirmation are reused; local backed_up_at is set only on confirmed completion. Whole-library last backup updates only once all currently indexed files are backed up. OFF pauses jobs; deleting phone files does not delete Drive copies. Revoked/expired permission asks for Google sign-in again. Cloud project filo-app-58815 configuration is still pending, with only drive.file and Filo Backup as previously documented.

Work performed: source inspection, required dependency resolution/native plugin registration, Drift **source generation**, and Dart formatting. **No tests, standalone static analysis, validation/app builds, device runs, SQL acceptance, live API checks or performance measurements.** Maintained tests are kept; no disposable fixtures, screenshots, logs or test guides were created. Owner acceptance checklist is supplied in chat. docs/ remains ignored by existing Git policy.


M6 final integration details: v4 also migrates legacy Drive job bookkeeping without losing existing job/remote IDs. New library backup jobs are unique by **local_file_id**, not digest: identical bytes in separately named files receive distinct Drive files, while retrying the same local-file ID reuses its stable job/remote ID. Zero-byte files use a metadata-only binary-file create and size confirmation; large files remain resumable. Pending snapshot/session cleanup follows local deletion without touching remote Drive copies. Package resolution, Flutter native plugin registration and generated Drift bindings are complete locally; application build and all tests remain unrun. Android broad-storage/media permissions from the external-open dependency are removed, and ACTION_VIEW visibility is declared for compatible-app discovery.


## Light-only frontend and screenshot design workflow - 2026-10-19

Owner requests default light appearance now and defers dark mode until later. Supersedes M6's system-theme viewer direction: MaterialApp uses ThemeMode.light and the incomplete AppTheme.dark definition is removed; existing light tokens and viewer rotation remain. External apps opened for office files retain their own settings.

UI_UX_IMPROVEMENTS.md supplements the Design Brief with explicit Filo application rules. Workspace AGENTS.md requires both references for frontend tasks and incremental screenshot-led improvement with shared components, accessibility and complete state coverage. Generic XP/streaks/fake progress/anonymous sign-in/package lists do not authorize product or backend changes. Existing brief and message contracts remain the baseline. Source inspection only; no tests, static analysis, builds or runtime checks. Owner acceptance pending light appearance under both phone themes, dialogs/viewers and offline/error/retry checks.


## Welcome intro vector mascot and tactile controls - 2026-10-19

Owner authorized the proposed welcome refresh and a character with intention. Added maintained Rive source at design/rive/filo-welcome (Python generator, editable RML, configuration and reproduction README) and bundled assets/animations/filo-welcome.riv. This is a simplified vector interpretation, not a pixel-perfect copy of the textured PNG. Welcome/Celebrate/Curious artboards have independent facial features, limbs, sprout and magnifier; each uses a 2.5-second one-shot greeting then a quiet seven-second idle with uneven blinks and pauses. No scripts, account login, remote publish/push, audio or confetti.

Intro keeps existing copy/navigation/light palette. Responsive top-aligned artwork and reserved heading space stabilize slide composition; page indicators animate, transitions use250ms easing, intro-scoped primary controls compress their edge80ms/release120ms and crossfade labels. Rapid Next taps are guarded. Only active pages load a player; existing PNGs cover loading/failure, inactive pages and reduced motion. Reduced motion uses instant controls/transitions. Decorative scenes are excluded from semantics and pointer handling. No artificial onboarding loading screen. rive0.14.11/rive_native0.1.11 resolved offline with Flutter plugin registration.

Only production Rive asset export, source inspection, formatting and dependency resolution performed. No tests, static analysis, validation builds, Rive runtime captures/preview, device or live API checks. Rive asset export succeeded but visual likeness, animation playback/runtime compatibility and owner acceptance remain pending. Owner checks all three poses, swipe/Next/Skip/Get started and repeated taps, quiet idle/revisit, background/resume, reduced motion,130% text/small screens, offline asset playback and fallback without blocking navigation. Generated build logs/output ignored; retained bundled production asset and lasting authoring sources.


## Original static mascots restored - 2026-10-19

Owner rejected the Rive character appearance and requested original mascots with component-focused polish only. Supersedes the welcome Rive decision: intro uses the unchanged original PNG Mascot widget; removed intro_mascot.dart, bundled Rive asset, isolated authoring project and rive dependency/native transitive registration. Retained responsive layout, tactile intro button, animated indicators, navigation guard and reduced-motion handling. Installed machine Rive CLI remains untouched. No tests, static analysis, validation builds or runtime checks; owner acceptance pending static original poses, component interactions and navigation/reduced-motion/large-text checks.


## Intro component motion specification - 2026-10-19

Owner explicitly requests low-opacity ambient shapes, staggered text entrances, smooth indicator,0.97 button press/shadow/arrow nudge, last-page-only idle pulse and initial Skip fade. Preserve existing layout/copy/routes/state management/static original mascots. Added flutter_animate4.5.2 (transitive flutter_shaders0.1.5); offline Flutter dependency resolution completed. Text and Skip use flutter_animate; background uses AnimationController+CustomPainter repaint boundary with3 edge radial-gradient blobs, no blur filter or saveLayer, mint/yellow20% peak alpha,16px travel/16-second leg. Button idle uses a stable controller-driven transform to retain pointer gestures, pauses while pressed/disabled/reduced motion, and only runs on Get started. No optional mascot-adjacent sparkle added.

IntroAnimation in presentation/animation_constants.dart centralizes UI durations300-500ms, easing easeOutCubic/easeInOut,100ms subtitle stagger,10px text rise, indicator colors, press scale/depth/shadow/3px arrow nudge, background colors/opacity/radius/drift, and1.006 pulse scale with8-second leg. UI shadow exception and timings supersede older generic brief motion guidance for this intro only. Reduced motion shows static decoration/full text and disables fades/slides/pulse/press motion; controllers disposed and TickerMode respected. No artificial loading state or routing change.

Source inspection/formatting/dependency resolution only. No tests, static analysis, validation builds, device/live checks or measured60fps claim. Owner checks first-load Skip, all slides/swipe/back/Next and stagger, smooth pill, press/cancel/rapid taps and last-page-only pulse, unchanged navigation/spacing/copy, readability over background, offline/reopen and live reduced-motion toggling/large text. Runtime and performance acceptance pending. No disposable testing files created.


## Sign-in preview removal and official Google mark - 2026-10-19

Owner requests removing Explore the preview and using a proper Google logo. Removed sign-in preview entry, role sheet helper and its preview imports only; other prototype routes remain outside this change. Added optional leading widget support to shared FiloButton, preserving existing trailing icon behavior for other callers. Sign-in displays20dp multicolor G before Continue with Google instead of the generic login arrow. Bundled unchanged official PNG at frontend/assets/brand/google-g.png using existing assets/brand registration, no SVG/runtime/network dependency. Original source: https://developers.google.com/static/identity/images/g-logo.png ; branding guidance: https://developers.google.com/identity/branding-guidelines . This sources the mark from Google; no claim that the existing custom Filo button has passed complete brand review.

Native Google authentication/session guards, loading/offline/connectivity retry behavior and About Filo retained. Source inspection/formatting only; no tests, analysis, builds or live/device checks. Owner verifies absent preview link, visible un-tinted G, account picker success/cancel and offline/retry behavior. Runtime acceptance pending. No disposable testing materials created.


## Four-screen entry alignment, branding and motion - 2026-10-19

Owner requests coordinated3-page intro/sign-in polish while preserving auth/routing/state/copy except requested additions. Shared EntryLayout/EntryMetrics/EntryPage now derive illustration size from the same full safe viewport (42%,216-330dp capped by width), fixed56dp header,8dp top gap, and common top-aligned text slots measured against all4 existing headlines/subtitles at device text scale. Footer content follows slots directly with20dp spacing; small screens/large text scroll instead of clipping. No existing mascot PNG or painted circle edited. Entry pages use plain high-quality Image display rather than outer ClipOval that cut through the image's off-white surround; static ground shadow placed just below feet. Painted texture/shading inside PNG is retained, so no claim of removing a baked-in halo. Ambient painter excludes entire illustration band including scroll clip's top; text rises10dp within12dp gap. Inactive dots #71867B, subtitle #3F554B/w500 chosen for AA contrast on light background; device/visual accessibility acceptance pending.

Last intro Skip hidden with maintained size/state and no hidden semantics; original page/role/auth/route destinations retained. Only /sign-in page presentation changes to400ms fade/slight-slide CustomTransitionPage; routing paths/guards/controllers unchanged. Shared text entrances420ms/100ms stagger on each selected intro page and first sign-in load;400ms indicator;300ms0.97 presses/arrow on intro. Occasional shimmer480ms after10.8sec pause on Get started and online/enabled Google only, replacing idle pulse. Google mark region excluded from shimmer, all ambient/effects excluded from illustration band, reduced-motion static/instant and TickerMode respected; controllers disposed. Background8sec eased legs make16sec out-and-back loop. No60fps measurement.

Google button:60dp height, standard white/#747775 border/#1F1F1F medium14/20 typography, unchanged official multicolor G, pressed fill/scale and soft shadow. Bundled official GoogleSans variable TTF at weight500 and SIL OFL text (declared as asset) from google/fonts ofl/googlesans. Guidance: https://developers.google.com/identity/branding-guidelines ; font source https://github.com/google/fonts/tree/main/ofl/googlesans . No new package dependency: existing flutter_animate/url_launcher reused. About Filo subtle14dp/w500 link with placement TODO. EntryCopy provides editable supportingLine='Your classes, wherever you learn.' (avoids claiming personal-note sync, which remains local), termsUrl=https://example.com/terms and privacyUrl=https://example.com/privacy. Requested agreement line and48dp tappable Terms/Privacy Policy links open external browser; failure reports Try again. Placeholder URLs require replacement before release; existing onboarding privacy checkbox/auth consent unchanged.

Source review/formatting/font download and graph refresh only. No tests, static analysis, validation builds, app/device/live API verification or visual/AA/performance acceptance. Owner checks same geometry4screens, larger static circles/halo/feet shadow, no decoration overlap, smallscreen130% text, third-page hidden Skip, text/indicator/shimmer/press/cancel/rapid taps, route fade/reduced motion, Google picker success/cancel/offline/retry, legal links/open failure and About intro replay. No disposable testing files created; production font/license retained and prior unrelated work preserved.


## Revert latest four-screen entry redesign - 2026-10-19

Owner rejected the latest four-screen alignment/branding/shimmer/legal-link redesign. Reverted that change only: restored separate intro/sign-in layouts, original Mascot clipping, earlier subtitle/dot styling, visible last-page Skip, standard sign-in route presentation, previous intro idle pulse/background timings and earlier Google-logo FiloButton. Removed latest shared entry/shimmer/Google button/copy files and GoogleSans font/license/registration after reference review. Earlier official Google G asset, preview-link removal, flutter_animate effects, auth/offline/retry/state and unrelated work retained. Historical redesign entry is superseded. No tests, analysis, builds or runtime checks; owner checks previous layout/static mascots, Next/Skip/Get started/About, Google sign-in and offline/retry/reduced motion. No disposable testing materials created; rejected task-created font assets removed.


## Shared tactile buttons and sign-in entrances - 2026-10-19

Owner requests fixing text becoming dark on click, smoother Next-to-Get-started text change, reusable consistent buttons, and animation on Hello curious mind. Source shows intro temporarily disables Next during page advance and FilledButton inherited its disabled text color; sign-in previously had no entrance animation. Consolidated original FiloButton and intro-specific implementation into core/widgets/filo_button.dart, re-exported from existing filo_widgets.dart so all18 existing callers inherit one component. Removed obsolete intro_button.dart after reference review. Preserves primary/secondary, icon and optional leading widget API; adds busy/animateArrow/idlePulse. Explicit primary white and secondary ink text/icon colors apply in pressed/busy/disabled states; transparent overlay removes dark press tint, while callbacks remain disabled when unavailable/busy.56dp pill,4dp edge,0.97scale300ms and subtle shadow feedback shared; explicit leading Google G stays static. Intro adds busy=_advancing and arrow nudge; only Get started opts into prior gentle idle pulse.

Label uses keyed AnimatedSwitcher fade+4dp rise with400ms easeOutCubic and AnimatedSize; keeps colors stable during Next/Get started and loading label changes. Moved shared tokens into core/theme/animation_constants.dart as FiloAnimation; former onboarding file re-exports it for compatibility. Tokens include labelRise, primaryLabel, secondaryLabel, pressOverlay, pressDuration and buttonEntranceDelay. Sign-in adds flutter_animate420ms fade+10dp rise for headline, subtitle100ms later and Google button200ms later, once per mount rather than on connectivity/auth rebuild; reduced motion skips entrance/press/label/pulse motion. No mascot/background/layout/spacing/text/route/auth changes; previous16dp button lift and Unicode escape fix retained. No new dependencies.

Source review/formatting only, no tests/static analysis/builds/device/live API checks. Owner checks press/hold/cancel, primary disabled/busy white labels and Google secondary stable ink, smooth Next/Get started/rapid tap guard, other FiloButton callers/loading labels, sign-in stagger/reopen/no repeated entrance on auth retry, offline/retry and reduced motion/large text. Runtime acceptance pending. No disposable testing files created; shared component is lasting implementation, no unrelated deletion.


## Intro finish label and separate sign-in stage - 2026-10-19

Owner requests smoother Next/Get started and reports mascot shrink on Hello; authorizes making sign-in a distinct step after3About-Filo slides. Source confirms intro footer-derived artwork could reach290dp while sign-in fixed240dp; overlapping AnimatedSwitcher labels and changing text width shifted arrow. Added optional FiloButton.labelVariants to reserve largest-label bounds; onboarding passes const[Next,Get started]. Label400ms uses separate first-half outgoing/second-half incoming easing,2dp rise, excluded outgoing/placeholder semantics, retaining stable color and arrow group position. No labels overlay each other at normal transition timing; rapid-update visual acceptance remains owner check.

Shared entryMascotSize(context) derives180-290dp size from viewport width minus48dp; intro and sign-in both use it, removing fixed240dp drop without modifying assets/circles. Sign-in retains its standalone greeting/Google layout; /sign-in page presentation uses400ms easeInOut fade over static app background, without scaling/morphing hero. Existing routes/destinations/auth/guards, intro text/Skip/page count, sign-in text/control entrances,16dp button lift, reduced motion and static PNGs retained. New FiloAnimation labelDuration/labelInCurve/labelOutCurve/signInTransitionDuration/signInTransitionCurve tokens; labelRise now2dp. No new dependencies.

Source inspection/formatting only. No tests, static analysis, builds, devices/live calls or measured visual/performance acceptance. Owner checks2-to3/back/repeatedNext label/arrow stability, separate Get started/Skip sign-in fade with unchanged mascot scale, About replay, narrow/large-text layouts, reduced motion, shared loading labels and Google online/offline/cancel/retry. No disposable testing materials created; lasting reusable geometry helper retained. Runtime acceptance pending.


## Sleepy Sprout device-check loading presentation - 2026-10-19

Owner requests keeping verification functionality but replacing checking UI with simple loading screen and Sleepy Sprout Notebook mascot. Reused unchanged docs/mascot and icon/Sleepy Sprout Notebook Mascot.png as bundled assets/mascots/sleepy.png under existing asset directory. SessionScreen retains same provider/checking condition and appbar/signout callback; only checking body now SessionLoadingView. Static156-240dp sleepy artwork, One moment and existing device-check subtitle with Unicode escapes, three8dp dots below artwork/28dp gap; no fake progress, no animated mascot or overlay. Loading view scrolls/centers and preserves optional action error feedback. Developer checks hidden during loading, existing debug panel remains in OTP/error view. Verified next destination, OTP send/verify/resend/countdowns, server gates, offline handling, errors/Try again and signout semantics untouched.

Dot animation uses isolated repaint boundary and disposed AnimationController1800ms cycle (600ms sequential dot), easeInOut4dp lift with opacity0.4-1; static dots when reduced motion/TickerMode disabled. Live-region label is stable and decorative dots excluded from semantics. Tokens loadingCycle/loadingDotTravel/loadingDotOpacity/loadingDotColor in core/theme/animation_constants.dart. No dependency addition or new network request. Source inspection/formatting only; no tests, static analysis, builds/device/live checks. Owner checks trusted verification to setup/home, new-device OTP, failed-check Try again/loading, signout/failed-signout feedback, offline and reduced motion/large-text/small-screen scrolling. Runtime acceptance pending. No disposable testing files created; production mascot copy retained, original artwork unchanged.


## Sleepy asset running-bundle recovery - 2026-10-19

Owner screenshot shows missing assets/mascots/sleepy.png in running bundle. Local file exists1213698bytes and assets/mascots directory already correctly declared. Stale running asset bundle after reload is likely, not independently confirmed. Owner must stop/relaunch flutter run to package new asset; no source path or auth change needed. Added optional Mascot.fallbackPose and loading-only curious fallback to prevent framework error artwork if sleepy is unavailable. Other mascot callers unchanged. No tests/builds/device/runtime checks performed; owner confirms sleepy after full relaunch and verification flow unaffected. No disposable testing files created.


## Sleepy-only loading artwork - 2026-10-19

Owner explicitly rejects curious fallback. Removed loading fallback and unused Mascot fallback API. Verification loading uses only sleepy.png copied unchanged from docs/mascot and icon/Sleepy Sprout Notebook Mascot.png. Full app relaunch required if running asset bundle predates this file. Auth/dots unchanged; no tests/builds/runtime checks; owner confirms sleepy after relaunch. No disposable materials.


## Role cards and returning-user profile lookup presentation - 2026-10-19

Owner requests improved role selection and removal of blank Set up your account spinner on repeat login. Source already skips role selection for any non-null account profile; retained online server profile lookup, offline per-account cached profile and existing notification-handled/home transition. No speculative role display or security bypass. While _stage=loading, render shared Sleepy-only SessionLoadingView with neutral Brand/signout header and Getting your account ready status, not empty setup shell. Same async/error/Retry and existing-account notification/home logic; role UI only after confirmed null profile. Loading view statusText configurable for device-check vs profile-lookup and stable Loading semantics, original device-check default unchanged.

Role content top-aligned instead of vertically centered; reusable RoleOptionCard presents48dp icon tile, title, canonical student/instructor description, primary border/mint selected fill/check and mutually-exclusive checked semantics. Entire card tappable/keyboard-focusable, wraps descriptions/scrolls at large text;300ms selection color/zero reduced motion. Full canonical irreversible-role warning in amber lock panel and shared FiloButton Continue; selection and _confirmRole confirmation unchanged, no role write until existing account creation flow. Details/notifications alignment left as before. Corrected existing mojibake punctuation in touched setup copy via Unicode escapes. No dependencies or mascot asset changes.

Source inspection/formatting only; no tests/static analysis/builds/devices/live API checks. Owner checks new Student/Instructor selection/Continue/cancel confirmation/details/save, existing role return skips setup with Sleepy loading then home/notification as before, profile failure Retry (never shows new-account choice), verified offline cache and missing-cache error, account switching, signout, large text/small screens/reduced motion. Runtime acceptance pending. No disposable testing materials created; lasting card widget retained and unrelated prior changes preserved.


## Simplified role screen and reusable disabled buttons - 2026-10-19

Owner explicitly removes setup Sign out, top setup title and role warning panel. Role stage now has no appbar: Choose your role remains the main heading, canonical role cards remain, amber warning removed, shared Continue retained. Sign out actions removed from account-setup header/loading header; other app security/account signout actions untouched. Existing irreversible-role confirmation still explains permanence before details; no profile/auth/notification/security rule change.

Shared FiloButton now distinguishes unavailable(onPressed null,busy false) from temporary busy. Disabled palette FiloColors.disabledButtonFill #E2E8E2 /disabledButtonInk #4F625A /disabledButtonBorder #CCD7CE, flat edge/no shadow/no press motion, same pill/height/layout/label behavior and native disabled semantics. Selected/enabled Continue uses regular green tactile style. busy true preserves active palette while disabling callbacks; prevents previous dark text flash during Next/Google operations. All FiloButton callers automatically reuse unavailable design; no bespoke role button or new dependency.

Source inspection/formatting only; no tests/static analysis/builds/device/live checks. Owner verifies role page no setup header/signout/warning, disabled Continue cannot tap before selection, each selection enables green button, confirm cancel/continue unchanged, other disabled/busy/secondary buttons and offline retry/reduced motion/large text. Runtime acceptance pending. No disposable testing materials created; unrelated files preserved.


## Playful role composition and anchored primary action - 2026-10-19

Owner authorizes proposed playful role composition and specifically selects docs/mascot and icon/Thinking Notebook Sprout Badge.png. Copied unchanged as assets/mascots/thinking.png under registered directory; static140dp Mascot, no redraw/animation/fallback substitution. Owner must fully stop/relaunch to include new asset. Dedicated RoleSelectionView has scrollable illustration/heading/cards and separate SafeArea bottom Continue footer24dp sides/40dp bottom matching intro/sign-in. SharedFiloButton disabled/enabled style retained. Body uses centered Choose your role, warmer proposed supporting line A place for curious minds and inspiring teachers, original canonical role descriptions and roles; no setupheader/signout/warning restored. Existing confirmation/selection/create/auth/profileloading/notification logic untouched.

RoleOptionCard now adds3dp pressed edge/0.99scale with stable2dp selection border, mintfill/check and existing checked semantics/keyboard InkWell. Header/cards420ms fade+8dp rise with80ms stagger, outside staticmascot bounds; zero motion under reduced settings. FiloAnimation role tokens centralize edge/scale/entrance/stagger. Narrow/largetext content scrolls independently above pinned Continue. No dependencies or testing materials added. Source inspection/formatting only; no tests/staticanalysis/builds/devices/livechecks. OwnerchecksThinkingartafterfullrelaunch, samebottomactionplacement, scroll/largefont, rolepress/cancel/selection/disabledContinue/confirmation, returningprofile skip and reducedmotion. Runtimevisualacceptancepending.


## Reusable role confirmation modal - 2026-10-19

Role selection now uses core showFiloConfirmation / FiloConfirmationDialog. Configurable title, message, icon and action labels; rounded 28dp warm surface, mint role icon tile, clear centered heading and stacked full-width shared FiloButton actions. 400dp maximum width and scrollable content support compact screens and large text. Existing title/body/Confirm role/Go back wording retained. Dismissal/back/cancel return false and retain role; only confirmation advances to details. Existing assessment confirmAction presentation unchanged. No dependencies, auth, routing, profile persistence or mascot changes. Shared button press/reduced-motion behavior retained.

No tests, static analysis, builds or device checks run. Owner checks both role icons/labels, confirm versus cancellation/barrier/back, repeated opening, compact screen/large text and reduced motion. Runtime acceptance pending; no disposable testing materials created.


## Consistent Phosphor icons and selective feedback - 2026-10-19

Owner approves proposed Flutter-native icon implementation after Morphicons analysis. Added phosphor_flutter ^2.1.0 (resolved 2.1.0 using offline cache); no npm or JS bridge. Core FiloIcons centralizes semantic names as static const glyphs: regular outlines for controls and fill for selected navigation. FiloIcon inherits existing IconTheme/disabled/pressed colors, sizes, semantics and directionality; normal icons remain static, optional animateChanges uses 300ms easeOutCubic fade/scale and excludes outgoing semantics. This is a transition, not a path morph. Existing device verified status opts in to actual status changes; no simulated save-success state introduced. Feature-owned explicit Material icons migrated across 29 source files including role cards/dialogs, entry buttons, classes, assessments, files, submissions, grading, backup and security; framework-managed implicit icons retain native behavior. Google sign-in logo and mascots untouched.

Shared FiloSelectionIndicator animates role check opacity/scale in a fixed 24dp circle with parent checked semantics. FiloExpansionTile retains native ExpansionTile behavior and semantics, Phosphor caret rotates on real controller state; controller disposed. Shared iconDuration 300ms, iconSwapScale .9, iconSelectionScale .75 live in animation_constants.dart; existing uiCurve applies, MediaQuery.disableAnimations makes effects immediate. Navigation uses consistent regular/filled pairs and work queue badges in both states; handlers/auth/state/profile/data operations and existing text/layout preserved.

Source inspection and formatting only; no tests, static analysis, builds, device or live API checks run. Owner must fully restart for bundled font dependency; inspect role choices/dialog/buttons, selected navigation and work badges, file/status/toolbar readability, expansion and reduced motion, large text, disabled/busy controls, offline download Retry and normal save/cancel flows. Runtime acceptance pending. No disposable testing materials created, no staging/commit/push; unrelated dirty work preserved.


## Flutter final IconData compatibility repair - 2026-10-19

Owner build failed because cached phosphor_flutter 2.1.0 subclasses IconData, which is final in the installed Flutter SDK. Removed that dependency instead of modifying the global Pub cache. FiloIcons now contains native const IconData declarations with original Phosphor 2.1.0 code points. Bundled original Regular and Fill TTFs in assets/fonts/phosphor, declared FiloPhosphorRegular/Fill families, retained MIT LICENSE as bundled asset and registered lazy LicenseRegistry entry. Same artwork, semantic names and selected variants preserved; only directional arrows/chevrons/sign-in/out mirror for RTL. No auth/routing/layout/motion redesign.

Removed redundant direct filo_icon imports where filo_widgets already exports it. Replaced deprecated TickerMode.of with installed SDK TickerMode.valuesOf(context).enabled in shared button, intro ambient background and loading dots. Other pre-existing UUID deprecation notices and workmanager_android KGP warning are separate from this compile error and were not changed. Package metadata resolved offline after dependency removal; no package cache edits or other dependency upgrades.

No tests, static analysis, builds, devices or live API checks run per owner policy. Owner reruns Flutter with existing env define, verifies successful compilation, Phosphor glyph rendering (including selected navigation and role modal), disabled/busy colors and reduced-motion behavior. Runtime acceptance pending. No disposable testing files created; fonts/license are required production assets.


## Device verification screenshot repair and polish - 2026-10-20

Owner screenshot shows corrupted apostrophes/ellipsis, oversized security headline, partially clipped Curious illustration, and unwanted Developer checks. Reviewed Graphify reports/query, current SessionScreen, shared widgets, loading view, session gate, UI UX Filo application rules, design brief, F1 flow and canonical auth messages. Existing real OTP send/verify, resend cooldown/lockout and provider retry already implemented; no backend or security changes required.

SessionScreen presentation now uses top-aligned SafeArea/SingleChildScrollView with 24dp margins, 440dp content cap and original static Curious PNG at full 156dp layout bounds. Headline explicit 28dp/1.2 avoids oversized inherited display style; subtitles 15dp w500. Existing intended wording restored using ASCII Dart Unicode escapes for apostrophes/ellipsis to prevent recurring encoding corruption. Compact email card uses a 44dp tinted Phosphor tile and wrapping email beside it, with full-width shared Send code action. Code field retains manual numeric entry, six-digit limit, no OS autofill/predictions, focus and keyboard-submit behavior; 24dp type/4dp tracking and accessible field label. Busy Send/Verify use existing FiloButton busy palette/guard. Error feedback remains live-region text plus icon and retry, before action card. Keyboard drag dismissal and scroll access support small screens/large text. Sleepy loading presentation retained.

Developer checks panel, debug-only imports/state, profile/class diagnostic read helper and JWT diagnostic helper removed completely. Real verifiedUserIdProvider, session gate and OTP payloads/timers/error mapping unchanged; confirmed verification still advances to existing AccountSetupScreen. Sign out retained. No new packages, mascot modifications or animations.

No tests, static analysis, builds, device or live checks run. Owner checks clean punctuation/full mascot on initial security screen, long email/large text/keyboard scrolling, Send busy/duplicate taps and send failure retry, six-digit entry/deletion, wrong/expired/used codes, cooldown/locked resend eligibility, offline send/verify messaging and retry, device-check Try again, success to account/home and sign out. Runtime/visual acceptance pending. No disposable testing files created, no staging/commit/push; unrelated work preserved.


## Account details form and shared Create account action - 2026-10-20

Owner screenshot requests better account-details hierarchy and consistent Create account button. Reviewed reports/query/docs inventory/UI UX rules/brief components/F1 flow/canonical privacy wording/current setup/repository/shared role footer/button. Existing details stage used in-list FilledButton, ungrouped read-only rows and right-side consent; validation and safe retry already exist in parent/repository.

Extracted presentation-only AccountDetailsView. Compact 64dp existing Google avatar with mint/person loading/error fallback beside 28dp Your details title; 24dp margins, 520dp cap, safe scrollable form with drag keyboard dismissal. Name80/school120 counters retained with explicit gaps, next/done keyboard actions. Read-only email/role grouped in tint panel with locks and wrapping values. Separate privacy panel keeps existing Read Privacy Notice and exact consent wording, checkbox moved to leading/left, accessible native checkbox interaction. Privacy dialog handler unchanged. Shared FiloButton pinned below form, sides24/bottom40 matching role footer; bottom16 above keyboard, unfocus before save. Disabled until existing validity predicate true, busy palette/guard preserved, arrow press nudge, creating and Retry labels use stable variants. Live-region failure panel retains inputs/consent and repair of corrupted failure/busy punctuation via Unicode escapes. No new dependencies, auth/routing/role/profile persistence/notification flow changes; adjacent notification busy ellipsis repaired only.

AccountSetupScreen owns controllers/disposal, validation, consent state, save and after-save routing; repository still checks existing profile for safe retry/reconciliation before insert. No optimistic account success. No tests/static analysis/builds/device/live checks run. Owner checks prefilled name/photo loading/error, empty/whitespace name and limits, long email/large text/small screen/keyboard scrolling, privacy dialog, unchecked/checked consent and disabled/enabled button, busy duplicate-tap guard, offline/create failure then Retry retaining fields, and successful transition to notification/home once. Runtime/visual acceptance pending; no disposable materials created or staging/commit/push.


## Remove repeated account setup toolbar - 2026-10-20

Owner requests removing Set up your account at top for clean consistent setup pages. Role selection already has no toolbar. Removed title AppBar from AccountDetailsView and remaining notification/lookup-error setup scaffold. Main Your details/Stay up to date headings, SafeAreas, controls, privacy, validation, save and routing preserved. Loading Brand header retained because it has no setup title. Source inspection/formatting only; no tests/static analysis/builds/device checks. Owner checks no duplicate toolbar on details/notifications, safe top spacing and keyboard scrolling, Create account/Retry and notification enable/Not now flows. Runtime acceptance pending. No disposable files created.


## Discoverable Privacy Notice and reusable reading modal - 2026-10-20

Owner asks for an indicator and redesigned Privacy Notice popup. Existing text-only TextButton opened generic AlertDialog. AccountDetailsView now shows a full-width mint-tinted Material/InkWell row, Phosphor document icon, canonical Read Privacy Notice label, decorative chevron and screen-reader opens-notice hint; 48dp minimum at normal text and wraps for large text. Native focus/tap feedback retained. Checkbox and exact consent text remain separate.

Added reusable core FiloNoticeDialog/FiloNoticeSection exported via shared widgets: 28dp bordered light surface, mint48dp icon tile,22dp title,15dp body/1.55 line-height, section headings and divider,440dp max width/24dp insets. Native scrollable AlertDialog scrolls title/body when constrained; shared full-width Close remains an action. Account setup supplies existing two disclosure paragraphs unchanged, grouped as Your information and AI processing. Reading/closing/barrier/back does not toggle consent or create account. Privacy works locally/offline, no dependency/network/auth changes.

Source inspection/formatting only; no tests/static analysis/builds/device/live checks. Owner checks whole notice row opens modal, both paragraphs reachable at large text/small screen, Close/back/outside dismiss and reopen, offline availability, focus/screen-reader indication and unchanged consent/Create account gating. Runtime acceptance pending. No disposable files created or staging/commit/push.


## Optional gallery profile photo during account setup - 2026-10-20

Owner explicitly approves gallery selection, local preview and save on Create account, keeping Google photo when skipped. Reviewed reports/query/docs inventory/Filo UI UX rules/brief/auth privacy/F1 flow/current profile repository, existing image_picker usage, signed avatar display, API photo preference contract and storage/profile policy source. image_picker/uuid already installed; private avatars bucket declares 524288-byte cap and user_id/file ownership. Local current_user_ok checks verified session without requiring profile. Profile avatar_path has UPDATE grant but is deliberately absent from INSERT column grant; no SQL changes made and remote deployment state not verified.

Details photo now an accessible80dp gallery tap target with camera badge (same static profile circle, no mascot changes), memory preview, loading/error Google fallback, picking guard and Use Google photo reset. Native gallery picker requests512x512/quality80 without full metadata. ProfilePhotoDraft validates final JPEG/PNG/WebP signatures and <=512KiB bytes, retains stable UUID/file extension/MIME; UI decodes before accepting preview and disposes image/codec. Cancel retains previous selection. Permission/invalid/oversize/unreadable errors announced separately without discarding fields or consent. Shared Create disabled while picking; fields/photo edits blocked during save; reduced motion keeps static camera instead of picking spinner.

No remote upload until existing valid/consented Create account. Repository reconciles existing profile before insert (unchanged), then privately uploads under user_id/draftUUID.ext and updates avatar_path with select.single confirmation. Existing Google URL retained. Repeated save uses same path/upsert; if avatar_path already committed, returns fetched profile. Photo-step failure clearly says account created but photo unfinished, retains preview, offers Retry or Google fallback; no false photo-success transition. Explicit Google reset can clear avatar_path on retry after ambiguous custom-photo update. Current account identity checked before upload/update. Never delete uploaded object on ambiguous response, since profile path may have committed; replacing failed drafts can leave unreferenced private objects, cleanup policy is separate. After full completion existing notification/home route and signed avatar display consume returned profile normally. No new dependencies, public URLs, storage grants, auth or notification rules.

Adjusted maintained FakeProfiles.create optional parameters to match repository signature, no new assertions or disposable tests. No tests/static analysis/builds/manual devices/live API checks run. Owner checks gallery choose/cancel/replace/reset, no-photo Google fallback and Google image load failure, permission denied/invalid/too-large image messages, large text/keyboard/reduced motion and duplicate taps, offline create, upload/path-update failure and Retry without duplicate profile, success avatar in home and after sign-in, account switching, original consent/role flow. Runtime/storage-policy acceptance pending. Preview draft is in memory; process restart during setup loses unsaved photo (existing native picker process-recovery is not added). No task-created disposable materials, staging/commit/push.


## Profile camera badge clipping repair - 2026-10-20

Owner screenshot shows camera badge cut into a pointed shape. Source confirms outer80dp Material radius40 clip antiAlias cuts lower-right32dp badge. Outer Material now Clip.none; photo keeps own ClipOval, InkWell uses CircleBorder for feedback, badge keeps complete32dp circle with3dp background outline/centered16dp camera.80dp accessible touch area and all picker/save/preview/disabled/reduced-motion behavior retained. Source review/formatting only; no tests/static analysis/builds/devices. Owner checks full round badge on Google and chosen photos, tap to pick, cancel/reset and busy state; visual/runtime acceptance pending. No disposable files created.


## Notification permission prompt design - 2026-10-20

Owner screenshot requests improving sparse centered text/standard button. Reviewed reports/query/docs inventory/UI UX rules/design brief/F1 A6 flow/auth wording/current parent/native permission helper/shared button/icon tokens. Existing _finishNotifications requests native permission only on Enable, marks handled best-effort and proceeds Home even on denial/request/storage error; Not now skips permission. Those semantics remain unchanged.

New presentation-only NotificationPromptView: no toolbar, static112dp rounded mint bell tile,28dp centered Stay up to date heading, existing explanatory wording in15dp w500 readable body. Compact rounded panel groups existing categories Class updates/Deadlines/Grades with regular Phosphor icons.24dp safe margins/520dp cap, vertically balanced scrollable body and separate bottom actions. Shared FiloButton Enable notifications with existing Continuing Unicode label/busy guard, accessible >=48dp Not now remains plain secondary action and disabled while busy. Gentle420ms fade/10dp rise uses existing FiloAnimation.textDuration/textRise/uiCurve; no loop, reduce motion skips entrance. No mascots, new assets, dependencies, permissions, schedules or backend changes. Parent delegates notification stage and removes old duplicate markup; other setup/lookup stages unchanged.

Source inspection/formatting only; no tests/static analysis/builds/manual/device/live checks. Owner checks new composition and readable scroll at large text/small screen, stable busy button/duplicate tap guard, native Allow/Deny/dismiss and Not now all reach Home, permission request/storage failure never blocks Home, handled prompt not repeated on next login, reduced motion has no entrance. Runtime/visual acceptance pending. No disposable testing materials created or staging/commit/push.


## Classes screen hierarchy and routine sync cleanup - 2026-10-20

Owner screenshot requests Classes redesign and removal of One class. A world of possibilities. and Last synced below Join class. Reviewed reports/query/docs inventory/UI UX/design brief C1/F2 messages/current classes screen/cache/sync providers/shared widgets. Existing class reads/filtering/join/create, archived/deleted/pending views and error retry already present. Removed slogan row and all routine bottom sync labels/timestamps (healthy, syncing, not-yet-synced). Renamed bottom helper _SyncErrorStatus: only renders when coordinator.errors nonempty with truthful failure/offline copy and existing Retry sync, disabled while syncing/offline. Existing OfflineBanner, class refresh errors/Retry and pull-to-refresh remain; no sync engine changes.

Classes header explicit28dp/1.2/w800 with15dpw500 supporting line,24dp margins. Header mascot72dp only when loaded classes or skeletons exist, eliminating duplicate header mascot in empty/search state. New screen-specific ClassesEmptyState uses original static Curious144dp in rounded tint panel,22dp heading/15dpw500 message. Existing state/role-specific copy retained, query-no-match takes precedence over offline cache-empty wording so cached search results are described correctly. Search keeps pill, adds accessible label/clear action and disposed TextEditingController, search/dismiss keyboard handling. Standard shared Join/Create footer, all navigation destinations/badges, card layout and mutation contracts unchanged. List bottom112dp reserve keeps content clear of floating action; banner/error separation improved. No new assets/dependencies/motion/mascot edits/backend changes.

No tests/static analysis/builds/device/live checks run. Owner checks empty student Join/instructor Create, no slogan/timestamp, populated/pending/archived/deleted views, query match/no-match/clear including offline cache, loading/error/refresh retry, offline Join disabled and reconnect, sync failure Retry only when applicable, navigation/work badges, keyboard/large text/small screen and no footer overlap. Runtime/visual acceptance pending; no disposable files created/staging/commit/push.


## Student To-do page polish - 2026-10-20

Owner requests enhancing To-do without a new screenshot. Reviewed reports/query/docs inventory/UI UX/design brief/student To-do flow/grading-submission messages/current WorkQueueScreen/provider/assignmentStatus/skeletons. Existing queue contains assignments only, grouped Overdue/Today/This week/Later/Done from due times and confirmed submission/returned-grade state. Preserved providers, sorting/minute refresh, cache/offline logic, membership/archive guards, deadlines, status calculation and assignment navigation. No quiz support fabricated. Instructor To review build and grade return handlers remain unchanged via student-only presentation branch.

Student body now28dp To-do heading and15dp due-date explanation/24dp margins, local All/To do/Done choice filters (All default preserves prior visibility), wrapping accessible48dp targets. Group headings show actual visible entry counts. New reusable TodoTaskCard separates17dp title/13dp class metadata, Phosphor icon/chevron, status pill with icon+word, optional known assignment points and localized date/time. Late uses warning tint, Missing error outline per brief, other statuses calm mint; no checkbox marks work complete, no optimistic submissions/grades. Unknown points omitted rather than inventing0. Class separator uses Unicode escape. Long names/status/date wrap. Standalone variant retains back appbar without duplicate title; embedded class shell unchanged.

TodoEmptyState provides rounded neutral empty/filtered/no-saved variants, with no mascot or gamification. Loading uses static task-specific semantic skeletons, no shimmer/fake progress/controllers. Offline banner and refresh-error panel/Retry stay visible with cached cards; Retry disabled offline, pull-to-refresh handler unchanged. No dependencies/backend/auth changes. No tests/static analysis/builds/device/live checks run. Owner checks All/To do/Done, actual counts/Overdue-Today-week-later-Done ordering and minute-boundary updates, assigned/draft/missing/late/turned-in/returned-grade statuses, no-date/unknown-points/long-title/large-text layout, tap opens correct assignment, loading/no-cache/offline-cache/refresh-error Retry/reconnect, standalone back and instructor To review unchanged. Runtime/visual acceptance pending; no disposable testing materials/staging/commit/push.


## Owner-selected Classes and To-do empty mascots - 2026-10-20

Owner requests Confused Sprout Notebook Mascot for no-classes and Cheerful Sprout Note Mascot for To-do empty state. Reviewed reports/query/docs/UI UX/brief/current empty widgets and visually inspected exact source PNGs. Copied originals unchanged from docs/mascot and icon to frontend/assets/mascots/confused.png and cheerful_note.png (distinct from pre-existing cheerful.png). ClassesEmptyState swaps Curious to Confused144dp; TodoEmptyState swaps checklist icon to Cheerful Note144dp/24dp text gap matching Classes. Existing shared Mascot excludes decorative semantics and displays static artwork. Existing directory asset declaration covers additions. No image/vector edits, animation, dependencies, state/wording/filter/routing changes; shared mascot defaults and all other pages unchanged.

No tests/static analysis/builds/devices run. Owner fully stops/relaunches app for new assets, checks exact poses on Classes and To-do empty/filter/offline variants, scrolling at large text and normal populated cards unaffected. Runtime acceptance pending. PNG assets required production materials, no disposable files created/staging/commit/push. Binary art not semantically indexed by Graphify; widget references and this provenance note document usage.


## Explicit mascot bundle entries after missing assets - 2026-10-20

Owner screenshots show Unable to load asset for confused.png and cheerful_note.png. Source inspection confirms both original PNGs exist and widget pose paths match; previous pubspec declared directory only. Running bundle state cannot be verified under owner testing policy; stale incremental bundle is a possibility, not proven. Replaced mascot directory declaration with explicit entries for all7 existing PNGs, including both requested empty-state assets, to make additions explicit pubspec inputs. Refreshed Dart/Flutter package metadata offline; no dependency upgrades/assets substituted or image changes. A full stop/relaunch is required to regenerate the installed asset bundle; hot reload alone cannot establish acceptance. No wrong-pose or silent blank fallback added.

No tests/static analysis/builds/device checks run. Owner stops running flutter session then runs flutter run --dart-define-from-file=.env.dev.json from frontend, checks Classes Confused and To-do Cheerful Note plus other mascot pages/offline display/large-text scroll. Runtime acceptance pending; no disposable files created.


## Files Confused Notepad empty mascot - 2026-10-20

Owner requests exact Confused Sprout Notepad Mascot.png for Files. Reviewed reports/query/docs UI UX/brief/file messages/files flow/current MyFilesScreen; visually inspected exact PNG. Copied unchanged to assets/mascots/confused_notepad.png, distinct from Classes confused.png, and explicitly declared in pubspec; offline metadata refresh performed. Replaced Files text-only empty state with tint rounded panel/original static144dp mascot/22dp heading/15dp text matching other empty screens. Existing no-files wording split into title/help, no-match retains title with Try another file or folder name helper. Applies when visible files/folders empty, including folder/search; loading/errors/populated lists/imports/sort/folder actions/backups/offline storage logic unchanged. No dependencies or image edits.

No tests/static analysis/builds/devices/live checks run. Owner fully stops/relaunches app, checks Files empty root/folder/search exact mascot and scroll at large text, populated file/folder actions and loading/error Retry remain. Runtime acceptance pending. Production PNG retained; no disposable materials created/staging/commit/push. Binary art provenance recorded here; not independently graph indexed.


## Shared bottom sheets, Files actions and calmer Classes - 2026-10-20

Owner requests removing awkward Classes animation, restyling Upload files/New folder and reusable consistent bottom sheets throughout app. Reviewed reports/query/docs inventory/UI UX/brief sheet and button specs/file/class wording/current Classes/Home/router/widgets and all14 sheet call sites. Classes contains no custom entrance animation; source exposes Scaffold FAB relocation/grow transitions and NavigationBar selection animation. Disabled Classes FAB animator and navigation duration, plus ClassesScreen account/preview/join sheet transitions; ordinary press/ripple feedback and class route navigation retained. No mascot motion added.

Added exported core showFiloBottomSheet<T> and FiloSheetAction. Shared shell uses28dp rounded light surface/560dp width cap,40x4 handle,22dp header with Close48dp target,90%-available-height constraint, one outer scroll region, consistent Nunito/Phosphor list-tile styling and24dp bottom spacing. Keyboard inset applied once externally and consumed for builder context; safe bottom applied once. Native modal dismissal/results/drag semantics retained, optional animation flag and owner reduced-motion use AnimationStyle.noAnimation; other sheets use existing400ms uiDuration/native eased route. Removed nested form/content scrollers/redundant padding to make parent scrolling responsible. Builders remain shrink-wrapped, folder picker ListView shrinkWrap/non-primary/non-scrollable under shared scroll. Long filenames remain full body content under generic File actions/Folder actions/File preview/Post details headings; header limited2lines.

All14 call sites migrated: Classes account/preview-role/join, class options/details/settings/preview post, Files backup/move/add/file/folder actions, file preview and assessment sample questions. Original action labels/results/callbacks/permission-disabled checks/confirmation gates preserved; duplicate heading rows removed where shell now owns title. No mutation or API contracts moved into shared shell.

Files standard plus FAB replaced with full-width shared FiloButton Add files/busy Please wait with no FAB motion and original picker-entry guard; Upload files/New folder are reusable FiloSheetAction cards with icon tile, helper, chevron and explicit enabled/button semantics. Selection still returns original files/folder keys, opens existing device picker or name dialog; imports are local as before, no cloud upload implied. Join shared button now uses busy palette and repaired Sending ellipsis. No dependencies/backend/storage rules/auth/navigation changes.

No tests/static analysis/builds/device/live checks run. Owner checks Classes stable footer/tabs/sheets, Files Add/Upload selection/cancel/import errors/New folder name/cancel and busy guards, long filenames/large font/full action lists and folder picker scrolling, Join class keyboard/validation/offline/retry and result callbacks, account signout/backup/class settings/role guards/confirmation cancellation, previews/sample bool results, close/back/barrier/swipe dismissal and reduced motion. Runtime acceptance pending. No disposable testing materials created/staging/commit/push; only lasting components/docs retained.


## Consistent lightweight sheet motion and lazy folder picker - 2026-10-20

Owner requests animations on other sheets like Add files while reporting perceived lag. Reviewed reports/query/docs/UI UX/motion brief/current shared shell and all animation opt-outs. Existing14 sheets already share native route animation, but3 ClassesScreen call sites opted out from prior direction. Removed those opt-outs per latest explicit request; Classes FAB/nav animations stay disabled. All sheets now use dedicated FiloAnimation.sheetDuration/sheetReverseDuration300ms instead of general400ms uiDuration. Uses native Material eased transition once, no row stagger/fades, spring/blur/pulse or new animation controllers. Reduced motion still AnimationStyle.noAnimation; existing animate opt-out remains available to future callers.

Shared sheet body now RepaintBoundary isolates content painting. Added scrollBody=false for bounded caller-owned scrollables; standard small menus/forms retain one outer SingleChildScrollView and consumed keyboard/safe insets. Move-to-folder picker now ListView.builder, no nested outer scroll; fewer than8 folders shrink-wrap, larger lists fill bounded sheet viewport and build lazily. Root result/excluded folder set/order/selection callbacks and move validation unchanged. Uses const ListTileThemeData/styles. No permission/results/auth/data mutation/dependency changes; keyboard/close/drag/dismiss semantics preserved.

These are source-level reductions in animation duration and list layout/paint work, not evidence of measured FPS or root-cause profiling. No tests/static analysis/builds/device/performance/live checks run under owner testing policy. Owner checks all sheet open/close (including Classes account/Join), no per-row bounce, repeated dismissal, keyboard/large text/reduced motion, large folder-list scrolling/root-and-folder selection/cancel, original offline/retry/disabled/confirmation behavior. Smoothness/runtime acceptance pending on owner device. No disposable materials/staging/commit/push.


## Remove duplicate Join class sheet title - 2026-10-20

Owner wants only Find your classroom heading instead of Join class shell title plus body heading. Shared sheet title now nullable: title=null renders compact48dp handle/Close row without title, preserving native dismissal/keyboard/scroll/motion. Join sheet opts in, existing Find your classroom body heading marked semantic header. Other sheets retain titles unchanged. No join callbacks/validation/offline guards/busy logic changes. Source inspection/formatting only; no tests/static analysis/builds/devices. Owner checks single heading/Close/back and keyboard/Join validation/offline Retry; runtime acceptance pending. No disposable materials created.


## Waiting mascot for Done empty state - 2026-10-20

Owner-selected Cute Notebook Mascot Waiting.png copied unchanged to production waiting.png and explicitly bundled. TodoEmptyState accepts mascotPose with existing cheerful_note default; student Done filter alone selects waiting at existing144dp. All/To do, populated lists, text, loading/error/offline/retry and instructor flows unchanged. Offline dependency metadata refreshed; no dependencies added. No tests/static analysis/builds/device checks run; owner checks full restart, empty Done artwork, other filters and populated Done navigation. Runtime acceptance pending. No disposable files created.


## Drive backup presentation polish - 2026-10-20

Reviewed Graphify/design/flow/file messages and actual service. Existing one-way Drive permission, Wi-Fi preference, durable queue, confirmed last-success, retry, file import and external Drive callbacks preserved. Page now has28dp heading/cloud tile,24dp margins/600dp cap, rounded settings/status panels, shared tactile primary Back up now / Retry and secondary picker, live service message, readable last-success/pending count, lazy sliver file cards, safe-area scroll, styled unavailable Retry/sign-in states and scrollable28dp permission dialog/shared Continue action. Fixed mojibake apostrophe and middle dot via Unicode escapes; no restore feature, fabricated progress, new animation, dependencies or service changes. No tests/static analysis/builds/device/live checks run. Owner checks enable consent cancel/deny/allow, off/disabled/busy states, Wi-Fi/offline queue, picker cancel/error, retries/partial failure/success timestamp and bytes, many/long files/large text, external Drive fallback. Runtime/performance acceptance pending. No disposable materials created.


## Drive permission shared confirmation - 2026-10-20

Replaced basic Drive permission AlertDialog with existing showFiloConfirmation: mint cloud-upload icon tile, centered semantic heading, readable original permission body, rounded28dp surface/24dp inset/400dp cap, scrollable content and stacked shared tactile Continue to Google/Not now controls. Exact permission wording and service.active/enable logic retained; dismiss/back/cancel remain false and cannot start Google consent. No shared widget changes/new dependencies/animations. No tests/static analysis/builds/device/live checks run. Owner checks popup large text/scroll, Not now/back/barrier leave backup off, Continue opens Google consent, deny/error remains off and retry can reopen. Runtime acceptance pending. No disposable materials created.


## Reuse Drive permission and clarify Google account - 2026-10-20

Implemented approved plan: DriveApi.authorize checks authorizationForScopes first and calls authorizeScopes only when missing, interactive and not closed. Existing noninteractive upload/token-refresh paths cannot launch consent. Existing lightweight account recovery then interactive fallback retained, now checks active before fallback; email and saved Google ID guards unchanged and run before authorization/uploads. Reconnect message distinguishes native Google authorization from Filo login. Page heading Back up your files., signed-in email when present and approved Google permission explanation added, one-way scope/folder copy retained. No Supabase signout/login, backend/schema/dependency/public API changes; no new token persistence or broad scope. No tests/static analysis/builds/device/live checks run. Owner checks first consent, granted reuse, restart/native recovery, cancel/deny/revoked reconnect, wrong-account refusal, offline/Wi-Fi queue and retry, auth unchanged, long email/large text. Google controls remaining chooser/security prompts; runtime acceptance pending. No disposable materials created.


## Classroom card screenshot polish - 2026-10-20

Reviewed Graphify/design brief/UI guide/class messages/current source/callers and screenshot. Existing reusable ClassCard retains section/instructor in banner and course row, private signed image/fallback provider, whole-card navigation and instructor request badge. Polished28dp bordered surface/light shadow, compact44dp book tile reserved beside26dp wrapping section,32dp avatar/ring and readable instructor, white course row with40dp mint book tile/18dp wrapping title/36dp arrow tile. Gradient now protects white text on all custom colors and photos; pending tint replaces whole-card opacity to preserve readable text, disabled semantics match actual callback, wrapping amber approval and archived read-only labels retained (repaired punctuation). No fake counts/deadlines/new APIs/provider/routing/role changes/animations/dependencies. Skeleton banner adjusted148dp. No tests/static analysis/builds/device checks. Owner checks active/cached class taps, pending nonopenable/approval, archived read-only routing, instructor request badge, long section/course/instructor and enlarged text, custom banner loading/failure/offline fallback, multi-card scroll. Runtime/visual acceptance pending. No disposable materials created.


## Screenshot warning source cleanup - 2026-10-20

Matched eight screenshot patterns by source inspection: awaited signed URL Future inside async classImageProvider, braced three shared class-image guards and two shared icon/button motion guards, migrated two deprecated Uuid.NAMESPACE_URL uses to Namespace.url.value with explicit enums import (same URL namespace, preserves durable UUID keys). Current ticker code already uses valuesOf(context).enabled; cropped deprecated of warning could not be pinpointed and may be stale or another location. No speculative broad replacements. No tests/static analysis/builds/device checks run; owner refreshes Problems, provides exact file/line for remaining of diagnostic, checks image fallback/loading, reduced motion/buttons and backup queue retry/no duplicates. Runtime acceptance pending. No disposable materials created.


## M7-SA-01 owner decisions and M7-BE-01/02/03 preparation - 2026-10-20

Owner explicitly accepted both planning choices: keep the instructor question bank and prohibit deleting a quiz after a student starts. Owner chose to apply migrations and run the DEV checks personally, with step-by-step instructions. This is product-direction acceptance, not database/security acceptance.

Source review found existing tables/publish validation/totals/guards/RLS, but no atomic question-save/reorder RPC or dedicated quiz/bank acceptance scripts. Found gaps: publication and first-start calls did not serialize; instruction/deletion edits remained allowed after lock; old/new parent checks and totals were incomplete on reassignment; bank ownership did not require instructor role.

Prepared new migrations `20261020100000_quiz_publish_security.sql` and `20261020110000_atomic_questions_and_bank.sql` without editing applied files. Parent quiz locking serializes publishing/start/content/save/reorder/deletion; option/key guards pin question rows before parent resolution, with possible database deadlock aborts requiring whole-transaction retry. Publication rejects deleted rows and preserves existing messages, repeat-publication behavior and active-member inbox payloads. Started quizzes refuse content/settings/instructions/type/deleted_at edits; title/valid close remain editable. Server result changes and class purge remain permitted.

Added verified-owner atomic save_question and exact-permutation reorder_questions. Shared strict validation enforces the documented type limits; edits replace options/key with all-or-nothing rollback and retain question/AI identity. Existing direct draft-table permissions remain compatible. No empty-ID retry idempotency is promised.

Bank shape retained: options list of {text,is_correct}, exactly one MC flag; answer {boolean:true/false} or {accepted:[text,...]}; essay neither. Guard normalizes unused fields and validates content, while legacy rows can still receive tombstones. Instructor-own policy now excludes students/unverified users; client hard delete revoked in favor of deleted_at. Copy conversion uses save_question without the bank ID, ensuring independent quiz copies.

Maintained rollback-only scripts: backend/tests/quizzes.sql and question_bank.sql, with authenticated fixtures, individual results, summaries and snapshot checks, including deliberate failure after question/options writes. Maintained quiz_concurrency.sql supplies separately selected two-tab blocks with committed dedicated fixtures and explicit cleanup. Backend tests README provides exact migration/run order. Both API documents, Markdown Background Schema and deletion wording updated; copy human reviews remain pending.

Status: PREPARED, NOT DEPLOYED OR EXECUTED. No tests, static analysis, builds, manual app checks, SQL scripts, migrations, or live API verification run by assistant. M7-BE-01/02/03 completion and checklist 2/quiz portion of 5 are pending owner DEV results. No remote migration-ledger state is inferred. No disposable scripts/logs/screenshots created; maintained regression scripts intentionally retained. Pre-existing frontend/pubspec.lock change preserved.


Graphify follow-up: `graphify update .` attempted; its CLI environment lacks tree_sitter_sql and refused graph replacement because saved semantic nodes would be lost. No force overwrite used. Updated 11 task-specific semantic fragments and their fingerprints. scripts/refresh-graphify.ps1 then refused structural publication because pre-existing semantic source changes remain in role_selection_view.dart, pubspec.lock and sync_coordinator_test.dart. Published graph does not yet contain the M7 additions; existing coverage gaps remain. Unrelated fragments/fingerprints were not overwritten. docs/ is already Git-ignored in the canonical app; requested docs are updated locally without altering ignore policy or staging files.


## M7 owner-reported first quiz run failure - 2026-10-20

Owner screenshot: `P0001: Quiz not found`, start_exam(uuid) line 11, inline block line 185 at assignment. This proves that run aborted at student start; it does not show earlier per-case results, establish the underlying cause, or independently attest migration application. No M7/checklist acceptance claimed.

Source inspection found an unguarded student-start assignment after helpers that collect earlier FAIL rows. Its exception prevents those result tables from being returned, potentially hiding a preceding publish failure. Updated maintained quizzes.sql to catch and record the actual start SQLSTATE/message/context plus admin fixture state (quiz status/schedule/deletion, class lifecycle, student membership) and earlier FAIL details. Dependent during/after checks are explicitly incomplete/FAIL on start failure; lock checks continue with their existing manual lock fixture. No publish/access requirement weakened and no applied migration edited. Owner runs ROLLBACK separately and reruns the entire latest script, returning FAIL details and summary. No assistant tests, SQL/live checks, builds or static analysis run. No disposable materials created.


## M7 owner summary and cascade-delete correction - 2026-10-20

Owner supplied summary 193 PASS, 9 FAIL, overall FAIL. Earliest failures: remove incomplete multiple_choice, true_false and identification. Other failures: publish complete quiz, republish, inbox count, published-row student read, student start and dependent during/after checks. Exact per-case details requested; summary alone does not attest each error or installed migration definitions. No checklist/task acceptance.

Source confirms a defect in authenticated question deletion: FK child cascades happen after the parent question disappears, while guard_class_content_write resolves the class of options/keys through that parent. Prepared new migration 20261020120000_quiz_question_delete_cascade.sql rather than editing applied files. guard_question_edits validates/locks quiz then deletes keys followed by options BEFORE deleting the question. Parent remains visible for child RLS/lifecycle guards; all changes remain atomic and existing ownership/archive/deletion/lock/server-purge protections stay. No auth bypass or trigger-depth exemption. Updated maintained quiz script with correction preflight and parent/child absence assertions for each incomplete type; original failures remain real assertions. Updated both API docs/schema and owner guide. Owner applies pending correction then reruns entire latest script and bank checks; dev/security acceptance pending. No assistant tests, static analysis, builds, migration deployment or live verification. No disposable materials created.


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
# M7 instructor frontend implementation — 2026-10-21

Owner accepted FE-01–06 implementation, retained the question bank, selected
light theme only and required valid questions for server draft saves instead of
changing the backend to accept unfinished questions. Settings-only drafts may
have zero questions. Unsaved changes remain in memory; confirmed server data is
cached for offline reading. There is no authoring outbox or device recovery of
unfinished edits. Student quiz-taking/results/AI generation remain outside this
change.

The live instructor builder replaces the session-only assessment preview path;
instructor Classwork merges assignment due times with assessment opening times,
ascending with undated rows last and ID tie-breaks. Existing assignment and
student navigation is retained. Complete instructor detail uses a single nested
quiz/questions/options/keys read and schema-v5 account-local snapshots. Shared
quiz sync updates metadata/restrictions and evicts deleted snapshots; class
cache deletion cascades. Bank reads/writes stay online, and quiz copies have no
bank foreign key.

Settings creation uses a retained quiz UUID for retry reconciliation. Questions
use save_question with server-created IDs; transport-uncertain creates block
another attempt until the owner reloads confirmed content. Saves are sequential,
not an aggregate server transaction: successful parts advance their baseline,
failed/remaining edits stay dirty, and full success is not announced on partial
failure. Publication/deletion outcomes require confirmation; unknown outcomes
require refresh/reload. Started quizzes permit only title/closing-time patches;
archive and server guards remain authoritative. Date helpers explicitly use
Asia/Manila UTC+08:00 independent of device timezone. Display statuses use the
current UTC device clock and never authorize student starts; server validates
actual timing. No new server time endpoint was introduced.

Maintained date/status/model and cache-reopen/isolation/upgrade tests added.
Assistant did not run tests, static analysis, builds, SQL, live APIs or device
checks. All FE acceptance, helper-test passes and Redmi/130%-text performance
remain pending owner execution. No disposable test guide, screenshot, sample
data or log was created; maintained regression tests are intentional source.


## Workmanager package-resolution repair - 2026-10-21

Owner build output reports org-dartlang-untranslatable-uri for package:workmanager/workmanager.dart. Source inspection confirms pubspec.yaml still declares Workmanager and the other M6 packages, while the local lockfile and generated package configuration had omitted twenty required direct/transitive packages. Offline dart pub get restored the existing declared dependency graph; offline Flutter pub get then completed successfully and regenerated plugin metadata, including Workmanager Android. pubspec.lock now matches repository HEAD; no package constraints or app source were changed for this repair. SDK lockfile access required the approved tool escalation. No tests, static analysis, builds or live/device checks were run. Owner retries the normal configured Flutter launch; compilation/runtime acceptance is still pending. No disposable files created.

## M7 TableUpdate import collision fix - 2026-10-21

Owner compiler output identifies assessment_repository.dart:100:39: TableUpdate exported by both Drift and Supabase storage_client. Narrowed the Supabase import to SupabaseClient and PostgrestException so cache notifications resolve to Drift TableUpdate. No behavior/API/dependency change. Formatting/source inspection only; no tests, static analysis, builds or devices run. Owner retries the same configured launch; build/runtime acceptance pending. No disposable materials created.

## M7 draft insert permission correction - 2026-10-21

Owner reports generic unavailable/read-only text during Publish. Source trace finds draft creation preceding publication submitted id, but authenticated quiz INSERT grant in 0007 excludes id and server default generates it. Removed client UUID from quiz insertion; use returned server ID and whitelist only granted insert settings. No backend privilege change. This supersedes the retained-client-quiz-UUID paragraph above. Before creation, capture accessible IDs/settings; transport-uncertain creation is not replayed, and explicit reload only adopts a unique newly visible matching draft, otherwise instructs Classwork refresh. Known database aborts can retry. Added maintained payload regression; formatting/source inspection only, no tests/analysis/build/API/device checks. Owner new-form Save draft then Publish and lost-response reconciliation acceptance pending.


## 2026-10-21 - Performance scaling foundations

Implemented source-backed optimizations without claiming measured FPS improvement: Stream uses lazy slivers with stable post keys/reorder lookup and existing PageStorage key, header/loading/offline/error/retry states and actions. Student and instructor work queues build first-match ID indexes once per evaluation rather than scanning related rows for every entry. Instructor navigation badge now uses a count-only provider with the same eligibility rules and a separate Consumer widget; it does not construct/format/sort queue entries or rebuild the Classes screen on count changes. Full snapshots and existing sync freshness remain in use.

App foreground lifecycle gates descendant tickers, preserving route TickerMode; post skeleton also respects hidden-route/reduced-motion state and avoids restarting an already running controller. Original PNGs, light theme, confirmed operations and account guards retained. Source inspection found existing coalesced sync runs and per-page transactions, so no sync replay/cursor/database notification semantics were changed. No APIs, migrations or dependencies changed.

Owner physical-phone debug slowdown includes intro; profile-mode baseline and before/after UI/raster/memory captures are pending. Gradient caching, paging and additional isolates remain measurement-dependent and deliberately deferred. Owner checks intro/swiping/background/resume, long Stream/insertion/deletion/scroll restoration, both-role queue and instructor badge parity, cached offline reads and failed refresh/reconnect/Retry, large text and reduced motion. Target at 60Hz: at least95% steady-interaction UI and raster frames within16.7ms; adjust budget for actual refresh rate. No tests, static analysis, builds, device checks or live verification run. No disposable materials created.


## M7-FE-02 instructor assessment list implementation - 2026-10-21

Current checkout now connects the signed-in instructor Classwork tab to cached
assignment and quiz/exam metadata. Default date order is created_at newest first;
all four requested filters, calm type/status chips, Manila windows/counts/points,
loading/empty/error/offline states and refresh/retry are implemented. A separate
instructor assignment-read checkpoint avoids mistaking missing cache for empty
content. Existing student Classwork behavior is retained.

The action above the class tabs and row navigation use a connected basic form
entry. It loads saved questions without rewriting them, saves basic settings,
warns before published edits, restricts started quizzes to title/closing time,
and prompts before discarding edits. Question editing and publishing UI remain
follow-on builder work. Archived classes are read-only. Delete is confirmed
server-side, hidden after a start, and guarded against start/archive races.
No backend or dependency additions. Runtime and visual acceptance remain pending
owner checks; no assistant tests, analysis, builds, live API or device checks
were performed. See API_CHANGES.md M7-FE-02 for interfaces and cache behavior.


## M7-FE-02 reconnect recovery correction - 2026-10-21

Owner reports Classwork pull/Retry needs force-close after Wi-Fi returns.
Corrected the source recovery gap: explicit shared connectivity recheck before
manual pulls, always reachable instructor Retry, connectivity-reactive refresh
providers, deduplicated/bounded manual refresh and preserved cached rows.
Connectivity error recovery no longer gets filtered out when the next successful
value equals the previous good value. Existing bool-stream consumers, session
verification, archive/ownership rules and offline write restrictions are retained.
Three maintained connectivity regression tests were added, not run. Device
reproduction/reconnection and runtime acceptance remain owner work; no tests,
analysis, validation builds, live checks or disposable materials.


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


## Current-branch diagnostics cleanup - 2026-10-21

Owner supplies a 41-item VS Code Problems screenshot after Git branch changes.
Current checkout is frontend at 3269cce. Screenshot red errors refer to an older
AssessmentRepository/assessment_cache.dart/assessment_widgets.dart implementation
that is absent from this checkout. Current sources use InstructorQuizRepository,
assessment_row.dart and AssessmentFormScreen; InstructorClassworkList already
accepts active, Supabase imports already expose only SupabaseClient and
PostgrestException alongside Drift, and FiloButton already uses
TickerMode.valuesOf. No obsolete implementation or compatibility stubs restored.
Editor diagnostics must be refreshed against this branch before claiming a
current error count; unseen/unsaved editor buffers were not overwritten.

Added braces to multiline executable control bodies in connectivity, instructor
repository/list/form and profile-photo code. Awaited _completePhoto inside the
profile INSERT try block to address unawaited_return_in_try. Collection-if UI/map
expressions and account/archive/offline/reconciliation rules are retained.
Formatting and source/diff review only; no analyzer, tests, validation builds,
app/device or live checks run. Owner checks: restart Dart analysis server to
refresh Problems, then usual configured launch; profile photo success/failure
retry if exercised. Runtime/compiler acceptance remains pending. No disposable
materials, dependency/backend changes, staging or commits.


## M7-FE-04 owner acceptance - 2026-10-22

Status: Complete - accepted. Owner explicitly reported "okay all runtime accepted"
for question cards and follow-up three-page builder, screenshot design changes,
Add question footer, simplified headings, exact validation targets and app-bar
Classwork destination with unsaved protection. Acceptance is owner-reported;
assistant did not independently run tests, builds, analysis or device/live checks.
Maintained question-card and step regressions remain unexecuted by the assistant.
Graphify publication remains blocked by five unrelated semantic source changes.
No disposable task materials, automatic staging, commit or push.


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


### Question-bank picker shared modal - 2026-10-22
Owner requested matching Filo modal design. Add from question bank now uses
showFiloBottomSheet with shared rounded top, handle, title/Close, light surface,
width limit, keyboard/safe-area handling and reduced-motion-aware transition.
Picker renders content directly without nested Scaffold/AppBar. Search/filter,
feedback and lazy question rows share one scroller; Add selected stays at bottom.
Bank manager retains its standalone screen. Selection/copy/save rules unchanged.
Existing picker regression updated to use modal route; not run. Formatting/source
inspection only; no tests/analysis/builds/runtime checks. Owner visual acceptance
pending for keyboard, enlarged text, scrolling, Close/dismiss and add/cancel.
No disposable materials created.


### Question-bank sheet content sizing correction - 2026-10-22
Owner reports modal still mismatched. Source comparison found picker Column/Expanded
forced maximum sheet height even for empty/small banks. Picker now shrink-wraps
small lists with a loose Flexible and uses themed selectable list rows like other
Filo sheets; question type/points remain visible. Large banks retain lazy bounded
scrolling; manager retains full question/answer cards. Shared shell and bottom action
unchanged. Formatting/source inspection only; owner visual acceptance pending for
empty/small/large banks, keyboard, enlarged text, selection and dismissal. No tests,
analysis/builds/runtime checks or disposable materials.


## M7-FE-06 owner runtime acceptance - 2026-10-22
Status: Complete - accepted on owner report "okay all runtime accepted".
Covers requested question-bank save/reuse across quizzes, all four question types,
copy independence under edits/deletion, search/type-filter/multi-selection, explicit
assessment saving, online/error/retry and lock/archive rules, plus shared modal
layout/height, scrolling, keyboard/enlarged text and dismissal follow-ups. Supersedes
earlier M7-FE-06 runtime/visual acceptance-pending notes. Evidence is owner-reported;
assistant did not run automated tests, analysis, builds, device, SQL or live checks.
No unrelated task acceptance inferred. No disposable materials or Git mutations.

## M8-BE-01 exam regression prepared — 2026-10-22

Status: PREPARED, NOT EXECUTED; runtime acceptance and exam security checklist items 2 and 3 are PENDING. Owner selected rejection of oversized text and owner-run DEV execution.

Existing start_exam already caps deadlines at closing, persists shuffle orders and resumes the same open attempt; get_exam uses saved order and projects student-safe fields. Existing quizzes.sql has limited exam assertions. These are source findings, not proof of deployed behavior.

Added maintained backend/tests/exams.sql with verified authenticated-role fixtures and labelled PASS/FAIL results inside BEGIN/ROLLBACK. Covers start restrictions/idempotence/locking/deadlines, all four answer types and overwrite/foreign-input/length/time boundaries, repeated saved-order retrieval, full JSON sentinel/key scans and field allowlists, six-table direct-read privacy through pre-start/in-progress/submitted/released states, and exam score release/cross-student gates. Deadline fixtures change instead of waiting. Private rows exist as positive controls. Result release is fixture setup; scheduling, cron and essay grading are not claimed.

Confirmed source defect: save_answer silently truncates identification/essay text with left(p_text,10000). New migration 20261022100000_exam_answer_text_limit.sql rejects above 10,000 characters with 22001 / Answer must be at most 10000 characters, before any answer write, and preserves the function signature, access checks, timing and upsert. Historical migrations unchanged. API behavior and owner execution instructions updated.

Actual DEV results: none supplied for this task. Migration deployment/history unverified. Owner must apply only the required migration on fiobwfzmqcffbpixzvbq, run the entire regression, and supply results/date/migration state. Any FAIL or uncaught error blocks acceptance; fixes go in new migrations. Checklist 3 acceptance here is exam-only, not assignment grades. No tests, SQL, live API checks, static analysis, builds or device checks run by assistant. No disposable testing materials created; SQL is lasting regression coverage. No staging, commit or push.


## M8-BE-01 owner DEV acceptance ? 2026-10-22

Status: COMPLETE ? accepted for the requested exam SQL/backend scope. Owner supplied the final regression summary: passed=178, failed=0, overall=PASS, failures=[]. This supersedes earlier M8-BE-01 prepared/not-executed and acceptance-pending statements. Evidence is owner-reported aggregate output; no case-level rows, independent run or migration-history inspection was supplied.

Exam security checklist item 2 accepted for direct question/option/key isolation before, during and after the exam; item 3 accepted for exam score release gating. Covers the maintained script's start eligibility/idempotence/deadlines/shuffle/lock, saved-order retrieval and privacy, all four answer types/overwrite/foreign-input/length/grace boundaries, protected-table reads, and cross-student/released-result checks. Assignment grading, HTTP/device/offline behavior, concurrent load, cron/release scheduling and essay grading are outside this acceptance.

Assistant did not run tests, SQL, live verification, static analysis or builds. The regression script and migration are maintained implementation files; no disposable testing materials were created or removed. Unrelated frontend changes remain untouched. No staging, commit or push performed. Documentation under docs/ remains ignored by the app repository; graph artifacts live outside that repository.

## M8-BE-02 submit, leave counting and time-out prepared — 2026-10-22

Status: PREPARED, NOT EXECUTED. SQL regression, cron availability/deployment, unattended proof, fallback app recovery and runtime acceptance are PENDING. M8-BE-01's 178 PASS is prior owner evidence only; no M8-BE-02 result has been supplied. Owner executes DEV SQL/deployment/checks on fiobwfzmqcffbpixzvbq.

Extended maintained backend/tests/exams.sql, preserving existing assertions. Added authenticated normal/late/idempotent/foreign submit, weighted correct and incorrect MC/boolean/identification grading (total 18), case/whitespace normalization and blank handling, pending essay/unanswered item, score privacy and internal-helper ACL checks, leave event deduplication/exact counts/+60-second boundary, global expiry worker +10/+15/+16-second and repeat cases, and fallback verification/isolation/release checks. Clocks use fixture deadline changes, never sleeping. Global worker refuses unrelated overdue DEV attempts in the regression; release-ready global quiz evaluation still occurs transactionally. Database rollback does not guarantee cancellation of configured external webhook effects.

Source-confirmed defect: norm_text used an over-escaped whitespace expression. New immutable-history migration 20261022110000_exam_finalization_and_schedule.sql replaces it with POSIX whitespace collapse followed by trimming/lowercasing, preserving word boundaries and matching keys and answers consistently. It adds verified caller-scoped finalize_accessible_exams(), returns void, and preserves access boundaries/server-only grading helpers. It finalizes only current-member own attempts or instructor-owned attempts in open accessible classes and checks eligible result release. SyncCoordinator invokes recovery before result/instructor pulls; isolated errors retain retry state and retry at the next normal online sync. Small maintained frontend regression added for failure isolation and retry, not executed.

The same migration attempts pg_cron availability and ensures one active per-minute filo-finalize-exams job in the current database; only duplicate copies of that named job are removed, other jobs preserved. Extension installation failures warn explicitly with SQLSTATE/message and leave deferred recovery deployable. No remote extension/job inspection or activation was performed by assistant. Owner preflight must inspect extension state, existing jobs/history and real overdue work before applying; scheduler activation may finalize real expired DEV attempts.

Three maintained proof scripts separate committed setup, read-only inspect and narrow guarded cleanup. The reserved marked fixture expires after 30 seconds; unattended PASS requires auto_submitted, submitted_at=deadline_at, score 7, grading complete and successful cron history after grace. App stays closed and no finalization/result/recovery RPC is called for those fixture users. Owner retains evidence before cleanup; fixtures_removed=true required. No fixture was created on DEV by assistant.

Fallback choice: owner explicitly accepts deferred finalization if pg_cron is unavailable. Online startup/resume/reconnect sync invokes the verified scoped recovery function; no app-open action means no timely finalization. This fallback is prepared as a recovery safety net even with cron installed. If DEV cron cannot run, record FALLBACK ACCEPTED (deferred) only after owner evidence, never claim unattended PASS. No new results screen, external scheduler, dependency or unrelated design change.

Actual results: none. Assistant performed source inspection/formatting only; no tests, SQL execution, static analysis, builds, live API or app/device checks. No disposable materials created; regression and cron scripts are maintained coverage. No staging, commit or push. Backend must deploy before the updated client. Runtime acceptance is pending owner results and job/fallback evidence.


### M8-BE-02 owner instruction preference - 2026-10-22

Owner requested removing the written preflight walkthrough and receiving execution instructions and npx.cmd Supabase commands in chat. Removed that README subsection and pre-deployment script comments; maintained SQL fixture, permission and unrelated-work guards remain. Task remains prepared; no new DEV results or assistant checks.


## M8-BE-02 owner DEV acceptance - 2026-10-22

Status: COMPLETE for requested backend SQL/cron scope on owner evidence. Owner reports exams.sql passed=294, failed=0, overall=PASS, failures=[]. This covers submission/grading/privacy, exact leave-event counting, expiry/grace and scoped recovery assertions while retaining the earlier exam checks.

Unattended proof: reserved session 8b020000-0000-4000-8000-000000000006 started 2026-10-22 13:59:29.978237 UTC, deadline 13:59:59.978237 UTC, grace eligibility after 14:00:14.978237 UTC. First inspection returned WAIT before inspect_after, not failure. Later read-only inspection returned PASS: auto_submitted, submitted_at=deadline_at, auto_score=total_score=points_awarded=7, essay_score=0, is_correct=true, grading_complete=true, successful_cron_after_expiry=true. updated_at and results_released_at were 14:01:00.014484 UTC. Owner then reports cleanup fixtures_removed=true. No committed proof fixture remains on owner evidence; maintained setup/inspect/cleanup scripts stay for regression coverage.

This supersedes prior M8-BE-02 pending statements for SQL regression, cron operation and proof cleanup. pg_cron worked on the tested DEV project; deferred fallback was not needed for unattended acceptance. SQL tests cover the scoped recovery RPC, but frontend app startup/resume/reconnect/error-retry behavior and its maintained Dart test were not reported as executed and remain unverified. Independent migration-ledger review, concurrency/load, production scheduling and real device behavior are not inferred. Assistant ran no tests/SQL/live checks/analysis/builds/device checks and did not independently inspect DEV. No staging, commit or push; unrelated assessment.dart retained. No disposable local materials created.
