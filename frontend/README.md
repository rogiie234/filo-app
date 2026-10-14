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
