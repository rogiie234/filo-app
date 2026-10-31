import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/database_providers.dart';
import '../data/ai_quiz_client.dart';
import '../data/file_text_cache.dart';
import '../data/lesson_text_extractor.dart';

final fileTextCacheProvider = FutureProvider<FileTextCache?>((ref) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null ? null : FileTextCache(db);
});
final lessonExtractorProvider = FutureProvider<LessonTextExtractor>(
  (ref) async =>
      LessonTextExtractor(cache: await ref.watch(fileTextCacheProvider.future)),
);
final aiQuizClientProvider = Provider<AiQuizClient>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final ai = AiQuizClient(
    invoke: (body) async =>
        (await client.functions.invoke('ai-generate-quiz', body: body)).data,
    invokeCancellable: (body, abort) async => (await client.functions.invoke(
      'ai-generate-quiz',
      body: body,
      abortSignal: abort,
    )).data,
    isOnline: () => ref.read(connectivityProvider).asData?.value == true,
    currentUser: () => client.auth.currentUser?.id,
    guard: ref.watch(aiRequestGuardProvider),
  );
  var identity = aiSessionIdentity(client.auth.currentSession);
  ref.listen(loginSessionProvider, (_, next) {
    if (!next.hasValue) return;
    final updated = aiSessionIdentity(next.value);
    if (updated != identity) ai.cancelActive();
    identity = updated;
  });
  ref.onDispose(ai.cancelActive);
  return ai;
});
