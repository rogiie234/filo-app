import 'package:flutter/material.dart';

import '../application/exam_providers.dart';
import 'student_exam_screen.dart';

class StudentQuizDetailScreen extends StatelessWidget {
  const StudentQuizDetailScreen({
    super.key,
    required this.classId,
    required this.quizId,
  });
  final String classId, quizId;

  @override
  Widget build(BuildContext context) => StudentExamScreen(
    classId: classId,
    request: StudentExamHandoff(quizId: quizId),
  );
}
