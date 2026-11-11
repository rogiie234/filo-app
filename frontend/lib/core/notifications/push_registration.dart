import 'dart:async';

/// Serializes this phone's registration and cleanup across account changes.
class PushRegistration {
  PushRegistration({
    required this.account,
    required this.canRegister,
    required this.getToken,
    required this.deviceHash,
    required this.register,
    required this.unregister,
    required this.deleteToken,
    required this.signOut,
    this.onStatus,
    this.signOutDeleted,
  });

  final String? Function() account;
  final Future<bool> Function() canRegister;
  final Future<String?> Function() getToken;
  final Future<String> Function() deviceHash;
  final Future<void> Function(String token, String hash) register;
  final Future<void> Function(String token) unregister;
  final Future<void> Function() deleteToken;
  final Future<void> Function() signOut;
  final Future<void> Function()? signOutDeleted;
  final void Function(String)? onStatus;
  Future<void>? _pending;
  Future<void>? _leaving;
  String? _token, _registeredAccount, _registeredToken, _blockedAccount;
  bool _again = false, _disposed = false, _deletionLeave = false;
  Object _generation = Object();

  bool Function() sessionGuard() {
    final owner = account();
    final generation = _generation;
    return () =>
        !_disposed &&
        owner != null &&
        account() == owner &&
        identical(generation, _generation);
  }

  void accountChanged() {
    _generation = Object();
    _token = _registeredAccount = _registeredToken = _blockedAccount = null;
    _again = true;
  }

  Future<void> sync() {
    if (_disposed || _leaving != null) return Future.value();
    _again = true;
    return _pending ??= _drain().whenComplete(() => _pending = null);
  }

  Future<void> _drain() async {
    while (_again && !_disposed && _leaving == null) {
      _again = false;
      final owner = account();
      if (owner == null) {
        _token = _registeredAccount = _registeredToken = null;
        try {
          await deleteToken();
        } catch (_) {}
        continue;
      }
      if (owner == _blockedAccount) return;
      final sessionCurrent = sessionGuard();
      bool current() => _leaving == null && sessionCurrent();
      var stage = 'eligibility';
      try {
        if (!await canRegister() || !current()) continue;
        stage = 'FCM token';
        onStatus?.call('Obtaining FCM token');
        final token = await getToken();
        if (!current()) continue;
        if (token == null || token.isEmpty) {
          onStatus?.call('FCM returned no token');
          continue;
        }
        _token = token;
        if (_registeredAccount == owner && _registeredToken == token) continue;
        stage = 'device hash';
        final hash = await deviceHash();
        if (!current()) continue;
        stage = 'registration RPC';
        onStatus?.call('Registering phone');
        await register(token, hash);
        if (current()) {
          _registeredAccount = owner;
          _registeredToken = token;
          onStatus?.call('Phone registered');
        }
      } catch (_) {
        if (current()) onStatus?.call('Registration pending: $stage failed');
        // Resume/reconnect retries only the current account; tokens never enter logs.
      }
    }
  }

  Future<void> leave() => _leaving ??= _leave().whenComplete(() {
    _leaving = null;
    if (_again && !_disposed && account() != null) unawaited(sync());
  });

  Future<void> _leave() async {
    final current = sessionGuard();
    if (!current()) return;
    _blockedAccount = account();
    _again = false;
    // Finish dispatched registration before removal, but never cross a session change.
    await _pending;
    if (!current()) return;
    try {
      final token = _token ?? await getToken();
      if (!current()) return;
      if (token != null) await unregister(token);
    } catch (_) {
      if (current()) {
        onStatus?.call('Sign-out cleanup pending: unregister failed');
      }
    }
    if (!current()) return;
    try {
      await deleteToken();
    } catch (_) {
      if (current()) {
        onStatus?.call('Sign-out cleanup pending: FCM invalidation failed');
      }
    }
    if (!current()) return;
    _token = _registeredAccount = _registeredToken = null;
    try {
      await signOut();
    } catch (_) {
      // The SDK can remove the local session before remote revocation fails.
      if (current()) {
        _blockedAccount = null;
        rethrow;
      }
    }
  }

  Future<void> leaveForDeletion(String id) {
    final pending = _leaving;
    if (pending != null) {
      if (_deletionLeave) return pending;
      return pending.then(
        (_) => leaveForDeletion(id),
        onError: (Object _, StackTrace _) => leaveForDeletion(id),
      );
    }
    _deletionLeave = true;
    return _leaving = _leaveDeleted(id).whenComplete(() {
      _deletionLeave = false;
      _leaving = null;
      if (_again && !_disposed && account() != null) unawaited(sync());
    });
  }

  Future<void> _leaveDeleted(String id) async {
    final owner = account();
    if (owner != null && !owner.startsWith('$id:')) return;
    final generation = _generation;
    bool current() =>
        !_disposed && identical(generation, _generation) && account() == owner;
    _blockedAccount = owner;
    _again = false;
    await _pending;
    if (!current()) return;
    try {
      if (owner != null && _token != null) await unregister(_token!);
    } catch (_) {
      /* Remote removal is best effort; local deletion is confirmed separately. */
    }
    if (!current()) return;
    Object? tokenError;
    try {
      await deleteToken();
    } catch (error) {
      tokenError = error;
    }
    if (!current()) return;
    _token = _registeredAccount = _registeredToken = null;
    if (owner != null) {
      try {
        await (signOutDeleted ?? signOut)();
      } catch (_) {
        if (current()) rethrow;
      }
    }
    if (tokenError != null && (current() || account() == null)) {
      throw tokenError;
    }
  }

  void dispose() {
    _disposed = true;
    _again = false;
  }
}
