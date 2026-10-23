import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exams/application/exam_providers.dart';

import '../../classes/presentation/classes_screen.dart';
import '../../onboarding/data/profile_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.profile, super.key});
  final AccountProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile.role == AccountRole.student) ref.watch(examLifecycleProvider);
    return PopScope(canPop: false, child: ClassesScreen(profile: profile));
  }
}
