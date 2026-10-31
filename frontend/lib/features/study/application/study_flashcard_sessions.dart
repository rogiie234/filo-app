import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/ai_cancellation.dart';
import '../../../data/local/app_database.dart';
import '../data/student_ai_client.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_inputs.dart';

const studyFlashcardBusyMessage =
    'The AI assistant is busy right now. Please try again in a few minutes.';
const studyDeckLimitMessage =
    'You can have up to 10 decks in a notebook. Delete a deck to add another.';
const studyDeckSaveError =
    'Could not confirm this deck was saved. Keep this screen open and try saving again.';

class StudyDeckGeneration extends ChangeNotifier {
  StudyDeckGeneration({
    required this.notebookId,
    required this.repository,
    required this.client,
    required this.isCurrent,
    required this.isOnline,
  });
  final String notebookId;
  final StudyDeckRepository repository;
  final StudentAiClient client;
  final bool Function() isCurrent, isOnline;
  StudyAiResult<StudyAiBatch<StudyCardInput>>? result;
  StudyDeckSettings? _settings;
  String? error, savedId, _pendingId;
  bool working = false, saving = false, _disposed = false;
  int _epoch = 0;
  AiCancelToken? _cancel;
  bool get current => !_disposed && isCurrent();
  bool get hasUnsaved => result != null && savedId == null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generate(StudyDeckSettings settings) async {
    if (!current || working || result != null) return;
    try {
      settings.validate();
    } catch (_) {
      error = studyAiMessages['INVALID_REQUEST'];
      _changed();
      return;
    }
    if (!isOnline() || client.guard.isBusy) {
      error = studyAiMessages[isOnline() ? 'AI_IN_PROGRESS' : 'OFFLINE'];
      _changed();
      return;
    }
    final epoch = ++_epoch, token = AiCancelToken();
    _cancel = token;
    working = true;
    error = null;
    _changed();
    bool valid() => current && epoch == _epoch && !token.isCancelled;
    try {
      final answer = await client.flashcards(
        notebookId: notebookId,
        settings: settings,
        cancel: token,
      );
      if (!valid()) return;
      result = answer;
      _settings = settings;
      _pendingId = const Uuid().v4();
      await _save(valid);
    } catch (failure) {
      if (valid())
        error = failure is StudyAiFailure && failure.code == 'AI_BUSY'
            ? studyFlashcardBusyMessage
            : studyAiFriendlyError(failure);
    } finally {
      token.cancel();
      if (current && epoch == _epoch) {
        _cancel = null;
        working = false;
        saving = false;
        _changed();
      }
    }
  }

  Future<void> _save(bool Function() valid) async {
    saving = true;
    _changed();
    try {
      final title = _settings!.topicFocus.trim();
      final id = await repository.create(
        notebookId: notebookId,
        title: title.isEmpty ? 'Flashcard deck' : title,
        settings: _settings!,
        cards: result!.value.items,
        deckId: _pendingId,
        canCommit: valid,
      );
      if (valid()) {
        savedId = id;
        error = null;
      }
    } on StudyLimitExceeded {
      if (valid()) error = studyDeckLimitMessage;
    } catch (_) {
      if (valid()) error = studyDeckSaveError;
    }
  }

  Future<void> retrySave() async {
    if (!current || working || !hasUnsaved) return;
    final epoch = ++_epoch;
    working = true;
    error = null;
    _changed();
    await _save(() => current && epoch == _epoch);
    if (current && epoch == _epoch) {
      working = false;
      saving = false;
      _changed();
    }
  }

  void cancel() {
    if (!working || saving) return;
    _cancel?.cancel();
    ++_epoch;
    working = false;
    error = studyAiMessages['CANCELLED'];
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _cancel?.cancel();
    super.dispose();
  }
}

class StudyFlashcardSession extends ChangeNotifier {
  StudyFlashcardSession({
    required this.notebookId,
    required this.deckId,
    required this.repository,
    required this.isCurrent,
    Random? random,
  }) : _random = random ?? Random();
  final String notebookId, deckId;
  final StudyDeckRepository repository;
  final bool Function() isCurrent;
  final Random _random;
  List<StudyCard> cards = [];
  final _queue = <String>[];
  final _marked = <String, String>{};
  bool loading = true, working = false, _disposed = false;
  String? error, retryStatus;
  int revision = 0;
  bool get current => !_disposed && isCurrent();
  StudyCard? get card =>
      _queue.isEmpty ? null : cards.firstWhere((c) => c.id == _queue.first);
  int get known => _marked.values.where((s) => s == 'known').length;
  int get learning => _marked.values.where((s) => s == 'learning').length;
  int get completed => _marked.length;
  int get total => completed + _queue.length;
  double get progress => total == 0 ? 0 : completed / total;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open() async {
    if (!current || working) return;
    loading = true;
    error = null;
    _changed();
    try {
      final db = repository.db;
      final deck =
          await (db.select(db.flashcardDecks)..where(
                (d) => d.id.equals(deckId) & d.notebookId.equals(notebookId),
              ))
              .getSingleOrNull();
      if (deck == null) throw StateError('Deck no longer available');
      final saved =
          await (db.select(db.flashcards)
                ..where((c) => c.deckId.equals(deckId))
                ..orderBy([(c) => OrderingTerm.asc(c.position)]))
              .get();
      if (!current) return;
      cards = List.of(saved);
      _queue
        ..clear()
        ..addAll(cards.map((c) => c.id));
      _marked.clear();
      retryStatus = null;
      revision++;
    } catch (_) {
      if (current) error = studyAiMessages['LOAD_FAILED'];
    } finally {
      if (current) {
        loading = false;
        _changed();
      }
    }
  }

  Future<void> mark(String status) async {
    if (!current || loading || working || card == null) return;
    if (!{'known', 'learning'}.contains(status))
      throw ArgumentError.value(status);
    final id = card!.id;
    working = true;
    error = null;
    retryStatus = status;
    _changed();
    try {
      final changed = await repository.setCardStatus(
        id,
        status,
        deckId: deckId,
        canCommit: () => current,
      );
      if (!current) return;
      if (changed != 1) throw StateError('Card no longer available');
      cards = [
        for (final c in cards) c.id == id ? c.copyWith(status: status) : c,
      ];
      _marked[id] = status;
      _queue.remove(id);
      retryStatus = null;
      revision++;
    } catch (_) {
      if (current) error = 'Could not save this card\'s status. Try again.';
    } finally {
      if (current) {
        working = false;
        _changed();
      }
    }
  }

  void shuffle() {
    if (!current || loading || working || _queue.isEmpty) return;
    _queue.shuffle(_random);
    revision++;
    _changed();
  }

  void repeatMissed() {
    if (!current || working || _queue.isNotEmpty) return;
    final missed = _marked.entries
        .where((e) => e.value == 'learning')
        .map((e) => e.key)
        .toList();
    if (missed.isEmpty) return;
    _queue.addAll(missed);
    _marked.clear();
    retryStatus = null;
    error = null;
    revision++;
    _changed();
  }

  Future<void> deleteCurrent() async {
    if (!current || working || card == null) return;
    final id = card!.id;
    working = true;
    error = null;
    retryStatus = null;
    _changed();
    try {
      await repository.deleteCard(deckId, id, canCommit: () => current);
      if (!current) return;
      cards.removeWhere((c) => c.id == id);
      _queue.remove(id);
      _marked.remove(id);
      retryStatus = null;
      revision++;
    } catch (_) {
      if (current) error = 'Could not delete this card. Try again.';
    } finally {
      if (current) {
        working = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
