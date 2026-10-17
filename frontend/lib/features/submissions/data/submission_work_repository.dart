import 'dart:io';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/local/app_database.dart';
import 'submission_repository.dart';

Map<String, dynamic> _json(Map<String, dynamic> row) => {
  for (final e in row.entries)
    e.key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m[1]!.toUpperCase(),
    ): (e.key.endsWith('_at') || e.key == 'unsubmit_until') && e.value != null
        ? DateTime.parse(e.value as String).millisecondsSinceEpoch
        : e.value,
};

/// Online draft writes. Confirmed rows are immediately persisted to the same
/// account database as the offline readers. Selected, unuploaded files belong
/// to the open screen; this repository does not promise a background queue.
class SubmissionWorkRepository {
  SubmissionWorkRepository(this.submissions);
  final SubmissionRepository submissions;
  SupabaseClient get client => submissions.client;
  AppDatabase get database => submissions.database;
  bool _busy = false;

  Future<T> _write<T>(Future<T> Function() action) async {
    if (!submissions.isOnline()) {
      throw StateError('Connect to the internet to change your work.');
    }
    if (_busy) {
      throw StateError('A change to your work is already in progress.');
    }
    _busy = true;
    var beganWrite = false;
    try {
      await submissions.reconcileBeforeWorkWrite();
      submissions.beginCacheWrite();
      beganWrite = true;
      return await action();
    } finally {
      if (beganWrite) {
        submissions.endCacheWrite();
      }
      _busy = false;
    }
  }

  Future<(CachePost, CacheSubmission, List<CacheSubmissionItem>)> _draft(
    String postId,
  ) async {
    // Live read prevents stale cached deadlines/settings/locks from enabling a
    // write. Server RLS and lifecycle triggers remain the final authority.
    final postRow = await client
        .from('posts')
        .select()
        .eq('id', postId)
        .isFilter('deleted_at', null)
        .single()
        .timeout(const Duration(seconds: 20));
    final post = CachePost.fromJson(_json(postRow));
    if (post.kind != 'assignment') {
      throw StateError('Assignment not found.');
    }
    if (post.dueAt != null &&
        DateTime.now().isAfter(post.dueAt!) &&
        !post.acceptLate) {
      throw StateError('Submissions are closed for this assignment.');
    }
    await database
        .into(database.cachePosts)
        .insertOnConflictUpdate(post.toCompanion(false));
    final submission = await submissions.startSubmission(postId);
    if (submission.status != 'draft') {
      throw StateError('This submission is locked.');
    }
    final returned = await client
        .from('submission_grades')
        .select('returned_at')
        .eq('submission_id', submission.id)
        .not('returned_at', 'is', null)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (returned != null) {
      throw StateError('Your grade has been returned. This work is locked.');
    }
    final rows = await client
        .from('submission_items')
        .select()
        .eq('submission_id', submission.id)
        .isFilter('deleted_at', null)
        .order('sort_order')
        .order('id')
        .timeout(const Duration(seconds: 20));
    final items = <CacheSubmissionItem>[];
    for (final row in rows) {
      items.add(await _cacheItem(row));
    }
    // Reconcile removals too, so an uncertain deletion cannot remain visible.
    final ids = items.map((i) => i.id).toSet();
    await (database.delete(database.cacheSubmissionItems)..where(
          (i) => i.submissionId.equals(submission.id) & i.id.isNotIn(ids),
        ))
        .go();
    return (post, submission, items);
  }

  Future<CacheSubmissionItem> _cacheItem(Map<String, dynamic> row) async {
    final item = CacheSubmissionItem.fromJson(_json(row));
    if (item.deletedAt != null) {
      await (database.delete(
        database.cacheSubmissionItems,
      )..where((i) => i.id.equals(item.id))).go();
    } else {
      await database
          .into(database.cacheSubmissionItems)
          .insertOnConflictUpdate(item.toCompanion(false));
    }
    return item;
  }

  Future<CacheSubmissionItem> _insert(Map<String, dynamic> values) async =>
      _cacheItem(
        await client
            .from('submission_items')
            .insert(values)
            .select()
            .single()
            .timeout(const Duration(seconds: 20)),
      );

