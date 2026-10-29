# Filo

Filo is an AI-assisted learning management app for Android, designed to bring classroom activities and study materials together in one place.

Built for instructors and students, Filo aims to simplify managing classes, sharing learning resources, submitting assignments, and taking quizzes and exams.

Its focus is on accessible learning, with offline access to downloaded materials and AI-assisted study tools such as chat, flashcards, and practice quizzes.

## Run the development app

From this directory, use the ignored development configuration file:

```powershell
flutter run --dart-define-from-file=.env.dev.json
```

Select your phone if prompted, or add `-d <phone-id>`. A plain `flutter run`
does not supply the required ENV, SUPABASE_URL, and SUPABASE_ANON_KEY values.
VS Code's **Filo DEV** launch configuration supplies the file automatically.
Do not commit the configuration file or include backend service credentials in it.

See [backend OTP setup and phone testing](../backend/OTP_TESTING.md).

## Native Google sign-in on Android

Continue with Google uses Android's native account picker. Its Google ID token is
exchanged with Supabase for a session; the existing device verification and OTP
flow then runs. Browser callback URLs are not used by this Android login method.

Add `GOOGLE_WEB_CLIENT_ID` to the ignored `.env.dev.json`. Use the **Web application**
OAuth client ID accepted by the Supabase Google provider, ending in
`.apps.googleusercontent.com`. No Google client secret belongs in the Flutter app.

In the same Google Cloud project, register an **Android** OAuth client with package
`com.filo.filo` and the SHA-1 of the certificate signing the installed app. The
current local debug SHA-1 is:

```text
CA:E6:6D:34:A4:FF:2E:24:85:A3:DA:66:A4:6B:B5:47:10:D3:FF:0D
```

Other developers and release/Play builds may use different signing certificates.
Register their fingerprints before testing those builds. This implementation passes
the Web client ID explicitly, so it does not require the Google Services Gradle
plugin or OAuth entries in the local `google-services.json` file.

After changing dependencies or Dart defines, stop the old run and launch again:

```powershell
flutter pub get
flutter run --dart-define-from-file=.env.dev.json
```

Account selection is followed by Supabase authentication and the OTP session gate.
Canceling account selection leaves the app signed out. Do not mark native phone
login verified until Google Cloud/Supabase configuration and the real account
selection/token exchange have been tested on the device.


## M9-FE-07 quiz results CSV (2026-10-25)

Instructor Results > Results options > Export CSV exports the current search/filter selection in the selected sort order, using the loaded authorized monitoring snapshot. Available offline and for archived classes; disabled without data, with an empty selection or while sharing. Columns: Student name, Status, Score, Total points, Percentage, Passed (only with a passing threshold), Essays graded, Leave count. Only current attempts are exported. Submitted provisional scores retain their percentage, Essays graded=No and blank Passed; in-progress/not-started scores and percentages are blank. Passing uses rounded percentage inclusively.

UTF-8 BOM, quoted/escaped cells and CRLF preserve spreadsheet text. Formula-leading text (including after whitespace) receives an apostrophe. Filename includes sanitized/truncated quiz title and Philippine date. Existing path_provider/share_plus dependencies open the native share sheet. A unique task-owned temporary directory is removed after the share operation where the OS permits. Cancellation has no success/error announcement; failures show "Couldn't export results. Try again." and restore retry. No API/schema/dependency changes.

Maintained results_csv_test covers row selection/order, conditional columns, status/grading/voided rules, rounding, missing scores, text safety/escaping/Unicode, filenames and offline/archived/empty/pending/error menu states. Tests, static analysis, builds and live/device checks were not run by the assistant; owner acceptance remains pending. This implementation supersedes the earlier FE-07 deferral; dark mode remains deferred.


M9-FE-07 owner focused tests (2026-10-25): owner supplied `flutter test test/features/results` output: 44 passed, All tests passed. Automated focused-suite acceptance is recorded on owner evidence; supersedes the test-pending label above. Phone share/cancel/retry, spreadsheet formula-text rendering and cached airplane-mode export runtime acceptance remain pending. No assistant tests, analysis, builds or live checks were run.


M9-FE-07 export directory correction (2026-10-25): owner reported Export CSV immediately showing the friendly failure. Source diagnosis found Directory(<cache>/filo-results-).createTemp() incorrectly treated a nonexistent child as the parent directory. Corrected to existingCacheDirectory.createTemp('filo-results-'). Added a maintained regression using a real test-owned temporary root and mocked native share channel to verify file location, CSV/BOM content and reaching the share sheet with dismissal. Prior 44-pass evidence predates this fix; owner focused rerun/device export remain pending. No assistant tests, analysis, builds or live/device checks.


