import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/local/app_database.dart';
import '../../classes/data/class_remote.dart';

import 'package:drift/drift.dart';

/// Signed links are requested on demand and never persisted in SQLite.
class PostAttachmentRepository {
  PostAttachmentRepository(this.database, this.client);
  final AppDatabase database;
  final SupabaseClient client;

  Stream<List<CachePostAttachment>> watchAttachments(String postId) =>
      (database.select(database.cachePostAttachments)
            ..where((a) => a.postId.equals(postId) & a.deletedAt.isNull())
            ..orderBy([
              (a) => OrderingTerm.asc(a.sortOrder),
              (a) => OrderingTerm.asc(a.id),
            ]))
          .watch();

  Future<String> signedFileLink(String attachmentId) async {
    // Re-read metadata under RLS rather than trusting a stale cached path.
    final row = await client
        .from('post_attachments')
        .select()
        .eq('id', attachmentId)
        .isFilter('deleted_at', null)
        .single();
    if (row['kind'] != 'file' || row['storage_path'] == null) {
      throw StateError('Attachment is not an available file');
    }
    return client.storage
        .from('materials')
        .createSignedUrl(row['storage_path'] as String, 300);
  }

  Future<List<ClassRow>> readChanges(String classId, DateTime? since) async {
    final rows = <ClassRow>[];
    String? after;
    while (true) {
      var query = client
          .from('post_attachments')
          .select('*,posts!inner(class_id)')
          .eq('posts.class_id', classId);
      if (since != null) {
        query = query.gte('updated_at', since.toUtc().toIso8601String());
      }
      if (after != null) query = query.gt('id', after);
      final page = await query
          .order('id', ascending: true)
          .limit(500)
          .timeout(const Duration(seconds: 20));
      rows.addAll(
        page.map((r) => Map<String, dynamic>.from(r)..remove('posts')),
      );
      if (page.isEmpty) return rows;
      after = page.last['id'] as String;
    }
  }
}
