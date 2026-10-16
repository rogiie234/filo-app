enum PreviewRole { student, instructor }

class ClassRoom {
  const ClassRoom({
    required this.id,
    required this.section,
    required this.course,
    required this.instructor,
    required this.color,
    this.pending = false,
    this.archived = false,
    this.schoolYear,
    this.joinCode,
    this.instructorPhotoUrl,
    this.instructorAvatarPath,
    this.bannerPath,
  });
  final String id;
  final String section;
  final String course;
  final String instructor;
  final int color;
  final bool pending;
  final bool archived;
  final String? schoolYear;
  final String? joinCode;
  final String? instructorPhotoUrl, instructorAvatarPath, bannerPath;
}

class ClassPost {
  const ClassPost({
    required this.id,
    required this.classId,
    required this.title,
    required this.message,
    this.assignment = false,
    this.points,
    this.dueLabel,
    this.attachments = const [],
  });
  final String id;
  final String classId;
  final String title;
  final String message;
  final bool assignment;
  final int? points;
  final String? dueLabel;
  final List<String> attachments;
}

class PreviewQuestion {
  const PreviewQuestion({
    required this.prompt,
    required this.options,
    required this.correct,
    required this.points,
    this.type = 'Multiple choice',
    this.answer = '',
  });
  final String prompt;
  final List<String> options;
  final int correct;
  final int points;
  final String type;
  final String answer;
}

class Assessment {
  const Assessment({
    required this.id,
    required this.classId,
    required this.title,
    required this.type,
    required this.minutes,
    required this.questions,
    this.draft = false,
    this.instructions = '',
  });
  final String id;
  final String classId;
  final String title;
  final String type;
  final int minutes;
  final List<PreviewQuestion> questions;
  final bool draft;
  final String instructions;
  int get points =>
      questions.fold(0, (total, question) => total + question.points);
}

class PreviewFile {
  const PreviewFile(this.name, this.type, this.size, this.description);
  final String name;
  final String type;
  final String size;
  final String description;
}

const sampleFiles = [
  PreviewFile(
    'Introduction to computing.pdf',
    'PDFs',
    '1.2 MB',
    'A sample course handout covering computer systems, hardware, software, and the role of technology in everyday life.',
  ),
  PreviewFile(
    'Week 1 learning guide.docx',
    'Documents',
    '240 KB',
    'Learning objectives: identify the parts of a computer, explain the difference between hardware and software, and describe responsible technology use.',
  ),
  PreviewFile(
    'Computer components.png',
    'Images',
    '680 KB',
    'A sample classroom illustration of computer components.',
  ),
];
