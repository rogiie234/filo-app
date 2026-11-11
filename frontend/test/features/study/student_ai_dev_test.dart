import 'dart:io';

import 'package:filo/core/ai/ai_cancellation.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner-only real DEV transport; credentials stay in process environment.
void main() {
  final enabled = Platform.environment['FILO_STUDY_DEV_TEST'] == '1';
  test(
    'owner DEV switch maps through all applicable student client methods',
    () async {
      const devUrl = 'https://fiobwfzmqcffbpixzvbq.supabase.co';
      final key = Platform.environment['FILO_STUDY_DEV_KEY'];
      final token = Platform.environment['FILO_STUDY_DEV_TOKEN'];
      final mode = Platform.environment['FILO_STUDY_EXPECTED_MODE'];
      const modes = {
        'sample',
        'NOT_ALLOWED',
        'INVALID_REQUEST',
        'NO_TEXT',
        'TOO_LARGE',
        'AI_IN_PROGRESS',
        'AI_BUSY',
        'AI_TIMEOUT',
        'AI_BAD_OUTPUT',
        'AI_UNAVAILABLE',
        'AI_BLOCKED',
        'unexpected',
      };
      if (key == null ||
          key.isEmpty ||
          token == null ||
          token.isEmpty ||
          !modes.contains(mode)) {
        fail(
          'Set the owner DEV key, verified student token and expected simulation mode in the process environment.',
        );
      }
      final supabase = SupabaseClient(devUrl, key);
      addTearDown(supabase.dispose);
      final guard = AiRequestGuard();
      addTearDown(guard.close);
      final client = StudentAiClient(
        guard: guard,
        isOnline: () => true,
        currentAccount: () => 'owner-dev-session',
        loadSources: (_) async => [
          StudyAiSource(
            key: 'att:synthetic',
            name: 'synthetic.txt',
            text: 'A' * 40001,
          ),
        ],
        invoke: (function, body, abort) async =>
            (await supabase.functions.invoke(
              function,
              body: body,
              abortSignal: abort,
              headers: {'Authorization': 'Bearer $token'},
            )).data,
      );
      for (final action in ['chat', 'summary', 'flashcards', 'practice_quiz']) {
        if (mode == 'AI_BAD_OUTPUT' &&
            (action == 'chat' || action == 'summary')) {
          continue;
        }
        final cancel = AiCancelToken();
        final Future<StudyAiResult<dynamic>> request = switch (action) {
          'chat' => client.chat(
            notebookId: 'synthetic',
            messages: const [
              StudyChatInput(role: 'user', content: 'Explain the text'),
            ],
            cancel: cancel,
          ),
          'summary' => client.summary(notebookId: 'synthetic', cancel: cancel),
          'flashcards' => client.flashcards(
            notebookId: 'synthetic',
            settings: const StudyDeckSettings(count: 5),
            cancel: cancel,
          ),
          _ => client.practiceQuiz(
            notebookId: 'synthetic',
            settings: const StudyQuizSettings(
              count: 5,
              types: ['multiple_choice', 'true_false', 'identification'],
            ),
            cancel: cancel,
          ),
        };
        if (mode == 'sample') {
          expect((await request).truncated, isTrue, reason: action);
        } else {
          await expectLater(
            request,
            throwsA(
              isA<StudyAiFailure>()
                  .having(
                    (e) => e.code,
                    'code',
                    mode == 'unexpected' ? 'AI_UNAVAILABLE' : mode,
                  )
                  .having((e) => e.sources?.truncated, 'source was cut', true),
            ),
            reason: action,
          );
        }
        expect(guard.isBusy, isFalse);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: enabled
        ? false
        : 'Owner opt-in only; see canonical M11 FE-02 acceptance setup',
  );
}
