import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/native_google_sign_in.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/preview_controller.dart';
import '../../classes/domain/prototype_models.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _signingIn = false;

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
                    const Mascot(size: 240),
                    const SizedBox(height: 32),
                    Text(
                      'Hello,\ncurious mind.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A little curiosity goes a long way.\nLet’s see where yours takes you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FiloColors.secondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  FiloButton(
                    label: _signingIn ? 'Signing in…' : 'Continue with Google',
                    secondary: true,
                    icon: Icons.login_rounded,
                    onPressed: _signingIn || connectivity.asData?.value != true
                        ? null
                        : _signIn,
                  ),
                  if (offline)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You’re offline. Connect to the internet to sign in.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (connectivity.isLoading)
                    const Text('Checking your connection…'),
                  if (connectivity.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(connectivityProvider),
                      child: const Text(
                        'Could not check your connection. Try again',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _explore(context, ref),
                    child: const Text(
                      'Explore the preview',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

  Future<void> _explore(BuildContext context, WidgetRef ref) async {
    final role = await showModalBottomSheet<PreviewRole>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take a look around.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a view. Sample changes stay in this session only.',
                style: TextStyle(color: FiloColors.secondary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.school_rounded),
                title: const Text('Student'),
                subtitle: const Text(
                  'Browse classes, materials, and classwork',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.pop(context, PreviewRole.student),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text('Instructor'),
                subtitle: const Text('Try creating a post and an assessment'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.pop(context, PreviewRole.instructor),
              ),
            ],
          ),
        ),
      ),
    );
    if (role != null && context.mounted) {
      ref.read(previewProvider.notifier).chooseRole(role);
      context.go('/classes');
    }
  }
}
