import '../widgets/filo_notice_dialog.dart';

const privacySummary =
    "Filo collects your name, email address, profile photo, school, and role, and stores class activity such as submissions, grades, and counts of leaving the app during exams. It also records device and login verification information to protect account access. Students can see only their own grades. Instructors can access records only for their own classes. When you use AI features, your requests and relevant text, including text from learning materials you select, are sent to Google for processing with Gemini. After account deletion, your submissions and grades remain in your instructors' records as Deleted User.";

const privacyNoticeSections = [
  FiloNoticeSection(
    heading: 'Your information',
    body: 'Filo collects your name, email address, profile photo, school, and selected role to set up your account. It stores your class activity, including submissions, grades, and counts of leaving the app during exams, to provide learning and assessment features. Filo also records device and login verification information to protect account access.',
  ),
  FiloNoticeSection(
    heading: 'AI processing',
    body: 'When you use AI features, Filo sends your requests and the text needed for those features, including text from learning materials you select, to Google for processing with Gemini. Avoid including passwords or sensitive personal information in AI requests.',
  ),
];
