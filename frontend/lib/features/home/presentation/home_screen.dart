import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exams/application/exam_providers.dart';
import '../../exams/presentation/student_exam_screen.dart';

import '../../classes/presentation/classes_screen.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../../core/notifications/push_events.dart';
import '../../settings/application/theme_settings.dart';
import '../../settings/application/profile_settings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.profile, super.key});
  final AccountProfile profile;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _announced = false;

  bool _scheduled = false;
  void _resumeExam() {
    if (_scheduled || ref.read(examNavigationProvider).open) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || ref.read(examNavigationProvider).open) return;
      final r = ref.read(studentExamRepositoryProvider).value;
      if (r == null) return;
      if (!r.engaged) {
        if (r.completion != null) {
          unawaited(
            r.protectScreen?.call(false).catchError((Object _) {}) ??
                Future<void>.value(),
          );
        }
        return;
      }
      final quiz = r.active?.quizId ?? r.pendingQuizId;
      if (quiz == null) return;
      openStudentExam(
        context,
        ref,
        StudentExamHandoff(
          quizId: quiz,
          sessionId: r.active?.sessionId ?? r.pendingSessionId,
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        ref.watch(accountProfileProvider(widget.profile.id)) ?? widget.profile;
    final appearance = ref.watch(themeSettingsProvider);
    if (appearance.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (appearance.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your theme setting.'),
                TextButton(
                  onPressed: () {
                    ref.invalidate(themeSettingsRepositoryProvider);
                    ref.invalidate(themeSettingsProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) NotificationHomeReady(profile).dispatch(context);
      });
    }
    if (profile.role == AccountRole.student) {
      ref.watch(examLifecycleProvider);
      ref.listen(examUpdatesProvider, (_, _) => _resumeExam());
      ref.watch(studentExamRepositoryProvider);
      _resumeExam();
    }
    return PopScope(canPop: false, child: ClassesScreen(profile: profile));
  }
}
