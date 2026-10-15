import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessments/presentation/new_assessment_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/session_screen.dart';
import '../../features/classes/presentation/classes_screen.dart';
import '../../features/classes/presentation/class_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/posts/presentation/create_post_screen.dart';
import '../widgets/filo_widgets.dart';
import '../supabase/session_gate.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const IntroScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      // Both entries pass through session verification and profile lookup.
      // App keeps the account Navigator mounted while the URL changes.
      for (final path in ['/onboarding', '/home'])
        GoRoute(
          path: path,
          builder: (context, state) =>
              ref.read(loginSessionProvider).asData?.value == null
              ? const SignInScreen()
              : const SessionScreen(),
        ),
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesScreen(),
        routes: [
          GoRoute(
            path: ':classId',
            builder: (context, state) =>
                ClassScreen(classId: state.pathParameters['classId']!),
            routes: [
              GoRoute(
                path: 'post/new',
                builder: (context, state) =>
                    CreatePostScreen(classId: state.pathParameters['classId']!),
              ),
              GoRoute(
                path: 'assessment/new',
                builder: (context, state) => NewAssessmentScreen(
                  classId: state.pathParameters['classId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: FiloButton(
            label: 'Back to classes',
            onPressed: () => context.go('/classes'),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
