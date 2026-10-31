import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/database_providers.dart';
import '../data/student_ai_client.dart';
import '../domain/study_ai.dart';

final studentAiClientProvider = Provider<StudentAiClient>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final client = StudentAiClient(
    invoke: (function, body, abort) async => (await supabase.functions.invoke(
      function,
      body: body,
      abortSignal: abort,
    )).data,
    loadSources: (notebookId) async {
      final db = await ref.read(accountDatabaseProvider.future);
      if (db == null || !ref.mounted) throw const StudyAiFailure('NOT_ALLOWED');
      return db.transaction(() async {
        final notebook = await (db.select(
          db.notebooks,
        )..where((n) => n.id.equals(notebookId))).getSingleOrNull();
        if (notebook == null) throw const StudyAiFailure('LOAD_FAILED');
        final sources =
            await (db.select(db.notebookSources)
                  ..where((s) => s.notebookId.equals(notebookId))
                  ..orderBy([
                    (s) => OrderingTerm.asc(s.createdAt),
                    (s) => OrderingTerm.asc(s.id),
                  ]))
                .get();
        return sources
            .map(
              (s) => StudyAiSource(
                key: s.sourceKey,
                name: s.name,
                text: s.extractedText,
              ),
            )
            .toList();
      });
    },
    isOnline: () => ref.read(connectivityProvider).asData?.value == true,
    currentAccount: () => aiSessionIdentity(supabase.auth.currentSession),
    sessionExpired: () {
      final expires = supabase.auth.currentSession?.expiresAt;
      return expires != null &&
          DateTime.now().millisecondsSinceEpoch >= expires * 1000;
    },
    guard: ref.watch(aiRequestGuardProvider),
  );
  var identity = aiSessionIdentity(supabase.auth.currentSession);
  ref.listen(loginSessionProvider, (_, next) {
    if (!next.hasValue) return;
    final updated = aiSessionIdentity(next.value);
    if (updated != identity) client.cancelActive();
    identity = updated;
  });
  ref.onDispose(client.cancelActive);
  return client;
});
