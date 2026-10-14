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
