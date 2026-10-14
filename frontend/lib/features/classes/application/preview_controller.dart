import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/prototype_models.dart';

class PreviewState {
  const PreviewState({
    this.role = PreviewRole.student,
    this.classes = const [
      ClassRoom(
        id: 'it119',
        section: 'BSIT-3A',
        course: 'Introduction to Computing',
        instructor: 'Ms. Andrea Santos',
        color: 0xFF236B57,
      ),
      ClassRoom(
        id: 'ge104',
        section: 'BSIT-3A',
        course: 'Purposive Communication',
        instructor: 'Mr. Gabriel Reyes',
        color: 0xFF386D7A,
      ),
    ],
    this.posts = const [
      ClassPost(
        id: 'welcome',
        classId: 'it119',
        title: 'A fresh start.',
        message: 'Welcome to our class! This is our space to share ideas, ask questions, and learn together. Take a look at the learning guide before our next meeting.',
      ),
      ClassPost(
        id: 'guide',
        classId: 'it119',
        title: 'Your first learning guide',
        message: 'Start with the introduction to computing. Bring one question you would like us to explore in class.',
        attachments: ['Introduction to computing.pdf'],
      ),
      ClassPost(
        id: 'activity',
        classId: 'it119',
        title: 'Activity 1: Technology around us',
        message: 'Choose one technology you use every day. Explain how it works and how it helps your community.',
        assignment: true,
        points: 20,
        dueLabel: 'Due this Friday',
      ),
    ],
    this.assessments = const [],
  });
  final PreviewRole role;
  final List<ClassRoom> classes;
  final List<ClassPost> posts;
  final List<Assessment> assessments;

  PreviewState copyWith({
    PreviewRole? role,
    List<ClassRoom>? classes,
    List<ClassPost>? posts,
    List<Assessment>? assessments,
  }) => PreviewState(
    role: role ?? this.role,
    classes: classes ?? this.classes,
    posts: posts ?? this.posts,
    assessments: assessments ?? this.assessments,
  );
}

final previewProvider = NotifierProvider<PreviewController, PreviewState>(
  PreviewController.new,
);

class PreviewController extends Notifier<PreviewState> {
  @override
  PreviewState build() => const PreviewState();

  void chooseRole(PreviewRole role) => state = state.copyWith(role: role);

  String joinClass(String code) {
    if (code != 'FILO26') {
      return 'Class code not found. Try the preview code FILO26.';
    }
    if (state.classes.any((room) => room.id == 'joined')) {
      return 'Your request is still waiting for approval.';
    }
    state = state.copyWith(
      classes: [
        ...state.classes,
        const ClassRoom(
          id: 'joined',
          section: 'BSIT-3B',
          course: 'Data Structures',
          instructor: 'Ms. Sofia Cruz',
          color: 0xFF647C58,
          pending: true,
        ),
      ],
    );
    return 'Preview request sent. Waiting for approval.';
  }

  void addPost(ClassPost post) {
    if (state.role != PreviewRole.instructor) return;
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  void addAssessment(Assessment assessment) {
    if (state.role != PreviewRole.instructor) return;
    state = state.copyWith(assessments: [assessment, ...state.assessments]);
  }
}
