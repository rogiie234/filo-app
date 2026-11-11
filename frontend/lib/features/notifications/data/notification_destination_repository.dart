import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../../../core/notifications/push_events.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/cache_row_json.dart';

class NotificationUnavailable implements Exception {
  const NotificationUnavailable();
}

class NotificationNeedsConnection implements Exception {
  const NotificationNeedsConnection();
}

enum NotificationScreen {
  post,
  assignment,
  quiz,
  result,
  classroom,
  requests,
  study,
  deck,
}

class NotificationDestination {
  const NotificationDestination(
    this.screen,
    this.classId,
    this.targetId, {
    this.notebookId,
  });
  final NotificationScreen screen;
  final String classId, targetId;
  final String? notebookId;
}

NotificationDestination notificationDestination(
  CacheNotification notice,
  Map<String, dynamic> item, {
  required bool instructor,
}) {
  final id = notice.targetId;
  final classId = notice.targetType == 'post' || notice.targetType == 'quiz'
      ? item['class_id']
      : item['id'];
  if (!PushEvents.validId(id) ||
      !PushEvents.validId(classId) ||
      item['id'] != id ||
      item['deleted_at'] != null ||
      notice.classId != null && notice.classId != classId) {
    throw const NotificationUnavailable();
  }
  final NotificationScreen screen;
  switch (notice.targetType) {
    case 'post':
      screen = switch (item['kind']) {
        'assignment' => NotificationScreen.assignment,
        'announcement' || 'material' => NotificationScreen.post,
        _ => throw const NotificationUnavailable(),
      };
      if (notice.type == 'grade_returned' &&
          screen != NotificationScreen.assignment) {
        throw const NotificationUnavailable();
      }
    case 'quiz':
      if (instructor) throw const NotificationUnavailable();
      screen = switch (notice.type) {
        'results_released' => NotificationScreen.result,
        'quiz_published' || 'second_chance' => NotificationScreen.quiz,
        _ => throw const NotificationUnavailable(),
      };
    case 'class':
      screen = NotificationScreen.classroom;
    case 'class_members':
      if (!instructor || notice.type != 'join_request') {
        throw const NotificationUnavailable();
      }
      screen = NotificationScreen.requests;
    default:
      throw const NotificationUnavailable();
  }
  return NotificationDestination(screen, classId as String, id!);
}

class NotificationDestinationRepository {
  NotificationDestinationRepository({
    required this.db,
    required this.client,
    required this.sync,
    required this.userId,
    required this.online,
    required this.isCurrent,
  });
  final AppDatabase db;
  final SupabaseClient client;
  final SyncCoordinator sync;
  final String userId;
  final bool Function() online, isCurrent;

  void checkAccount() {
    if (!isCurrent()) throw StateError('Account changed');
  }

  Future<CacheNotification> notice(String? id) async {
    checkAccount();
    if (!PushEvents.validId(id)) throw const NotificationUnavailable();
    final row = online()
        ? await sync.refreshNotification(id!)
        : await (db.select(db.cacheNotifications)
                ..where((n) => n.id.equals(id!) & n.recipientId.equals(userId)))
              .getSingleOrNull();
    checkAccount();
    if (row == null) {
      if (!online()) throw const NotificationNeedsConnection();
      throw const NotificationUnavailable();
    }
    // The cache FK may be null when a class has not been cached yet.
    if (row.classId == null) {
      final payloads = await db
          .customSelect(
            "SELECT payload FROM sync_payloads WHERE table_name='notifications' AND id=?",
            variables: [Variable(row.id)],
          )
          .get();
      checkAccount();
      if (payloads.isNotEmpty) {
        final payload = jsonDecode(
          payloads.single.read<String>('payload'),
        ) as Map<String, dynamic>;
        if (payload['class_id'] is String) {
          return row.copyWith(classId: Value(payload['class_id'] as String));
        }
      }
    }
    return row;
  }

