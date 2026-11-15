import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/data/class_remote.dart';
import 'package:filo/features/classes/data/class_repository.dart';
import 'package:filo/features/posts/data/post_attachment_repository.dart';
import 'package:filo/features/posts/data/post_repository.dart';
import 'package:filo/features/submissions/data/submission_repository.dart';
import 'package:filo/features/submissions/data/submission_work_repository.dart';

class _Posts extends PostRepository {
  _Posts(AppDatabase db, SupabaseClient client)
    : super(
        ClassRepository(db, SupabaseClassRemote(client), 'student'),
        client,
        PostAttachmentRepository(db, client),
      );
  final refreshed = <String>[];
  @override
  Future<void> sync(String classId) async {
    refreshed.add(classId);
  }
}

void main() {
  for (final failMetadata in [true, false]) {
    test(
      'removal intent survives ${failMetadata ? 'metadata' : 'Storage'} failure and repository reopen',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        var fail = true;
        final calls = <String>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(
              await db
                  .customSelect(
                    "SELECT key FROM file_settings WHERE key='submission_removal:item'",
                  )
                  .get(),
              hasLength(1),
            );
            final storage = request.url.path.contains('/storage/');
            calls.add(storage ? 'bytes' : 'metadata');
            final failed = fail && (storage != failMetadata);
            return http.Response(
              jsonEncode(
                failed
                    ? {'message': 'Temporary failure', 'code': 'XX000'}
                    : storage
                    ? []
                    : {'id': 'item'},
              ),
              failed ? 503 : 200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(() async {
          await client.dispose();
          await db.close();
        });
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': 'test-token',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            'user': {
              'id': 'student',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-10-15T00:00:00Z',
            },
          }),
        );
        await db.customStatement(
          "INSERT INTO cache_profiles(id,role,display_name) VALUES ('teacher','instructor','Teacher'),('student','student','Student')",
        );
        await db.customStatement(
          "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','teacher','Course','A','2026','CODE')",
        );
        await db.customStatement(
          "INSERT INTO cache_posts(id,class_id,author_id,kind,title,points,due_at) VALUES ('post','class','teacher','assignment','Work',100,2000000000)",
        );
        await db.customStatement(
          "INSERT INTO cache_submissions(id,post_id,student_id) VALUES ('submission','post','student')",
        );
        await db.customStatement(
          "INSERT INTO cache_submission_items(id,submission_id,kind,storage_path) VALUES ('item','submission','file','class/post/student/file')",
        );
        SubmissionRepository open() => SubmissionRepository(
          PostRepository(
            ClassRepository(db, SupabaseClassRemote(client), 'student'),
            client,
            PostAttachmentRepository(db, client),
          ),
          client,
          isOnline: () => true,
        );
        var repo = open();
        expect(await repo.watchItems('submission').first, hasLength(1));
        await repo.queueRemoval(
          'item',
          'item',
          'class/post/student/file',
          submissionId: 'submission',
        );
        expect(await repo.watchItems('submission').first, isEmpty);
        await expectLater(
          repo.reconcileRemovals('submission'),
          throwsA(isA<Exception>()),
        );
        expect(calls.first, 'metadata');
        if (failMetadata) expect(calls, isNot(contains('bytes')));
        fail = false;
        calls.clear();
        repo = open();
        await repo.reconcileRemovals('submission');
        expect(calls, ['metadata', 'bytes']);
        expect(await repo.watchItems('submission').first, isEmpty);
        expect(
          await db
              .customSelect(
                "SELECT key FROM file_settings WHERE key LIKE 'submission_removal:%'",
              )
              .get(),
          isEmpty,
        );
        await repo.reconcileRemovals('submission');
        expect(calls, ['metadata', 'bytes']);
      },
    );
  }
  for (final legacy in [false, true]) {
    test(
      'permission-lost removal stays recorded while another class refreshes and submits; legacy=$legacy',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        const stamp = '2026-11-15T00:00:00Z';
        final post = <String, Object?>{
          'id': 'post-b',
          'class_id': 'class-b',
          'author_id': 'teacher',
          'kind': 'assignment',
          'title': 'Work',
          'points': 100,
          'due_at': '2030-11-15T00:00:00Z',
        'accept_late': false,
          'allow_files': true,
          'max_files': 5,
          'created_at': stamp,
          'updated_at': stamp,
        };
        Map<String, Object?> submission([String status = 'draft']) => {
          'id': 'submission-b',
          'post_id': 'post-b',
          'student_id': 'student',
          'status': status,
          'is_late': false,
          'created_at': stamp,
          'updated_at': stamp,
        };
        var denied = 0;
        final calls = <String>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final table = request.url.pathSegments.last;
            calls.add('$table:${request.method}');
            Object? value;
            var status = 200;
            if (table == 'submission_items' && request.method == 'PATCH') {
              denied++;
              value = {'code': '42501', 'message': 'Permission denied'};
              status = 403;
            } else if (table == 'submissions' && request.method == 'GET') {
              value = request.url.queryParameters['select'] == 'post_id'
                  ? {'post_id': 'post-b'}
                  : [];
            } else if (table == 'posts') {
              value = post;
            } else if (table == 'start_submission') {
              value = submission();
            } else if (table == 'turn_in') {
              value = submission('turned_in');
            } else if (table == 'submissions' && request.method == 'PATCH') {
              value = submission();
            } else if (request.url.path.contains('/object/sign/')) {
              value = {
                'signedURL': '/object/sign/submissions/file?token=fixture',
              };
            } else if (table == 'submission_items' &&
                request.url.queryParameters['id'] == 'eq.item-b') {
              value = {
                'id': 'item-b',
                'submission_id': 'submission-b',
                'kind': 'file',
                'storage_path': 'class-b/post-b/student/file',
                'deleted_at': null,
                'submissions': {'student_id': 'student', 'post_id': 'post-b'},
              };
            } else {
              value = request.headers['accept']?.contains('object+json') == true
                  ? null
                  : [];
            }
            return http.Response(
              jsonEncode(value),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(() async {
          await client.dispose();
          await db.close();
        });
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': 'test-token',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            'user': {
              'id': 'student',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': stamp,
            },
          }),
        );
        await db.customStatement(
          "INSERT INTO cache_profiles(id,role,display_name) VALUES ('teacher','instructor','Teacher'),('student','student','Student')",
        );
        for (final suffix in ['a', 'b']) {
          await db.customStatement(
            "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES (?, 'teacher','Course','A','2026',?)",
            ['class-$suffix', suffix],
          );
          await db.customStatement(
            "INSERT INTO cache_class_members(id,class_id,student_id,status) VALUES (?,?,'student','active')",
            ['member-$suffix', 'class-$suffix'],
          );
          await db.customStatement(
            "INSERT INTO cache_posts(id,class_id,author_id,kind,title,points,due_at) VALUES (?,?,'teacher','assignment','Work',100,2000000000)",
            ['post-$suffix', 'class-$suffix'],
          );
          await db.customStatement(
            "INSERT INTO cache_submissions(id,post_id,student_id) VALUES (?,?,'student')",
            ['submission-$suffix', 'post-$suffix'],
          );
        }
        await db.customStatement(
          "UPDATE cache_classes SET archived_at=1 WHERE id='class-a'",
        );
        await db.customStatement(
          "INSERT INTO cache_submission_items(id,submission_id,kind,storage_path) VALUES ('item-a','submission-a','file','class-a/post-a/student/file')",
        );
        final posts = _Posts(db, client);
        final repo = SubmissionRepository(posts, client, isOnline: () => true);
        if (legacy) {
          await db.customStatement(
            'INSERT INTO file_settings(key,value) VALUES (?,?)',
            [
              'submission_removal:item-a',
              jsonEncode({
                'item_id': 'item-a',
                'path': 'class-a/post-a/student/file',
              }),
            ],
          );
        } else {
          await repo.queueRemoval(
            'item-a',
            'item-a',
            'class-a/post-a/student/file',
            submissionId: 'submission-a',
          );
        }
        await expectLater(
          repo.startSubmission('post-a'),
          throwsA(isA<PostgrestException>()),
        );
        await repo.sync('class-a');
        expect(posts.refreshed, contains('class-a'));
        expect(await repo.watchItems('submission-a').first, isEmpty);
        final attempts = denied;
        await repo.sync('class-b');
        final work = SubmissionWorkRepository(repo);
        await work.saveComment('post-b', 'Keep working');
        expect(await work.signedFileLink('item-b'), contains('token=fixture'));
        expect((await repo.turnIn('submission-b')).status, 'turned_in');
        expect(denied, attempts);
        expect(calls, contains('turn_in:POST'));
        expect(posts.refreshed, contains('class-b'));
        expect(
          await db
              .customSelect(
                "SELECT key FROM file_settings WHERE key='submission_removal:item-a'",
              )
              .get(),
          hasLength(1),
        );
      },
    );
  }
}
