import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

/// Initialization is cached across widget rebuilds and account switches.
final nativeGoogleSignInProvider = FutureProvider<GoogleSignIn>((ref) async {
  final clientId = AppConfig.googleWebClientId.trim();
  if (!clientId.endsWith('.apps.googleusercontent.com')) {
    throw StateError(
      'Configure GOOGLE_WEB_CLIENT_ID in the development settings.',
    );
  }
  final google = GoogleSignIn.instance;
  await google.initialize(serverClientId: clientId);
  return google;
});