  Future<Map<String, dynamic>> _item(String table, String id) async {
    checkAccount();
    Map<String, dynamic>? row;
    if (online()) {
      row = await client
          .from(table)
          .select()
          .eq('id', id)
          .isFilter('deleted_at', null)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
    } else {
      const local = {
        'posts': 'cache_posts',
        'quizzes': 'cache_quizzes',
        'classes': 'cache_classes',
      };
      final rows = await db
          .customSelect(
            'SELECT * FROM ${local[table]} WHERE id=?',
            variables: [Variable(id)],
          )
          .get();
      if (rows.isNotEmpty) row = rows.single.data;
    }
    checkAccount();
    if (row == null) {
      if (!online()) throw const NotificationNeedsConnection();
      throw const NotificationUnavailable();
    }
    if (row['deleted_at'] != null) throw const NotificationUnavailable();
    return row;
  }

  // Reuse authorized rows; collection sync belongs to the destination screen.
  Future<void> _prepare(
    Map<String, dynamic> room, {
    Map<String, dynamic>? member,
    Map<String, dynamic>? post,
  }) async {
    checkAccount();
    final profileIds = <String>{
      room['owner_id'] as String,
      if (member != null) member['student_id'] as String,
      if (member?['decided_by'] != null) member!['decided_by'] as String,
      if (post != null) post['author_id'] as String,
    };
    final missing = <String>[];
    for (final id in profileIds) {
      if (await db.readProfile(id) == null) missing.add(id);
    }
    final profiles = missing.isEmpty
        ? <Map<String, dynamic>>[]
        : await client
              .from('profiles')
              .select()
              .inFilter('id', missing)
              .timeout(const Duration(seconds: 20));
    checkAccount();
    final attachments = post == null
        ? <Map<String, dynamic>>[]
        : await client
              .from('post_attachments')
              .select()
              .eq('post_id', post['id'] as String)
              .isFilter('deleted_at', null)
              .order('id')
              .timeout(const Duration(seconds: 20));
    checkAccount();
    await db.transaction(() async {
      checkAccount();
      for (final profile in profiles) {
        await db
            .into(db.cacheProfiles)
            .insertOnConflictUpdate(
              CacheProfile.fromJson(cacheRowJson(profile)).toCompanion(false),
            );
      }
      await db
          .into(db.cacheClasses)
          .insertOnConflictUpdate(
            CacheClassesData.fromJson(cacheRowJson(room)).toCompanion(false),
          );
      if (member != null) {
        await db
            .into(db.cacheClassMembers)
            .insertOnConflictUpdate(
              CacheClassMember.fromJson(cacheRowJson(member))
                  .toCompanion(false),
            );
      }
      if (post != null) {
        await db
            .into(db.cachePosts)
            .insertOnConflictUpdate(
              CachePost.fromJson(cacheRowJson(post)).toCompanion(false),
            );
        await (db.delete(
          db.cachePostAttachments,
        )..where((a) => a.postId.equals(post['id'] as String))).go();
        for (final attachment in attachments) {
          await db
              .into(db.cachePostAttachments)
              .insertOnConflictUpdate(
                CachePostAttachment.fromJson(cacheRowJson(attachment))
                    .toCompanion(false),
              );
        }
      }
      checkAccount();
    });
  }

  Future<NotificationDestination> resolve(
    String? id, {
    required bool instructor,
  }) => _resolve(notice(id), null, instructor);

  Future<NotificationDestination> resolveAssignment(String postId) =>
      _resolve(Future.value(null), postId, false);

