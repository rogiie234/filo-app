import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/native_google_sign_in.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/animation_constants.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_artwork.dart';
import '../application/sign_in_clock.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _signingIn = false;
  bool _checkingClock = false, _returningFromSettings = false;
  bool _clockIncorrect = false;
  String? _failure;
  late final AppLifecycleListener _lifecycle;
  static const _clockMessage =
      'Your phone\'s date or time appears incorrect, which can prevent sign-in. Turn on automatic date and time in your phone\'s Settings, then try again.';
  static const _clockHint =
      'If this keeps happening, check that automatic date and time is enabled on your phone.';

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_returningFromSettings) {
          _returningFromSettings = false;
          unawaited(_recheckClock());
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    _returningFromSettings = true;
    try {
      await ref.read(openDateTimeSettingsProvider)();
    } catch (_) {
      _returningFromSettings = false;
      if (mounted)
        setState(
          () => _failure = 'Open your phone\'s Settings, choose Date & time, and turn on automatic date and time.',
        );
    }
  }

  Future<void> _recheckClock() async {
    if (!mounted || _signingIn || _checkingClock) return;
    setState(() => _checkingClock = true);
    final mismatch = await ref.read(signInClockCheckProvider)();
    if (!mounted) return;
    setState(() {
      _checkingClock = false;
      _clockIncorrect = mismatch == true;
      _failure = mismatch == true
          ? _clockMessage
          : mismatch == false
          ? 'Date and time look correct. Try signing in again.'
          : 'Could not check your date and time. Check your connection and try again.';
    });
  }

  void _showFailure(String message) {
    if (mounted)
      setState(() {
        _clockIncorrect = false;
        _failure = message;
      });
  }

  Widget _entrance(Widget child, {Duration delay = Duration.zero}) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate()
        .fadeIn(
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        )
        .moveY(
          begin: FiloAnimation.textRise,
          end: 0,
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        );
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final offline = connectivity.asData?.value == false;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Brand()),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('About Filo'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    Mascot(size: entryMascotSize(context)),
                    const SizedBox(height: 32),
                    _entrance(
                      Text(
                        'Hello,\ncurious mind.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _entrance(
                      const Text(
                        'A little curiosity goes a long way.\nLet\u2019s see where yours takes you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FiloColors.secondary,
                          fontSize: 16,
                        ),
                      ),
                      delay: FiloAnimation.subtitleDelay,
                    ),
                    if (_failure != null) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          children: [
                            if (_clockIncorrect)
                              Text(
                                'Check your phone\'s date and time',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 8),
                            Text(_failure!, textAlign: TextAlign.center),
                            if (!_clockIncorrect) ...[
                              const SizedBox(height: 8),
                              const Text(
                                _clockHint,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FiloButton(
                        label: 'Open settings',
                        secondary: true,
                        onPressed: _signingIn || _checkingClock
                            ? null
                            : _openSettings,
                      ),
                      const SizedBox(height: 12),
                      FiloButton(
                        label: _checkingClock
                            ? 'Checking date and time...'
                            : 'Try again',
                        busy: _checkingClock,
                        onPressed:
                            _signingIn ||
                                _checkingClock ||
                                connectivity.asData?.value != true
                            ? null
                            : _signIn,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Column(
                children: [
                  _entrance(
                    FiloButton(
                      label: _signingIn
                          ? 'Signing in\u2026'
                          : 'Continue with Google',
                      secondary: true,
                      busy: _signingIn,
                      leading: Image.asset(
                        'assets/brand/google-g.png',
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                      onPressed:
                          _signingIn ||
                              _checkingClock ||
                              connectivity.asData?.value != true
                          ? null
                          : _signIn,
                    ),
                    delay: FiloAnimation.buttonEntranceDelay,
                  ),
                  if (offline)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You\u2019re offline. Connect to the internet to sign in.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (connectivity.isLoading)
                    const Text('Checking your connection\u2026'),
                  if (connectivity.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(connectivityProvider),
                      child: const Text(
                        'Could not check your connection. Try again',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (ref.read(connectivityProvider).asData?.value != true ||
        _signingIn ||
        _checkingClock) {
      return;
    }
    setState(() {
      _signingIn = true;
      _failure = null;
      _clockIncorrect = false;
    });
    try {
      final mismatch = await ref.read(signInClockCheckProvider)();
      if (!mounted) return;
      if (mismatch == true) {
        setState(() {
          _clockIncorrect = true;
          _failure = _clockMessage;
        });
        return;
      }
      final client = ref.read(supabaseClientProvider);
      final google = await ref.read(nativeGoogleSignInProvider.future);
      await google.signOut();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not provide a login token.');
      }
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      // The existing session gate performs the trusted-device/OTP check.
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        _showFailure('Could not sign in with Google. Try again.');
      }
    } on SocketException {
      _connectionFailure();
    } on TimeoutException {
      _connectionFailure();
    } on AuthRetryableFetchException {
      _connectionFailure();
    } on StateError catch (error) {
      _showFailure(error.message.toString());
    } catch (_) {
      if (mounted) {
        _showFailure('Could not sign in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _connectionFailure() {
    if (!mounted) return;
    ref.invalidate(connectivityProvider);
    _showFailure(
      'Could not reach sign-in. Check your internet connection and try again.',
    );
  }
}
