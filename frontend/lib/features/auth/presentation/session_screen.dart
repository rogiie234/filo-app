import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../onboarding/presentation/account_setup_screen.dart';
import 'session_loading_view.dart';

final otpClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});
  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _challenge, _message;
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
            'We couldn\u2019t send your code. Please try again in a moment.',
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
  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(verifiedUserIdProvider);
    if (verification.asData?.value != null) {
      return const AccountSetupScreen();
    }
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
      body: verification.isLoading
          ? SessionLoadingView(message: _message, error: _error)
          : SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: Mascot(pose: 'curious', size: 156)),
                        const SizedBox(height: 24),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FiloIcon(
                              FiloIcons.shield,
                              size: 18,
                              color: FiloColors.primary,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'A quick security check',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FiloColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          child: const Text(
                            'Let\u2019s make sure\nit\u2019s you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: FiloColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sent
                              ? 'We sent a 6-digit code to $email. Enter it to verify this device. The code expires in 10 minutes.'
                              : 'One little check to keep your account safe. We\u2019ll send a 6-digit code to your Google email.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: FiloColors.secondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: FiloPanel(
                              color: _error
                                  ? FiloColors.warning
                                  : FiloColors.tint,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FiloIcon(
                                    _error
                                        ? FiloIcons.info
                                        : FiloIcons.checkCircle,
                                    color: _error
                                        ? FiloColors.warningInk
                                        : FiloColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_message!)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (verification.hasError)
                          FiloPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const FiloIcon(
                                  FiloIcons.info,
                                  color: FiloColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'We couldn\u2019t check this device. Please try again.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                FiloButton(
                                  label: 'Try again',
                                  onPressed: () =>
                                      ref.invalidate(verifiedUserIdProvider),
                                ),
                              ],
                            ),
                          )
                        else
                          FiloPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!sent) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: FiloColors.tint,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: const FiloIcon(
                                          FiloIcons.email,
                                          color: FiloColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          email,
                                          style: const TextStyle(
                                            color: FiloColors.ink,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  FiloButton(
                                    label: _busy
                                        ? 'Sending code\u2026'
                                        : 'Send code',
                                    busy: _busy,
                                    icon: _busy ? null : FiloIcons.forward,
                                    animateArrow: true,
                                    onPressed: _busy ? null : _send,
                                  ),
                                ] else ...[
                                  const Text(
                                    'Verification code',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: FiloColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AutofillGroup(
                                    child: TextField(
                                      controller: _code,
                                      focusNode: _focus,
                                      enabled: !_busy && !_locked,
                                      keyboardType: TextInputType.number,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      enableIMEPersonalizedLearning: false,
                                      enableInlinePrediction: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      textInputAction: TextInputAction.done,
                                      // Keep OTP entry manual: delayed OS autofill can restore deleted digits.
                                      autofillHints: null,
                                      maxLength: 6,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Verification code',
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.never,
                                        hintText: '000000',
                                        counterText: '',
                                        hintStyle: TextStyle(
                                          color: FiloColors.secondary,
                                        ),
                                      ),
                                      onSubmitted: (_) {
                                        if (!_busy && !_locked) _verify();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FiloButton(
                                    label: _busy
                                        ? 'Please wait\u2026'
                                        : 'Verify code',
                                    busy: _busy,
                                    onPressed: _busy || _locked
                                        ? null
                                        : _verify,
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
                                  const SizedBox(height: 4),
                                  const Text(
                                    'No email yet? Check your spam folder.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: FiloColors.secondary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
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
}
