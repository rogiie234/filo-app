import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../onboarding/presentation/account_setup_screen.dart';

final otpClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});
  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _challenge, _message, _diagnostic;
  DateTime? _resendAt, _expiresAt;
  Timer? _timer;
  bool _busy = false, _error = false, _locked = false;
  int get _seconds => _resendAt == null
      ? 0
      : (_resendAt!.difference(ref.read(otpClockProvider)()).inMilliseconds /
                1000)
            .ceil()
            .clamp(0, 600);
  bool get _canResend =>
      !_busy &&
      _seconds == 0 &&
      (!_locked ||
          (_expiresAt != null &&
              !ref.read(otpClockProvider)().isBefore(_expiresAt!)));

  void _countdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (_seconds == 0 && (!_locked || _canResend)) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _feedback(String message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _message = message;
        _error = error;
      });
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
    } on FunctionException catch (exception) {
      final data = exception.details is Map ? exception.details as Map : {};
      final error = data['error'];
      final code = error is Map ? error['code'] : null;
      switch (code) {
        case 'OTP_WRONG':
          final attempts = data['attempts_remaining'];
          _feedback(
            'That code is incorrect. Check your email and try again.'
            '${attempts is int ? '\n$attempts ${attempts == 1 ? 'attempt' : 'attempts'} remaining.' : ''}',
            error: true,
          );
        case 'OTP_EXPIRED':
          _feedback(
            'Your code has expired. Request a new code to continue.',
            error: true,
          );
        case 'OTP_LOCKED':
          _locked = true;
          _countdown();
          _feedback(
            "You've reached the limit of 5 incorrect attempts. Wait until this code expires, then request a new code.",
            error: true,
          );
        case 'OTP_RESEND_TOO_SOON':
          final seconds = data['retry_after'];
          if (seconds is int) {
            _resendAt = ref
                .read(otpClockProvider)()
                .add(Duration(seconds: seconds));
            _countdown();
          }
          _feedback(
            'Please wait ${seconds is int ? '$seconds ${seconds == 1 ? 'second' : 'seconds'}' : 'a moment'} before requesting another code.',
            error: true,
          );
        case 'OTP_USED':
          _feedback(
            'This code has already been used. Request a new code to continue.',
            error: true,
          );
        case 'OTP_SEND_FAILED':
          _feedback(
            'We couldn’t send your code. Please try again in a moment.',
            error: true,
          );
        default:
          _feedback(
            'Something went wrong. Please try again in a moment.',
            error: true,
          );
      }
    } on SocketException {
      _feedback(
        "You're offline. Connect to the internet to send or verify your code.",
        error: true,
      );
    } catch (_) {
      _feedback(
        'Something went wrong. Please try again in a moment.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _perform(() async {
    final hash = await ref.read(deviceHashProvider.future);
    final requestedAt = ref.read(otpClockProvider)();
    final response = await ref
        .read(supabaseClientProvider)
        .functions
        .invoke('send-otp', body: {'device_hash': hash});
    final data = response.data as Map<String, dynamic>;
    if (data['challenge_id'] is! String) throw StateError('OTP not issued');
    if (!mounted) return;
    setState(() {
      _challenge = data['challenge_id'] as String;
      _locked = false;
      _code.clear();
      _resendAt = ref
          .read(otpClockProvider)()
          .add(Duration(seconds: data['resend_after'] as int? ?? 60));
      _expiresAt = requestedAt.add(
        Duration(seconds: data['expires_in'] as int? ?? 600),
      );
    });
    _countdown();
    _focus.requestFocus();
  });
  Future<void> _verify() => _perform(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      _feedback('Enter the 6-digit code from your email.', error: true);
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
    _focus.unfocus();
    ref.invalidate(verifiedUserIdProvider);
  });
  Future<void> _checkReads() => _perform(() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final profiles = await client.from('profiles').select('id');
      final classes = await client.from('classes').select('id');
      if (mounted) {
        setState(
          () => _diagnostic =
              'Visible rows: profiles ${profiles.length}, classes ${classes.length}.',
        );
      }
    } on PostgrestException catch (error) {
      if (error.code != '42501') rethrow;
      if (mounted) {
        setState(() => _diagnostic = 'Access denied by database security.');
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(verifiedUserIdProvider);
    final verified = verification.asData?.value != null;
    if (verified) return const AccountSetupScreen();
    final checking = verification.isLoading;
    final session = ref.watch(loginSessionProvider).asData?.value;
    final rawEmail = session?.user.email;
    final at = rawEmail?.indexOf('@') ?? -1;
    final sent = _challenge != null;
    final email = !sent
        ? rawEmail ?? 'your Google email'
        : rawEmail != null && at > 0
        ? '${rawEmail[0]}***${rawEmail.substring(at)}'
        : 'your Google email';
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        toolbarHeight: 76,
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _perform(() async {
                    await ref.read(supabaseClientProvider).auth.signOut();
                  }),
            child: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Mascot(pose: verified ? 'cheerful' : 'curious', size: 156),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        verified
                            ? Icons.check_circle_rounded
                            : Icons.shield_outlined,
                        size: 18,
                        color: FiloColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          verified
                              ? 'Device confirmed'
                              : 'A quick security check',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: FiloColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    verified
                        ? 'You’re all set.'
                        : checking
                        ? 'One moment…'
                        : 'Let’s make sure\nit’s you.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    verified
                        ? 'This device is ready for Filo. We’ll recognize it the next time you sign in.'
                        : checking
                        ? 'We’re checking this device before you continue.'
                        : sent
                        ? 'We sent a 6-digit code to $email. Enter it to verify this device. The code expires in 10 minutes.'
                        : 'One little check to keep your account safe. We’ll send a 6-digit code to your Google email.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FiloColors.secondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (checking)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )
                  else if (verification.hasError)
                    FiloPanel(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: FiloColors.secondary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'We couldn’t check this device. Please try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FiloButton(
                            label: 'Try again',
                            onPressed: () =>
                                ref.invalidate(verifiedUserIdProvider),
                          ),
                        ],
                      ),
                    )
                  else if (!verified)
                    FiloPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!sent) ...[
                            const Icon(
                              Icons.mark_email_unread_outlined,
                              size: 28,
                              color: FiloColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FiloButton(
                              label: _busy ? 'Sending code…' : 'Send code',
                              icon: _busy ? null : Icons.arrow_forward_rounded,
                              onPressed: _busy ? null : _send,
                            ),
                          ] else ...[
                            const Text(
                              'Verification code',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            AutofillGroup(
                              child: TextField(
                                controller: _code,
                                focusNode: _focus,
                                enabled: !_busy && !_locked,
                                keyboardType: TextInputType.number,
                                // Codes must not be rewritten by keyboard predictions.
                                autocorrect: false,
                                enableSuggestions: false,
                                enableIMEPersonalizedLearning: false,
                                enableInlinePrediction: false,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                textInputAction: TextInputAction.done,
                                // Delayed OS OTP autofill can restore digits after
                                // the user deletes them. Keep this field manual.
                                autofillHints: null,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 8,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: '000000',
                                  counterText: '',
                                  hintStyle: TextStyle(
                                    color: FiloColors.border,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (!_busy && !_locked) _verify();
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            FiloButton(
                              label: _busy ? 'Please wait…' : 'Verify code',
                              onPressed: _busy || _locked ? null : _verify,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _canResend ? _send : null,
                              child: Text(
                                _seconds > 0
                                    ? 'Resend in ${_seconds}s'
                                    : 'Resend code',
                              ),
                            ),
                            const Text(
                              'No email yet? Check your spam folder.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: FiloColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: FiloPanel(
                          color: _error ? FiloColors.warning : FiloColors.tint,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _error
                                    ? Icons.info_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_message!)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (kDebugMode && session != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: ExpansionTile(
                        title: const Text(
                          'Developer checks',
                          style: TextStyle(fontSize: 13),
                        ),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          Text(
                            'Session ID present: ${_hasSessionId(session.accessToken)}',
                          ),
                          TextButton(
                            onPressed: _busy ? null : _checkReads,
                            child: const Text('Check profile and class access'),
                          ),
                          if (_diagnostic != null)
                            Text(_diagnostic!, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
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
