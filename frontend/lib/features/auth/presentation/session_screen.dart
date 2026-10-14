import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _code = TextEditingController();
  String? _challenge;
  String? _message;
  DateTime? _resendAt;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not complete the request. Check your code and connection, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _perform(() async {
    if (_resendAt != null && DateTime.now().isBefore(_resendAt!)) {
      setState(
        () => _message = 'Wait 60 seconds before requesting another code.',
      );
      return;
    }
    final hash = await ref.read(deviceHashProvider.future);
    final response = await ref
        .read(supabaseClientProvider)
        .functions
        .invoke('send-otp', body: {'device_hash': hash});
    final data = response.data as Map<String, dynamic>;
    if (data['challenge_id'] is! String) throw StateError('OTP not issued');
    if (!mounted) return;
    setState(() {
      _challenge = data['challenge_id'] as String;
      _resendAt = DateTime.now().add(
        Duration(seconds: data['resend_after'] as int? ?? 60),
      );
      _message = 'Code sent. Check your email.';
    });
  });

  Future<void> _verify() => _perform(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _message = 'Enter the six-digit code.');
      return;
    }
    final hash = await ref.read(deviceHashProvider.future);
    final response = await ref
        .read(supabaseClientProvider)
        .functions
        .invoke(
          'verify-otp',
          body: {
            'challenge_id': _challenge,
            'device_hash': hash,
            'code': _code.text,
          },
        );
    if ((response.data as Map)['verified'] != true) {
      throw StateError('Not verified');
    }
    if (!mounted) return;
    _code.clear();
    ref.invalidate(verifiedUserIdProvider);
  });

  Future<void> _checkReads() => _perform(() async {
    final client = ref.read(supabaseClientProvider);
    final profiles = await client.from('profiles').select('id');
    final classes = await client.from('classes').select('id');
    if (!mounted) return;
    setState(
      () => _message =
          'Visible rows: profiles ${profiles.length}, classes ${classes.length}.',
    );
  });

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(verifiedUserIdProvider);
    final verified = verification.asData?.value != null;
    final session = ref.watch(loginSessionProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filo'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _perform(() async {
                    await ref.read(supabaseClientProvider).auth.signOut();
                  }),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  verified ? 'Device verified' : 'Verify your device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  verified
                      ? 'Your session can now access permitted account data.'
                      : 'Verify the code sent to your Google account email to continue.',
                ),
                if (session != null) Text(session.user.email ?? ''),
                if (verification.isLoading) const CircularProgressIndicator(),
                if (verification.hasError) ...[
                  const Text(
                    'Could not check this login. Account data remains locked.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(verifiedUserIdProvider),
                    child: const Text('Retry device check'),
                  ),
                ],
                if (!verified &&
                    !verification.isLoading &&
                    !verification.hasError) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: Text(
                      _challenge == null ? 'Send code' : 'Resend code',
                    ),
                  ),
                  if (_challenge != null) ...[
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: const Text('Verify code'),
                    ),
                  ],
                ],
                if (kDebugMode && session != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Session ID present: ${_hasSessionId(session.accessToken)}',
                  ),
                  TextButton(
                    onPressed: _busy ? null : _checkReads,
                    child: const Text('Check profile and class access'),
                  ),
                ],
                if (_busy) const CircularProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasSessionId(String token) {
    try {
      sessionIdFromToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }
}
