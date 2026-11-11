import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/profile_repository.dart';

final pushEventsProvider = Provider<PushEvents>((ref) {
  final events = PushEvents();
  ref.onDispose(events.dispose);
  return events;
});

class NotificationHomeReady extends Notification {
  NotificationHomeReady(this.profile);
  final AccountProfile profile;
}

class PushEvent {
  const PushEvent(
    this.id, {
    required this.open,
    this.accountId,
    this.completion,
    this.assignmentId,
    this.alarmId,
  });
  final String? id, accountId;
  final bool open;
  final Completer<void>? completion;
  final String? assignmentId;
  final String? alarmId;
}

/// Contains identifiers only; display content comes from authorized inbox rows.
class PushEvents extends ChangeNotifier {
  // shortcut: pending taps live in memory, persist intents if a second process death must resume them.
  final _pending = <PushEvent>[];
  final _seen = <String>{};
  PushEvent? _inboxOpen;

  Future<void> openInbox(String id, String accountId) {
    if (!validId(id)) {
      return Future.error(ArgumentError('Invalid notification'));
    }
    if (_inboxOpen != null) return _inboxOpen!.completion!.future;
    final event = PushEvent(
      id.toLowerCase(),
      open: true,
      accountId: accountId,
      completion: Completer<void>(),
    );
    _inboxOpen = event;
    _pending.add(event);
    notifyListeners();
    return event.completion!.future;
  }

  void finishOpen(PushEvent event) {
    final completion = event.completion;
    if (completion != null && !completion.isCompleted) completion.complete();
    if (identical(_inboxOpen, event)) _inboxOpen = null;
  }

  void failInboxOpen() {
    final event = _inboxOpen;
    if (event == null) return;
    _pending.remove(event);
    if (!event.completion!.isCompleted) {
      event.completion!.completeError(
        StateError('Notification storage unavailable'),
      );
    }
    _inboxOpen = null;
  }

  static bool validId(Object? id) =>
      id is String &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);

  void receive(
    Map<String, dynamic> data, {
    required bool open,
    String? accountId,
  }) {
    if (!open && accountId == null) return;
    final raw = data['notification_id'];
    final id = validId(raw) ? (raw as String).toLowerCase() : null;
    if (id == null && !open) return;
    final key = 'push:$accountId:$id:$open';
    if (!_seen.add(key)) return;
    _pending.add(PushEvent(id, open: open, accountId: accountId));
    notifyListeners();
  }

  void receiveReminder(Map<dynamic, dynamic> data) {
    if (data['kind'] == 'study') {
      if (!validId(data['accountId']) ||
          !validId(data['alarmId']) ||
          data['nonce'] is! String) {
        return;
      }
      final key =
          'study:${data['accountId']}:${data['alarmId']}:${data['nonce']}';
      if (!_seen.add(key)) return;
      _pending.add(
        PushEvent(
          null,
          open: true,
          accountId: data['accountId'] as String,
          alarmId: data['alarmId'] as String,
        ),
      );
      notifyListeners();
      return;
    }
    if (!validId(data['accountId']) ||
        !validId(data['postId']) ||
        data['nonce'] is! String) {
      return;
    }
    final key =
        'reminder:${data['accountId']}:${data['postId']}:${data['nonce']}';
    if (!_seen.add(key)) return;
    _pending.add(
      PushEvent(
        null,
        open: true,
        accountId: data['accountId'] as String,
        assignmentId: data['postId'] as String,
      ),
    );
    notifyListeners();
  }

  PushEvent? take(String accountId, {required bool allowOpen}) {
    _pending.removeWhere((e) {
      final foreign = e.accountId != null && e.accountId != accountId;
      if (foreign) finishOpen(e);
      return foreign;
    });
    final index = _pending.indexWhere((e) => allowOpen || !e.open);
    return index < 0 ? null : _pending.removeAt(index);
  }

  void retry(PushEvent event) {
    _pending.add(event);
    notifyListeners();
  }

  void clearAccount(String id) {
    if (_inboxOpen?.accountId == id) finishOpen(_inboxOpen!);
    for (final event
        in _pending.where((event) => event.accountId == id).toList()) {
      finishOpen(event);
      _pending.remove(event);
    }
    _seen.removeWhere(
      (key) =>
          key.startsWith('push:$id:') ||
          key.startsWith('study:$id:') ||
          key.startsWith('reminder:$id:'),
    );
    notifyListeners();
  }

  void clear() {
    if (_inboxOpen != null) finishOpen(_inboxOpen!);
    _pending.clear();
    _seen.clear();
    notifyListeners();
  }
}