M9-FE-07 regression async correction (2026-10-25): owner reported 44 passed / 1 failed, new filesystem/share regression timed out and cleanup encountered a Windows file lock. Test now invokes the actual menu callback and creates its completion inside runAsync, then awaits export-directory cleanup before teardown. Existing separate menu interaction tests remain. Production cache-directory correction unchanged; no timeout increase. Owner focused rerun/device export pending; no assistant checks run.


M9-FE-07 regression BOM assertion correction (2026-10-25): owner still reported 44PASS/1FAIL. SDK source confirms UTF-8 decoding discards the leading BOM; regression incorrectly compared readAsString to the BOM-prefixed builder output. Test now compares exact file bytes to utf8.encode(expected CSV), retaining explicit BOM assertion. Mock assertion failures complete the test future with the original error/stack instead of being swallowed into an export error/timeout. Production unchanged. Prior async diagnosis alone did not resolve the failure. Owner rerun/device checks pending; no assistant tests, analysis, builds or live checks.


## M9-FE-07 COMPLETE - owner acceptance (2026-10-25)

Owner supplied `flutter test test/features/results`: 45 passed, All tests passed, followed by explicit acceptance of all requested runtime checks. CSV export, filtered/sorted selection, phone sharing/cancel/retry, spreadsheet/formula-text rendering and cached offline export are accepted on owner evidence. Supersedes earlier test/runtime-pending notes for FE-07. No independent assistant execution is claimed. M9-FE-01 through FE-07 frontend scope is accepted in this conversation; dark mode remains deferred. No additional checks requested absent a new change or defect.

## 2026-10-29 automatic lesson extraction and frontend generation (owner checks pending)
Implemented local source slice in the active AssessmentFormScreen, not the legacy prototype. Saved, writable, unlocked instructor assessments offer Generate with AI. Select up to3 phone files (TXT UTF-8, text PDF, DOCX, PPTX), choose difficulty/counts, extract in background without an extracted-text preview, send text only to the existing authenticated direct-v2 function, review returned questions/answers and explicitly add them to unsaved assessment edits. Save remains explicit; no auto publication, backend/schema/model changes or automatic retry. Owner direction supersedes the earlier text-preview proposal.
Limits:10MiB per file,3sources,40000Unicode code points shared; excessive text rejected, never truncated. PDF pages read in order and disposed; any empty page rejected conservatively (blank versus scanned cannot be distinguished without OCR). DOCX main body paragraphs/table-cell text and PPTX presentation relationship order extracted with archive/XML in a worker isolate. Embedded images/charts/notes/headers/footnotes excluded; spatial layout not reconstructed. Legacy DOC/PPT and OCR unsupported. ZIP expansion/part/count and XML declaration checks added. Cached archive4.5.2/xml7.0.1 promoted from transitive to direct dependencies; offline dependency resolution completed. Flutter wrapper initially stalled and was interrupted; direct cached Dart pub resolution completed. Formatting only, no tests/build/static analysis/device or live API execution.
Sheet handles offline, unreadable/corrupt/encrypted/oversized sources, invalid counts, provider errors, explicit partial review and late-response discard. Closing does not cancel server processing; new requests may be blocked by existing AI_IN_PROGRESS gate. Account identity rechecked before displaying a response. Evidence/sample/rubric visible during question review only: existing assessment save contract cannot persist them; sheet discloses this. MCcorrect_index mapped to existing correct_option_index, AIgenerated marker retained. Generation requires saving the new assessment as draft first; existing class/lock/server authorization remains authoritative.
Maintained regression files: frontend/test/features/assessments/lesson_text_extractor_test.dart (8cases) and ai_quiz_response_test.dart (4cases); NOT RUN. Includes synthetic DOCX/PPTX ordering, TXT Unicode/limits/errors/XML declarations and four question formats, partial counts, bad rubric/MC and save-key mapping. Owner also runs existing quiz_save_ai_test.dart, quiz_draft_test.dart and question_cards_test.dart. Native PDF/device extraction and sheet integration/offline/cancel/permission/expired-session cases pending. Prior DEV/local evidence applies only to previously measured generation scope, not this new extraction/UI path. M10-BE-03 five-file results/manual scores/acceptance still incomplete. No task-created disposable materials.
Report: filo-app/docs/ai-quality-check.md; implementation notes: filo-app/docs/ai-messages.md and frontend/README.md. Explicit runtime/visual/content acceptance: pending owner, no Pass inferred.

## M10 frontend owner checks (FE-01 through FE-05, 2026-10-29)
Source implementation only; no assistant tests/builds/live calls. Full task acceptance pending owner evidence. Existing backend evidence is not evidence for this new extraction/UI path. No server migrations or model changes. Restart/rebuild the Flutter app after adding native OCR; hot reload is insufficient.

