import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum DeletionStage { uncertain, pending, cleanup }

class DeletionRecord {
  const DeletionRecord(this.userId, this.sessionId, this.stage);
  final String userId, sessionId;
  final DeletionStage stage;
  DeletionRecord at(DeletionStage stage) =>
      DeletionRecord(userId, sessionId, stage);
}

class DeletionJournalStore {
  static const key = 'filo.account_deletions.v1';
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  Future<Map<String, DeletionRecord>> read() async {
    final text = await storage.read(key: key);
    if (text == null) return {};
    final json = jsonDecode(text) as Map<String, dynamic>;
    return json.map((id, value) {
      if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id))
        throw const FormatException('Invalid account journal');
      final row = value as Map<String, dynamic>;
      return MapEntry(
        id,
        DeletionRecord(
          id,
          row['session'] as String,
          DeletionStage.values.byName(row['stage'] as String),
        ),
      );
    });
  }

  Future<void> write(Map<String, DeletionRecord> records) => storage.write(
    key: key,
    value: jsonEncode({
      for (final record in records.values)
        record.userId: {
          'session': record.sessionId,
          'stage': record.stage.name,
        },
    }),
  );
}

final deletionJournalStoreProvider = Provider((ref) => DeletionJournalStore());
final deletionJournalProvider =
    AsyncNotifierProvider<DeletionJournal, Map<String, DeletionRecord>>(
      DeletionJournal.new,
    );

class DeletionJournal extends AsyncNotifier<Map<String, DeletionRecord>> {
  Future<void> _writes = Future.value();
  @override
  Future<Map<String, DeletionRecord>> build() =>
      ref.watch(deletionJournalStoreProvider).read();
  Future<void> put(String id, DeletionRecord? record) {
    final next = _writes.then((_) async {
      final current = await future;
      final updated = {...current};
      if (record == null) {
        updated.remove(id);
      } else {
        updated[id] = record;
      }
      await ref.read(deletionJournalStoreProvider).write(updated);
      state = AsyncData(updated);
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
