import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/domain/prototype_models.dart';
import '../data/post_attachment_repository.dart';
import '../data/post_repository.dart';

final postAttachmentRepositoryProvider =
    FutureProvider<PostAttachmentRepository?>((ref) async {
      final classes = await ref.watch(classRepositoryProvider.future);
      return classes == null
          ? null
          : PostAttachmentRepository(
              classes.database,
              ref.watch(supabaseClientProvider),
            );
    });

final postRepositoryProvider = FutureProvider<PostRepository?>((ref) async {
  final classes = await ref.watch(classRepositoryProvider.future);
  final attachments = await ref.watch(postAttachmentRepositoryProvider.future);
  if (classes == null || attachments == null) return null;
  return PostRepository(
    classes,
    ref.watch(supabaseClientProvider),
    attachments,
  );
});

final postsProvider = StreamProvider.autoDispose
    .family<List<CachePost>, String>((ref, classId) async* {
      final repository = await ref.watch(postRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchPosts(classId);
    });

final postAttachmentsProvider = StreamProvider.autoDispose
    .family<List<CachePostAttachment>, String>((ref, postId) async* {
      final repository = await ref.watch(
        postAttachmentRepositoryProvider.future,
      );
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchAttachments(postId);
    });

/// One SQLite join keeps post text and attachment names reactive together.
final streamPostsProvider = StreamProvider.autoDispose
    .family<List<ClassPost>, String>((ref, classId) async* {
      final repository = await ref.watch(postRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      final db = repository.database;
      final p = db.cachePosts;
      final a = db.cachePostAttachments;
      final query =
          db.select(p).join([
              leftOuterJoin(a, a.postId.equalsExp(p.id) & a.deletedAt.isNull()),
            ])
            ..where(p.classId.equals(classId) & p.deletedAt.isNull())
            ..orderBy([
              OrderingTerm.desc(p.createdAt),
              OrderingTerm.desc(p.id),
              OrderingTerm.asc(a.sortOrder),
              OrderingTerm.asc(a.id),
            ]);
      yield* query.watch().map((rows) {
        final posts = <String, CachePost>{};
        final names = <String, List<String>>{};
        for (final row in rows) {
          final post = row.readTable(p);
          posts[post.id] = post;
          final attachment = row.readTableOrNull(a);
          if (attachment != null) (names[post.id] ??= []).add(attachment.name);
        }
        return posts.values
            .map(
              (p) => ClassPost(
                id: p.id,
                classId: p.classId,
                title: p.title,
                message: p.body ?? '',
                kind: p.kind,
                createdAt: p.createdAt,
                dueAt: p.dueAt,
                assignment: p.kind == 'assignment',
                points: p.points,
                dueLabel: p.dueAt?.toLocal().toString(),
                attachments: names[p.id] ?? const [],
              ),
            )
            .toList();
      });
    });

final postSyncProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  classId,
) async {
  final online = ref.watch(connectivityProvider).asData?.value == true;
  if (!online) return;
  final repository = await ref.watch(postRepositoryProvider.future);
  if (ref.mounted) await repository?.sync(classId);
});

final postSyncLifecycleProvider = Provider.autoDispose.family<void, String>((
  ref,
  classId,
) {
  ref.listen(postSyncProvider(classId), (_, _) {});
  var foreground = true;
  void pull() => ref.invalidate(postSyncProvider(classId));
  final listener = AppLifecycleListener(
    onResume: () {
      foreground = true;
      pull();
    },
    onPause: () => foreground = false,
    onHide: () => foreground = false,
  );
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (foreground && !ref.read(postSyncProvider(classId)).isLoading) pull();
  });
  ref.onDispose(() {
    timer.cancel();
    listener.dispose();
  });
});