1. From frontend: `flutter test test/features/assessments test/features/results/results_repository_test.dart`. Expect maintained extraction/cache/migration/client/source-loader/sheet/writer plus affected existing checks to pass without real network calls. Stop on any failure. Negative fixtures are mocked errors, not live provider incidents.
2. From frontend/android: `.\gradlew.bat :app:testDebugUnitTest`. Expect native color/format bounds checks to pass; no phone needed. This has not been run by the assistant.
3. From frontend: `flutter run`. Use existing DEV configuration and a verified instructor with an active owned class. Create a draft, open Questions -> Generate with AI; supply title when missing. Existing edits must save first; no student visibility before Publish. Published/locked/archived assessments refuse AI writes.
4. Select one Class materials PDF and one From phone JPEG/PNG/WebP. Expect independent Reading/Ready/error rows, count and warnings, removal, max3files. Unsupported/over10MiB/no-text errors must leave other good sources usable. Repeat the same original: expect Cached, with no parsing/OCR (phone hashing still reads bytes). No source-text preview.
5. Exercise40000-code-point allocation with multiple long files: exact used-prefix warnings including0, no split Unicode characters; generator receives only nonempty allowed prefixes. Check counts0..20, Easy/Medium/Hard, focus<=200, first-use privacy OK and repeat/account-isolated acknowledgement. Turn connectivity off: Class materials and Generate unavailable; local reading remains possible.
6. Generate one DEV batch, cancel once, then explicitly retry. Late results must not add questions. A quick retry may show the exact AI_IN_PROGRESS copy. Inspect failures/partial results before retrying. No automatic retries, invented progress or raw errors. Verify returned/dropped/missing by type, and one direct_generation provider call if the deployed backend is direct-v2; logs needed to establish revision/call count.
7. Expect confirmed questions saved as drafts through per-question RPCs, AI badge and added highlight/scroll. Check edit/answer/points/reorder/duplicate/delete/reopen. Simulate known partial saves and unconfirmed transport outcomes: confirmed items stay; Retry targets failures only; uncertain inserts reconcile without duplicate RPCs. Stopping pending retries is explicit and cannot cancel already-sent work. Do not overwrite unsaved edits during reconciliation.
8. Regenerate one AI question: same cached prefixes/type/difficulty/position and current points; original remains until replacement succeeds. Cancel/error must preserve original. Expired/missing text offers original-source reselection; old-version/no context cannot silently guess. Over100current prompts/40000prompt characters refuses clearly. Publish reminder counts AI provenance including duplicates/edited AI questions. Confirmed publish/delete clears draft-owned cache, retaining shared text needed by another draft.
9. On Redmi and one older supported Android8+ phone, check at least3real documents of each type, including long/table/scanned PDF, table DOCX and multi-slide PPTX; plus photo formats, cancellation/timeout, memory pressure and130%text/48dp controls/light theme. Record actual device/OS/build, file sizes, elapsed time/method and problems in docs/decisions.md. Use a matching before/after release APK for size delta (`flutter build apk --release --split-per-abi` if needed); leave unmeasured rows Pending if no baseline exists. No claim that resource caps guarantee an RSS ceiling or that schema-valid questions meet requested difficulty.

