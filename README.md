<div align="center">
  <img src="frontend/assets/brand/logo-mark-light.png" width="88" height="88" alt="Filo logo" />
  <h1>Filo</h1>
  <p><strong>Learning, together.</strong></p>
  <p>Your classes. Your notes. Your next discovery.</p>
  <p><a href="https://github.com/rogiie234/filo-app/releases">Downloads & releases</a> · <a href="#meet-the-team">Meet the team</a> · <a href="https://github.com/rogiie234/filo-app/issues">Report an issue</a></p>
</div>

## Welcome to Filo

Filo is an AI-assisted learning management app for **Android 8.0 and newer**, built for students and instructors. It brings classroom activities, learning materials, and study support into one approachable space.

Started as a final-year school project, Filo aims to make learning feel less scattered and more connected.

## Download and install

**Release preparation is in progress.** A public APK has not been published by this update. Check the [Releases page](https://github.com/rogiie234/filo-app/releases) for available builds and their release notes.

When an APK is available:

1. Open the release and read its notes, including any testing limitations.
2. Expand **Assets** and download the `.apk` attachment. **Source code ZIP/TAR.GZ files are not the Android app.**
3. Open the APK on your Android device. If prompted, allow installation from the browser or file manager you used, then follow Android's installation prompts.
4. Launch Filo and follow the in-app sign-in instructions.

If there is no `.apk` attachment, that release does not include an Android installer. A prerelease is a testing build; follow its notes before using it for classwork.

## What Filo brings together

| Area | What it is for |
| --- | --- |
| Classes | Announcements, learning materials, and assignments for students and instructors |
| Files | Organized class resources and offline access to files downloaded in the app |
| Assessments | In-app quizzes and exams, submissions, and grading workflows |
| AI-assisted study | Questions about source materials, flashcards, and practice quizzes |

Feature availability depends on the build. Downloaded files and saved study sets support offline use; sign-in, synchronization, AI generation, submissions, and official assessments require internet access. AI can make mistakes: check answers against your materials and ask your instructor when needed.

## Need a hand?

Found something that does not work as expected? [Open an issue](https://github.com/rogiie234/filo-app/issues) with your Filo version, Android version, steps to reproduce, and what you expected to happen. Redact personal details from screenshots; never include passwords, verification codes, private class materials, or credentials.

If an APK will not install, check its release notes and your Android version. An installed build signed with a different key may not accept an update. Do not uninstall as a first troubleshooting step: uninstalling can remove local files and unsynced work.

## Meet the team

| Team member | Role |
| --- | --- |
| Christian Orlan Motas | System Analyst |
| Rogelyn Nepa | Project Manager |
| Kent Aian Tabuelog | Frontend Developer |
| Rose Jean Tupaz | Backend Developer |
| Jhondel Cabugsa | Quality Assurance |
| Zaira Jane Estrada | Technical Writer |

## For developers

Filo uses Flutter and Dart with Riverpod, Drift/SQLite, and Supabase. The Android application lives in `frontend/`; backend source and migrations live in `backend/`.

For a release build, copy `frontend/android/key.properties.example` to the ignored `frontend/android/key.properties` and configure your local release keystore. Release builds use that signing configuration instead of the debug key. Keep the real signing file, keystore, passwords, and environment files out of Git. Select the intended backend configuration before building; no production configuration is bundled with this README.
