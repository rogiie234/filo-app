import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../assessments/application/instructor_quiz_providers.dart';
import '../../assessments/domain/quiz_helpers.dart';
import '../../assessments/presentation/assessment_form_screen.dart';
import '../../exams/application/exam_providers.dart';
import '../../exams/domain/student_quiz_status.dart';
import '../../exams/presentation/student_quiz_detail_screen.dart';
import '../domain/prototype_models.dart';

typedef StreamClass = ({String classId, bool student});

class StreamAssessment {
  StreamAssessment(Map<String, dynamic> row, {this.studentStatus})
    : id = row['id'] as String,
      classId = row['class_id'] as String,
      title = row['title'] as String,
      type = row['type'] == 'exam' ? 'Exam' : 'Quiz',
      status = row['status'] as String? ?? '',
      deleted = row['deleted_at'] != null,
      publishedAt = DateTime.tryParse('${row['published_at'] ?? ''}'),
      opensAt = DateTime.tryParse('${row['opens_at'] ?? ''}'),
      closesAt = DateTime.tryParse('${row['closes_at'] ?? ''}');
  final String id, classId, title, type, status;
  final bool deleted;
  final DateTime? publishedAt, opensAt, closesAt;
  final String? studentStatus;
  String displayStatus(DateTime now) =>
      studentStatus ??
      quizDisplayStatus(
        status: status,
        opensAt: opensAt,
        closesAt: closesAt,
        now: now,
      ).label;
}

class AssessmentStreamData {
  const AssessmentStreamData(
    this.items, {
    this.loaded = false,
    this.loading = false,
    this.failed = false,
  });
  final List<StreamAssessment> items;
  final bool loaded, loading, failed;
}

final assessmentStreamProvider = Provider.autoDispose
    .family<AssessmentStreamData, StreamClass>((ref, key) {
      final online = ref.watch(connectivityProvider).asData?.value == true;
      if (key.student) {
        final catalog = ref.watch(studentQuizCatalogProvider);
        final now =
            ref.watch(studentQuizNowProvider).asData?.value ??
            DateTime.now().toUtc();
        return AssessmentStreamData(
          [
            for (final quiz in catalog.value?.quizzes ?? [])
              if (quiz.classId == key.classId)
                StreamAssessment(
                  quiz.json,
                  studentStatus: studentQuizState(quiz, now).status.label,
                ),
          ],
          loaded: catalog.value?.loaded == true,
          loading: catalog.isLoading || catalog.value?.refreshing == true,
          failed: catalog.hasError || catalog.value?.failed == true,
        );
      }
      final cached = ref.watch(instructorQuizzesProvider(key.classId));
      final refresh = online
          ? ref.watch(instructorQuizListRefreshProvider(key.classId))
          : null;
      final rows = cached.value;
      final now = DateTime.now().toUtc();
      var delay = const Duration(minutes: 1);
      for (final quiz in rows ?? []) {
        for (final boundary in [quiz.opensAt, quiz.closesAt]) {
          if (boundary == null || !boundary.isAfter(now)) continue;
          final remaining =
              boundary.difference(now) + const Duration(milliseconds: 1);
          if (remaining < delay) delay = remaining;
        }
      }
      final timer = Timer(delay, ref.invalidateSelf);
      final lifecycle = AppLifecycleListener(
        onResume: () {
          ref.invalidate(instructorQuizListRefreshProvider(key.classId));
          ref.invalidateSelf();
        },
      );
      ref.onDispose(() {
        timer.cancel();
        lifecycle.dispose();
      });
      return AssessmentStreamData(
        [for (final quiz in rows ?? []) StreamAssessment(quiz.row)],
        loaded: rows != null,
        loading: cached.isLoading || refresh?.isLoading == true,
        failed: cached.hasError || refresh?.hasError == true,
      );
    });

class ClassStreamItem {
  const ClassStreamItem.post(this.post) : assessment = null;
  const ClassStreamItem.assessment(this.assessment) : post = null;
  final ClassPost? post;
  final StreamAssessment? assessment;
  String get id =>
      post == null ? 'assessment:${assessment!.id}' : 'post:${post!.id}';
  DateTime? get publishedAt => post?.createdAt ?? assessment?.publishedAt;
  String get category => post?.postType ?? 'assessment';
}

List<ClassStreamItem> classStreamItems(
  List<ClassPost> posts,
  List<StreamAssessment> assessments,
  String classId, {
  String? filter,
}) {
  final unique = <String, ClassStreamItem>{};
  for (final post in posts.where((p) => p.classId == classId)) {
    final item = ClassStreamItem.post(post);
    unique[item.id] = item;
  }
  for (final assessment in assessments.where(
    (q) => q.classId == classId && q.status == 'published' && !q.deleted,
  )) {
    final item = ClassStreamItem.assessment(assessment);
    unique[item.id] = item;
  }
  final items = unique.values
      .where((item) => filter == null || item.category == filter)
      .toList();
  items.sort((a, b) {
    final date = (b.publishedAt ?? DateTime(1970)).compareTo(
      a.publishedAt ?? DateTime(1970),
    );
    return date != 0 ? date : a.id.compareTo(b.id);
  });
  return items;
}

class StreamAssessmentCard extends StatelessWidget {
  const StreamAssessmentCard({
    super.key,
    required this.assessment,
    required this.student,
    this.archived = false,
  });
  final StreamAssessment assessment;
  final bool student, archived;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.all(FiloSpacing.screen),
      leading: const FiloIcon(FiloIcons.assessment),
      title: Text(assessment.title),
      subtitle: Text(
        '${assessment.type} / ${assessment.displayStatus(DateTime.now())}\nOpens ${philippineQuizDate(assessment.opensAt)}\nCloses ${philippineQuizDate(assessment.closesAt)} (Asia/Manila)',
      ),
      trailing: const FiloIcon(FiloIcons.chevronRight),
      onTap: () async {
        if (!student && !archived) {
          final accepted = await showFiloConfirmation(
            context,
            title: 'Edit this published assessment?',
            message: 'Students can already see this assessment. Your saved changes will affect it. Once a student starts, only the title and closing time can change.',
            confirmLabel: 'Continue editing',
            cancelLabel: 'Cancel',
            icon: FiloIcons.edit,
          );
          if (!accepted || !context.mounted) return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => student
                ? StudentQuizDetailScreen(
                    classId: assessment.classId,
                    quizId: assessment.id,
                  )
                : AssessmentFormScreen(
                    classId: assessment.classId,
                    quizId: assessment.id,
                    readOnly: archived,
                  ),
          ),
        );
      },
    ),
  );
}
