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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _signingIn = false;

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
                          _signingIn || connectivity.asData?.value != true
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
    if (ref.read(connectivityProvider).asData?.value != true || _signingIn) {
      return;
    }
    setState(() => _signingIn = true);
    try {
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
        showMessage(
          context,
          'Google sign-in failed. Check the Android OAuth configuration and try again.',
        );
      }
    } on SocketException {
      _connectionFailure();
    } on TimeoutException {
      _connectionFailure();
    } on AuthRetryableFetchException {
      _connectionFailure();
    } on StateError catch (error) {
      if (mounted) showMessage(context, error.message.toString());
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _connectionFailure() {
    if (!mounted) return;
    ref.invalidate(connectivityProvider);
    showMessage(
      context,
      'Could not reach sign-in. Check your internet connection and try again.',
    );
  }
}
