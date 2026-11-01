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
  });

  final String? Function() account;
  final Future<bool> Function() canRegister;
  final Future<String?> Function() getToken;
  final Future<String> Function() deviceHash;
  final Future<void> Function(String token, String hash) register;
  final Future<void> Function(String token) unregister;
  final Future<void> Function() deleteToken;
  final Future<void> Function() signOut;
  final void Function(String)? onStatus;
  Future<void>? _pending;
  Future<void>? _leaving;
  String? _token, _registeredAccount, _registeredToken, _blockedAccount;
  bool _again = false, _disposed = false;

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
      bool current() => !_disposed && _leaving == null && account() == owner;
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
        onStatus?.call('Registration pending: $stage failed');
        // Resume/reconnect retries only the current account; tokens never enter logs.
      }
    }
  }

  Future<void> leave() =>
      _leaving ??= _leave().whenComplete(() => _leaving = null);

  Future<void> _leave() async {
    _blockedAccount = account();
    _again = false;
    // Let an already dispatched registration finish before removing its token.
    await _pending;
    try {
      final token = _token ?? await getToken();
      if (token != null) await unregister(token);
    } catch (_) {
      // Offline/revoked sessions cannot remove the server row; invalidate FCM too.
      onStatus?.call('Sign-out cleanup pending: unregister failed');
    }
    try {
      await deleteToken();
    } catch (_) {
      // Authentication sign-out must remain available when Firebase is offline.
      onStatus?.call('Sign-out cleanup pending: FCM invalidation failed');
    }
    _token = _registeredAccount = _registeredToken = null;
    try {
      await signOut();
    } catch (_) {
      _blockedAccount = null;
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    _again = false;
  }
}
