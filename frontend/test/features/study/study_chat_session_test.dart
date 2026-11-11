import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/study/application/study_chat_session.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingChatRepository extends StudyChatRepository {
  FailingChatRepository(super.db);
  bool failQuestion = false, failReply = false;
  Completer<void>? questionGate;
  @override
  Future<(String, String)> saveQuestion({
    required String notebookId,
    required String? chatId,
    required String content,
    required String mode,
  }) async {
    if (questionGate != null) await questionGate!.future;
    if (failQuestion) throw StateError('Synthetic storage failure');
    return super.saveQuestion(
      notebookId: notebookId,
      chatId: chatId,
      content: content,
      mode: mode,
    );
  }

  @override
  Future<void> saveReply({
    required String notebookId,
    required String chatId,
    required String questionId,
    required String content,
    required String mode,
  }) {
    if (failReply) throw StateError('Synthetic storage failure');
    return super.saveReply(
      notebookId: notebookId,
      chatId: chatId,
      questionId: questionId,
      content: content,
      mode: mode,
    );
  }
}

void main() {
  late AppDatabase db;
  late FailingChatRepository repo;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StudyChatSession session;
  late String notebook;
  var elapsed = Duration.zero;
  var online = true, current = true;
  var calls = 0;
  late DateTime now;
  Map<String, dynamic>? submitted;
  late StudyAiInvoke invoke;
  Future<void> Function()? loadHook;
  setUp(() async {
    now = DateTime.utc(2026, 10, 31);
    db = AppDatabase(NativeDatabase.memory(), now: () => now);
    repo = FailingChatRepository(db);
    notebook = await NotebookRepository(db).create('Chat notebook');
    elapsed = Duration.zero;
    online = true;
    current = true;
    calls = 0;
    loadHook = null;
    submitted = null;
    guard = AiRequestGuard(elapsed: () => elapsed);
    invoke = (_, body, _) async => {
      'answer': '**A saved answer**\n- One point',
      'mode': (body['sources'] as List).isEmpty ? 'general' : 'files',
      'truncated': false,
    };
    client = StudentAiClient(
      invoke: (function, body, abort) {
        calls++;
        submitted = body;
        return invoke(function, body, abort);
      },
      loadSources: (_) async {
        await loadHook?.call();
        final sources = await (db.select(
          db.notebookSources,
        )..where((s) => s.notebookId.equals(notebook))).get();
        return sources
            .map(
              (s) => StudyAiSource(
                key: s.sourceKey,
                name: s.name,
                text: s.extractedText,
              ),
            )
            .toList();
      },
      isOnline: () => online,
      currentAccount: () => current ? 'student-session' : 'other-session',
      guard: guard,
    );
    session = StudyChatSession(
      notebookId: notebook,
      repository: repo,
      client: client,
      isCurrent: () => current,
      isOnline: () => online,
    );
    await session.open(latest: true);
  });
  tearDown(() async {
    session.dispose();
    await guard.close();
    await db.close();
  });

  test('first question and answer save with title, mode, expiry and reopen history', () async {
    session.setDraft('  Explain cells.  ');
    await session.send();
    expect(calls, 1);
    expect(session.messages.map((m) => m.role), ['user', 'assistant']);
    expect(session.messages.every((m) => m.mode == 'general'), isTrue);
    final chat = await repo.find(notebook, session.chatId!);
    expect(chat!.title, 'Explain cells.');
    expect(chatDaysLeft(chat.expiresAt, db.now().toUtc()), 30);
    final id = session.chatId;
    await session.open();
    expect(session.chatId, isNull);
    expect((await db.select(db.chats).get()).length, 1);
    await session.open(latest: true);
    expect(session.chatId, id);
    expect(session.messages.length, 2);
    await repo.delete(id!);
    expect(await repo.getMessages(id), isEmpty);
  });

  test(
    'cancel ignores late response and retry reuses the unanswered question',
    () async {
      final dispatched = Completer<void>(), reply = Completer<dynamic>();
      invoke = (_, _, _) {
        dispatched.complete();
        return reply.future;
      };
      session.setDraft('Explain cells.');
      final sending = session.send();
      await dispatched.future;
      final questionId = session.messages.single.id;
      session.cancel();
      await sending;
      reply.complete({
        'answer': 'Late answer',
        'mode': 'general',
        'truncated': false,
      });
      await Future<void>.delayed(Duration.zero);
      expect(session.messages.length, 1);
      expect(session.draft, 'Explain cells.');
      expect(session.error, studyAiMessages['CANCELLED']);
      elapsed += const Duration(seconds: 3);
      invoke = (_, _, _) async => {
        'answer': 'New answer',
        'mode': 'general',
        'truncated': false,
      };
      await session.send();
      expect(calls, 2);
      expect(session.messages.length, 2);
      expect(session.messages.first.id, questionId);
      expect(session.messages.last.content, 'New answer');
    },
  );

  test('busy copy is chat-specific after save and an edited retry creates another question', () async {
    invoke = (_, _, _) async => {
      'error': {'code': 'AI_BUSY'},
    };
    session.setDraft('First question');
    await session.send();
    expect(session.error, studyChatBusyMessage);
    expect(session.messages.single.content, 'First question');
    elapsed += const Duration(seconds: 3);
    session.setDraft('Edited question');
    await session.send();
    expect(session.messages.map((m) => m.content), [
      'First question',
      'Edited question',
    ]);
    expect(session.draft, 'Edited question');
  });

  test(
    'save failures prevent transport; answer save retry does not call AI again',
    () async {
      repo.failQuestion = true;
      session.setDraft('Question');
      await session.send();
      expect(calls, 0);
      expect(session.error, studyChatSaveMessageError);
      expect(await db.select(db.chats).get(), isEmpty);
      repo.failQuestion = false;
      repo.failReply = true;
      await session.send();
      expect(calls, 1);
      expect(session.pendingAnswer, isNotNull);
      expect(session.messages.length, 1);
      expect(session.draft, 'Question');
      repo.failReply = false;
      await session.retrySave();
      expect(calls, 1);
      expect(session.pendingAnswer, isNull);
      expect(session.messages.length, 2);
      expect(session.draft, isEmpty);
      await repo.saveReply(
        notebookId: notebook,
        chatId: session.chatId!,
        questionId: session.messages.first.id,
        content: session.messages.last.content,
        mode: session.messages.last.mode,
      );
      expect((await repo.getMessages(session.chatId!)).length, 2);
    },
  );

  test('client caps Unicode messages, last ten history and source prefixes with truthful notices', () async {
    final id = await repo.create(notebook, 'Old conversation');
    for (var i = 0; i < 12; i++) {
      await repo.addMessage(
        chatId: id,
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i',
        mode: 'general',
      );
    }
    await NotebookSourceRepository(db).add(
      notebookId: notebook,
      fileId: 'local',
      name: 'long.txt',
      text: LessonText(text: 'x' * 45000, sourceKey: 'att:long'),
      extractedAt: db.now(),
    );
    await session.open(id: id);
    session.setDraft('😀' * 2001);
    await session.send();
    final messages = submitted!['messages'] as List;
    expect(messages.length, 10);
    expect((messages.last['content'] as String).runes.length, 2000);
    expect(
      ((submitted!['sources'] as List).single['text'] as String).runes.length,
      40000,
    );
    expect(session.messages.last.mode, 'files');
    expect(
      session.notices,
      contains('Only the first 40000 characters of long.txt were used.'),
    );
    expect(
      session.notices,
      contains('Your message was shortened to 2,000 characters.'),
    );
  });

  test(
    'offline, shared busy and cooldown never dispatch or create empty chats',
    () async {
      session.setDraft('Question');
      online = false;
      await session.send();
      expect(session.error, studyAiMessages['OFFLINE']);
      online = true;
      final release = Completer<void>();
      final occupied = guard.run(AiCancelToken(), (_) => release.future);
      await session.send();
      expect(session.error, studyAiMessages['AI_IN_PROGRESS']);
      release.complete();
      await occupied;
      guard.markChatDispatched();
      await session.send();
      expect(calls, 0);
      expect(await db.select(db.chats).get(), isEmpty);
      elapsed += const Duration(seconds: 3);
      expect(guard.chatCooldownRemaining, Duration.zero);
      await session.send();
      expect(calls, 1);
    },
  );

  test('source changes during preparation refuse dispatch rather than switch to general knowledge', () async {
    await NotebookSourceRepository(db).add(
      notebookId: notebook,
      fileId: 'file',
      name: 'one.txt',
      text: const LessonText(text: 'Text', sourceKey: 'att:one'),
      extractedAt: db.now(),
    );
    loadHook = () async {
      await db.delete(db.notebookSources).go();
    };
    session.setDraft('Question');
    await session.send();
    expect(calls, 0);
    expect(session.error, studyAiMessages['LOAD_FAILED']);
    expect(await db.select(db.chats).get(), isEmpty);
  });

  test('account change prevents saving a late answer', () async {
    final dispatched = Completer<void>(), reply = Completer<dynamic>();
    invoke = (_, _, _) {
      dispatched.complete();
      return reply.future;
    };
    session.setDraft('Question');
    final sending = session.send();
    await dispatched.future;
    final id = session.chatId!;
    current = false;
    reply.complete({
      'answer': 'Do not save',
      'mode': 'general',
      'truncated': false,
    });
    await sending;
    expect((await repo.getMessages(id)).length, 1);
  });

  test('expiry excludes exact-boundary chats and reopening restores unanswered text', () async {
    final ids = await repo.saveQuestion(
      notebookId: notebook,
      chatId: null,
      content: 'Unanswered',
      mode: 'general',
    );
    await session.open(latest: true);
    expect(session.draft, 'Unanswered');
    final chat = (await repo.find(notebook, ids.$1))!;
    expect(chatDaysLeft(chat.expiresAt, chat.expiresAt), 0);
    expect(
      chatDaysLeft(
        chat.expiresAt,
        chat.expiresAt.subtract(const Duration(milliseconds: 1)),
      ),
      1,
    );
    now = chat.expiresAt;
    await session.open(latest: true);
    expect(session.chatId, isNull);
    expect(await repo.getMessages(ids.$1), isEmpty);
  });

  test(
    'every server failure keeps the composer and never exposes raw errors',
    () async {
      session.setDraft('Keep this question');
      for (final code in [
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
      ]) {
        invoke = (_, _, _) async => {
          'error': {'code': code, 'message': 'raw diagnostics'},
        };
        await session.send();
        expect(
          session.error,
          code == 'AI_BUSY' ? studyChatBusyMessage : studyAiMessages[code],
        );
        expect(session.draft, 'Keep this question');
        elapsed += const Duration(seconds: 3);
      }
      invoke = (_, _, _) async => throw StateError('raw transport diagnostics');
      await session.send();
      expect(session.error, studyAiMessages['UNKNOWN']);
      expect(session.messages.length, 1);
    },
  );

  test(
    'timeout keeps the saved question and ignores a late transport result',
    () async {
      final reply = Completer<dynamic>();
      final bounded = StudentAiClient(
        invoke: (_, _, _) => reply.future,
        loadSources: (_) async => [],
        isOnline: () => true,
        currentAccount: () => 'student',
        guard: guard,
        timeout: const Duration(milliseconds: 50),
      );
      final timedSession = StudyChatSession(
        notebookId: notebook,
        repository: repo,
        client: bounded,
        isCurrent: () => true,
        isOnline: () => true,
      );
      try {
        await timedSession.open();
        timedSession.setDraft('Question');
        await timedSession.send();
        expect(timedSession.error, studyAiMessages['AI_TIMEOUT']);
        expect(timedSession.messages.length, 1);
        reply.complete({
          'answer': 'Late',
          'mode': 'general',
          'truncated': false,
        });
        await Future<void>.delayed(Duration.zero);
        expect((await repo.getMessages(timedSession.chatId!)).length, 1);
      } finally {
        timedSession.dispose();
      }
    },
  );

  test(
    'deadline during question storage rolls back and never dispatches late',
    () async {
      repo.questionGate = Completer<void>();
      var invoked = false;
      final bounded = StudentAiClient(
        invoke: (_, _, _) async {
          invoked = true;
          return {
            'answer': 'Do not dispatch',
            'mode': 'general',
            'truncated': false,
          };
        },
        loadSources: (_) async => [],
        isOnline: () => true,
        currentAccount: () => 'student',
        guard: guard,
        timeout: const Duration(milliseconds: 50),
      );
      final delayedSession = StudyChatSession(
        notebookId: notebook,
        repository: repo,
        client: bounded,
        isCurrent: () => true,
        isOnline: () => true,
      );
      try {
        await delayedSession.open();
        delayedSession.setDraft('Question');
        await delayedSession.send();
        expect(delayedSession.error, studyAiMessages['AI_TIMEOUT']);
        repo.questionGate!.complete();
        expect(await db.select(db.chats).get(), isEmpty);
        expect(invoked, isFalse);
      } finally {
        delayedSession.dispose();
      }
    },
  );

  test('latest chat follows message activity and retry renews its thirty-day expiry', () async {
    final first = await repo.saveQuestion(
      notebookId: notebook,
      chatId: null,
      content: 'First',
      mode: 'general',
    );
    now = now.add(const Duration(days: 1));
    final second = await repo.saveQuestion(
      notebookId: notebook,
      chatId: null,
      content: 'Second',
      mode: 'general',
    );
    await session.open(latest: true);
    expect(session.chatId, second.$1);
    now = now.add(const Duration(days: 1));
    final retried = await repo.saveQuestion(
      notebookId: notebook,
      chatId: first.$1,
      content: 'First',
      mode: 'general',
    );
    expect(retried.$2, first.$2);
    await session.open(latest: true);
    expect(session.chatId, first.$1);
    expect(
      (await repo.find(notebook, first.$1))!.expiresAt.toUtc(),
      now.add(const Duration(days: 30)),
    );
  });
}