  Future<CacheSubmissionItem> addLink(
    String postId, {
    required String url,
    String? name,
  }) => _write(() async {
    final value = url.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw StateError('Enter a valid http or https link.');
    }
    if (name != null && name.length > 255) {
      throw StateError('Link name must be 255 characters or fewer.');
    }
    final (_, submission, items) = await _draft(postId);
    // The same URL is one piece of work. Reconcile a lost insert response
    // before retrying, rather than inserting a duplicate link.
    for (final item in items) {
      if (item.kind == 'link' && item.url == value) {
        return item;
      }
    }
    if (items.where((i) => i.kind == 'link').length >= 5) {
      throw StateError(
        'You can add up to 5 links. Remove a link before adding another.',
      );
    }
    return _insert({
      'submission_id': submission.id,
      'kind': 'link',
      'url': value,
      'name': name?.trim(),
      'sort_order': items.length,
    });
  });

  Future<CacheSubmissionItem> saveText(
    String postId,
    String text, {
    String? itemId,
  }) => _write(() async {
    if (text.trim().isEmpty) {
      throw StateError('Enter your text before saving.');
    }
    if (text.length > 10000) {
      throw StateError('Text must be 10,000 characters or fewer.');
    }
    final (_, submission, items) = await _draft(postId);
    final existing = items.where((i) => i.kind == 'text').firstOrNull;
    if (itemId != null && existing?.id != itemId) {
      throw StateError('Text entry is no longer available. Refresh your work.');
    }
    if (existing != null) {
      if (itemId == null) {
        if (existing.textContent == text) {
          return existing;
        }
        throw StateError(
          'Only one text entry is allowed. Edit your existing text entry instead.',
        );
      }
      return _cacheItem(
        await client
            .from('submission_items')
            .update({'text_content': text})
            .eq('id', existing.id)
            .eq('submission_id', submission.id)
            .isFilter('deleted_at', null)
            .select()
            .single()
            .timeout(const Duration(seconds: 20)),
      );
    }
    return _insert({
      'submission_id': submission.id,
      'kind': 'text',
      'text_content': text,
      'sort_order': items.length,
    });
  });

  Future<CacheSubmissionItem> uploadFile(
    String postId, {
    required String localPath,
    required String name,
    String? mimeType,
    required String uploadId,
    void Function(double?)? onProgress,
  }) => _write(() async {
    final safeName = name
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (safeName.isEmpty ||
        name.length > 255 ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(uploadId)) {
      throw StateError('This file name is not supported.');
    }
    final extension = safeName.split('.').last.toLowerCase();
    if ([
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'm4v',
          '3gp',
          'wmv',
        ].contains(extension) ||
        (mimeType?.toLowerCase().startsWith('video/') ?? false)) {
      throw StateError("Videos can't be uploaded. Add a link instead.");
    }
    final file = File(localPath);
    final size = await file.length();
    if (size > 26214400) {
      throw StateError('This file is too large. The limit is 25 MB.');
    }
    final (post, submission, items) = await _draft(postId);
    final path =
        '${post.classId}/${post.id}/${submissions.userId}/$uploadId-$safeName';
    for (final item in items) {
      if (item.storagePath == path) {
        onProgress?.call(1);
        return item;
      }
    }
    if (!post.allowFiles) {
      throw StateError(
        'File uploads are turned off for this assignment. Add a link or text instead.',
      );
    }
    final cap = post.maxFiles.clamp(1, 5);
    if (items.where((i) => i.kind == 'file').length >= cap) {
      throw StateError(
        cap == 1
            ? 'You can add only 1 file to this assignment. Remove it before adding another.'
            : 'You can add up to $cap files to this assignment. Remove a file before adding another.',
      );
    }
    onProgress?.call(null);
    // The SDK has no byte progress callback. Use an indeterminate indicator;
    // upload streams the native File and does not read all selected files.
    await client.storage
        .from('submissions')
        .upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
          retryAttempts: 0,
        )
        .timeout(const Duration(minutes: 2));
    try {
      final item = await _insert({
        'submission_id': submission.id,
        'kind': 'file',
        'name': name,
        'storage_path': path,
        'mime_type': mimeType,
        'size_bytes': size,
        'sort_order': items.length,
      });
      onProgress?.call(1);
      return item;
    } catch (error, stack) {
      // Metadata insertion may have succeeded despite a lost response. Never
      // delete a confirmed work file before resolving this uncertainty.
      try {
        final existing = await client
            .from('submission_items')
            .select()
            .eq('submission_id', submission.id)
            .eq('storage_path', path)
            .isFilter('deleted_at', null)
            .maybeSingle()
            .timeout(const Duration(seconds: 20));
        if (existing != null) {
          onProgress?.call(1);
          return await _cacheItem(existing);
        }
        await client.storage
            .from('submissions')
            .remove([path])
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Keep the stable upload ID: Retry first reads metadata and reuses the
        // same object, avoiding a second object after an uncertain response.
        throw StateError(
          'The upload could not be reconciled or cleaned up. Reconnect, then Retry or Delete this file.',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<(Map<String, dynamic>, String)> _ownedItem(String itemId) async {
    final row = await client
        .from('submission_items')
        .select('*,submissions!inner(student_id,post_id)')
        .eq('id', itemId)
        .eq('submissions.student_id', submissions.userId)
        .isFilter('deleted_at', null)
        .single()
        .timeout(const Duration(seconds: 20));
    final parent = row.remove('submissions') as Map<String, dynamic>;
    return (row, parent['post_id'] as String);
  }

  Future<void> removeItem(String itemId) => _write(() async {
    final (row, postId) = await _ownedItem(itemId);
    await _draft(postId);
    if (row['kind'] == 'file') {
      await client.storage
          .from('submissions')
          .remove([row['storage_path'] as String])
          .timeout(const Duration(seconds: 20));
    }
    await _cacheItem(
      await client
          .from('submission_items')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', itemId)
          .select()
          .single()
          .timeout(const Duration(seconds: 20)),
    );
  });

  /// Remove a failed upload using the same stable object identity as Retry.
  /// If metadata committed, remove that item too; otherwise delete the orphan.
  Future<void> discardUpload(
    String postId,
    String uploadId,
    String name,
  ) => _write(() async {
    final (post, submission, items) = await _draft(postId);
    final safeName = name
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(uploadId)) {
      throw StateError('Invalid upload identifier.');
    }
    final path =
        '${post.classId}/${post.id}/${submissions.userId}/$uploadId-$safeName';
    await client.storage
        .from('submissions')
        .remove([path])
        .timeout(const Duration(seconds: 20));
    final matching = items.where(
      (i) => i.submissionId == submission.id && i.storagePath == path,
    );
    for (final item in matching) {
      await _cacheItem(
        await client
            .from('submission_items')
            .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', item.id)
            .select()
            .single()
            .timeout(const Duration(seconds: 20)),
      );
    }
  });

  Future<CacheSubmission> saveComment(String postId, String comment) => _write(
    () async {
      if (comment.length > 1000) {
        throw StateError('Private comment must be 1,000 characters or fewer.');
      }
      final (_, submission, _) = await _draft(postId);
      final row = await client
          .from('submissions')
          .update({'private_comment': comment})
          .eq('id', submission.id)
          .eq('student_id', submissions.userId)
          .eq('status', 'draft')
          .select()
          .single()
          .timeout(const Duration(seconds: 20));
      final saved = CacheSubmission.fromJson(_json(row));
      await database
          .into(database.cacheSubmissions)
          .insertOnConflictUpdate(saved.toCompanion(false));
      return saved;
    },
  );

  Future<String> signedFileLink(String itemId) async {
    if (!submissions.isOnline()) {
      throw StateError('Connect to the internet to open this file.');
    }
    final (row, _) = await _ownedItem(itemId);
    if (row['kind'] != 'file' || row['storage_path'] == null) {
      throw StateError('File is no longer available.');
    }
    return client.storage
        .from('submissions')
        .createSignedUrl(row['storage_path'] as String, 300)
        .timeout(const Duration(seconds: 20));
  }
}
