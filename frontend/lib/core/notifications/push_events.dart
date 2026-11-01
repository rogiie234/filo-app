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
  const PushEvent(this.id, {required this.open, this.accountId});
  final String? id, accountId;
  final bool open;
}

/// Contains identifiers only; display content comes from authorized inbox rows.
class PushEvents extends ChangeNotifier {
  // shortcut: pending taps live in memory, persist intents if a second process death must resume them.
  final _pending = <PushEvent>[];
  final _seen = <String>{};

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
    final key = '$id:$open';
    if (!_seen.add(key)) return;
    _pending.add(PushEvent(id, open: open, accountId: accountId));
    notifyListeners();
  }

  PushEvent? take(String accountId, {required bool allowOpen}) {
    _pending.removeWhere(
      (e) => e.accountId != null && e.accountId != accountId,
    );
    final index = _pending.indexWhere((e) => allowOpen || !e.open);
    return index < 0 ? null : _pending.removeAt(index);
  }

  void retry(PushEvent event) {
    _pending.add(event);
    notifyListeners();
  }

  void clear() {
    _pending.clear();
    _seen.clear();
    notifyListeners();
  }
}