## M10 frontend first owner test run: corrections, 2026-10-29
Owner supplied the focused Flutter command output: 91 passed / 14 failed after21:17 (attachment0c69101d-1d85-459a-a73e-93f63071a191). This run FAILED; FE acceptance remains pending. Failures include FilePicker API compilation blocking builder/sheet/steps, mock PostgREST nulls in writer/loader, the nullable TextField focus-node assertion and question-bank ambiguous search/card text followed by timeout/framework/timer cascades. Corrected picker to installed13.1 static/List API, attached originating requests to mock HTTP responses, asserted actual EditableText focus, selected the bank CheckboxListTile and disabled fixture auth auto-refresh. No production network/auth/save safeguards changed, dependencies changed, or timeouts increased. Separate in-memory account databases caused a Drift debug warning; no corruption inferred. No assistant test/build/static analysis execution; owner rerun required before any corrected Pass. Earlier test/native/device/quality gaps remain. See frontend/README.md and workspace qa/TEST_ACCEPTANCE.md.
## M10 picker remaining size API correction - 2026-10-29
Second owner transcript (d7914b54-4674-4f7b-9f0f-e71f29218ef4) reaches99passing/3compile-load failures at00:21, with no final summary. The previous static/List API fix missed PlatformFile.size. Installed platform_interface4.2.0 exposes asynchronous nullable length(). Updated phone selection to use it per file; unknown/failed length gets Size unavailable and a friendly row error, without discarding successful files or inventing zero bytes. Actual extraction retains its independent byte cap. Added mocked platform-picker regression for static/List/length API, cancellation, unknown size, oversized input and retaining cached ready text. No tests/build/static analysis/live/device checks run by assistant; owner first reruns ai_quiz_sheet_test.dart, ai_builder_test.dart and assessment_steps_test.dart, then the affected full command after they pass. Native/device/task acceptance remains pending. Prior91passed14failed history and repeated Drift test warning remain recorded; no corruption inferred. No dependency/model/backend changes, disposable files or Git mutations.
## M10 bank fixture teardown isolation - 2026-10-29
Owner tail12:26 +99 -5 reports bank edit did not complete and a Flutter test-listener directory already missing during finalization. First failure details/source revision/cancellation cause not supplied; no proof of a damaged project or production failure. Existing bank widget fake overrides network methods but unnecessarily constructed real Supabase clients and their JSON isolates. Replaced those clients with an inert typed sentinel that fails on unexpected use, eliminating SDK initialization/disposal/timers/network from all3bank widget fixtures. Existing assertions and production code retained. Source inspection supports removing this potential teardown blocker, not a runtime claim that all5failures are resolved. Do not delete project/temp directories or increase test timeout based only on this tail. Owner next: flutter test test/features/assessments/question_bank_test.dart --reporter expanded; expect4checks and clean completion. If passing, run the previously compile-blocked widget files, then affected full suite. No assistant tests/analysis/build/device/live verification; all remaining FE acceptance pending. Historical failures retained in qa/TEST_ACCEPTANCE.md; no disposable materials created.
## M10 owner isolated bank tests PASS - 2026-10-29
Owner supplied question_bank_test.dart expanded output:4passed, All tests passed at00:01. Scoped acceptance covers independent bank copies, hidden selection/order, load retry and edit retention/save retry; fixture completes without the earlier hang in supplied output. Preserve historical failures. This supersedes only the isolated bank-rerun pending note; no whole-M10/full-suite/native/device/production acceptance inferred. No repeat isolated run needed absent new changes. Owner next runs previously blocked ai_quiz_sheet/ai_builder/assessment_steps files, then affected full suite if passing. No assistant execution/implementation changes or disposable files; qa/TEST_ACCEPTANCE.md retains evidence and separate overall acceptance status.
## M10 widget fixture corrections after expanded output - 2026-10-29
Owner attachmentef50cf3b-5f53-44f7-b919-a2f7e3db1dd0 ends00:06 +3 -2, builder success case active, no final summary. Demonstrated test defects: tooltip finder returned RawTooltip instead of IconButton; steps asserted nullable wrapper focus node. Updated finder and EditableText focus assertions. Builder/steps now use a shared inert SDK sentinel; builder SQLite setup and DB cleanup run in tester.runAsync, unmounting before close. No real SDK initialization or teardown in these two UI fixtures. Production behavior/timeouts unchanged; exact stall cause unverified. Owner runs builder alone (2checks), then sheet+steps (5checks), before full suite. No assistant tests/builds/static analysis/live/device checks. Bank4PASS retained within its accepted scope without rerun; all overall FE acceptance remains pending. Fixture support/unused_assessment_client.dart is maintained required test infrastructure, no disposable files.
## M10 owner widget regressions PASS - 2026-10-29
Owner expanded runs: ai_builder_test.dart2PASS at00:04; ai_quiz_sheet_test.dart plus assessment_steps_test.dart5PASS at00:03. Titled-save success/rejection, picker API/errors/cancel, counts/privacy/offline/generation cancellation and steps focus/validation now accepted within mocked scope. Supersedes only the pending rerun notes for these7checks; historical failures preserved. Prior bank4PASS retained. No phone/provider/native/whole-M10 acceptance inferred. Next owner gate is affected combined Flutter suite; if passing, native checks and full DEV rebuild/device matrix. No assistant tests/builds/analysis/live/device work, implementation changes or disposable files. Full evidence/remaining gaps and explicit acceptance separation are in qa/TEST_ACCEPTANCE.md.
## M10 native JVM checks PASS - 2026-10-29
Owner reports Gradle BUILD SUCCESSFUL6m56s (286tasks,88executed198up-to-date). Read-only generated JUnit report frontend/build/app/test-results/testDebugUnitTest/TEST-com.filo.filo.LessonImageReaderTest.xml confirms2tests0failures0errors0skipped, timestamp2026-10-29T09:13:17.842Z, suite duration0.015s: dimension bounds and NV21 colors/order. Accepted only within JVM preprocessing scope; build elapsed is not OCR/device/quiz response time. Keep generated report ignored in build output. Prior bank4/builder2/sheet+steps5Pass retained, no isolated repeat required absent changes. Combined Flutter final output not supplied; phone OCR/extraction/full DEV flow and release APK measurements pending. Launch DEV with flutter run --dart-define-from-file=.env.dev.json after pending checks pass. No assistant tests/builds/static analysis/live/device execution or implementation changes; qa/TEST_ACCEPTANCE.md records separate overall acceptance.