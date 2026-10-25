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