  Future<NotificationDestination> resolveStudyAlarm(String id) async {
    checkAccount();
    final profile = await db.readProfile(userId);
    final alarm = await (db.select(
      db.studyAlarms,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    checkAccount();
    if (profile?.role != 'student' ||
        profile?.deletedAt != null ||
        alarm == null) {
      throw const NotificationUnavailable();
    }
    if (alarm.linkedDeckId != null) {
      final deck = await (db.select(
        db.flashcardDecks,
      )..where((d) => d.id.equals(alarm.linkedDeckId!))).getSingleOrNull();
      checkAccount();
      if (deck == null) throw const NotificationUnavailable();
      return NotificationDestination(
        NotificationScreen.deck,
        '',
        deck.id,
        notebookId: deck.notebookId,
      );
    }
    if (alarm.linkedClassId != null) {
      try {
        final room = await _item('classes', alarm.linkedClassId!);
        final List members;
        Map<String, dynamic>? membership;
        if (online()) {
          members = await client
              .from('class_members')
              .select()
              .eq('class_id', alarm.linkedClassId!)
              .eq('student_id', userId)
              .eq('status', 'active')
              .isFilter('deleted_at', null)
              .limit(1)
              .timeout(const Duration(seconds: 20));
          if (members.isNotEmpty)
            membership = Map<String, dynamic>.from(members.single as Map);
        } else {
          final member =
              await (db.select(db.cacheClassMembers)..where(
                    (m) =>
                        m.classId.equals(alarm.linkedClassId!) &
                        m.studentId.equals(userId),
                  ))
                  .getSingleOrNull();
          if (member != null && member.status != 'active') {
            throw const NotificationUnavailable();
          }
          members = member == null ? [] : [member];
        }
        checkAccount();
        if (members.isEmpty) {
          if (!online()) throw const NotificationNeedsConnection();
          throw const NotificationUnavailable();
        }
        final destination = NotificationDestination(
          NotificationScreen.classroom,
          room['id'] as String,
          room['id'] as String,
        );
        if (online()) await _prepare(room, member: membership);
        checkAccount();
        return destination;
      } on PostgrestException catch (e) {
        if (e.code == '42501') throw const NotificationUnavailable();
        rethrow;
      }
    }
    return const NotificationDestination(NotificationScreen.study, '', '');
  }

  Future<NotificationDestination> _resolve(
    Future<CacheNotification?> notification,
    String? assignmentId,
    bool instructor,
  ) async {
    try {
      final n = await notification;
      final targetId = assignmentId ?? n?.targetId;
      if (!PushEvents.validId(targetId)) throw const NotificationUnavailable();
      final table = assignmentId != null
          ? 'posts'
          : switch (n!.targetType) {
              'post' => 'posts',
              'quiz' => 'quizzes',
              'class' || 'class_members' => 'classes',
              _ => throw const NotificationUnavailable(),
            };
      final item = await _item(table, targetId!);
      if (assignmentId != null &&
          (item['kind'] != 'assignment' ||
              !PushEvents.validId(item['class_id']) ||
              item['id'] != assignmentId ||
              item['deleted_at'] != null)) {
        throw const NotificationUnavailable();
      }
      final destination = assignmentId != null
          ? NotificationDestination(
              NotificationScreen.assignment,
              item['class_id'] as String,
              assignmentId,
            )
          : notificationDestination(n!, item, instructor: instructor);
      final room = table == 'classes'
          ? item
          : await _item('classes', destination.classId);
      final ownsClass = room['owner_id'] == userId;
      Map<String, dynamic>? membership;
      if (instructor && !ownsClass) throw const NotificationUnavailable();
      if (!ownsClass) {
        final List<dynamic> members;
        if (online()) {
          members = await client
              .from('class_members')
              .select()
              .eq('class_id', destination.classId)
              .eq('student_id', userId)
              .eq('status', 'active')
              .isFilter('deleted_at', null)
              .limit(1)
              .timeout(const Duration(seconds: 20));
          if (members.isNotEmpty)
            membership = Map<String, dynamic>.from(members.single as Map);
        } else {
          members =
              await (db.select(db.cacheClassMembers)..where(
                    (m) =>
                        m.classId.equals(destination.classId) &
                        m.studentId.equals(userId) &
                        m.status.equals('active'),
                  ))
                  .get();
        }
        checkAccount();
        if (members.isEmpty) {
          if (!online()) throw const NotificationNeedsConnection();
          throw const NotificationUnavailable();
        }
      }
      if (online())
        await _prepare(
          room,
          member: membership,
          post: table == 'posts' ? item : null,
        );
      checkAccount();
      return destination;
    } on PostgrestException catch (error) {
      if (error.code == '42501') throw const NotificationUnavailable();
      rethrow;
    }
  }
}
