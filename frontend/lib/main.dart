import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show
        LicenseEntryWithLineBreaks,
        LicenseRegistry,
        kIsWeb,
        defaultTargetPlatform,
        TargetPlatform,
        kDebugMode,
        debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/config/app_config.dart';
import 'core/sync/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/phosphor/LICENSE',
    );
    yield LicenseEntryWithLineBreaks(['Phosphor Icons'], license);
  });
  try {
    AppConfig.validate();
  } on StateError catch (error) {
    runApp(StartupErrorApp(message: error.message.toString()));
    return;
  }
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (_) {
    runApp(
      const StartupErrorApp(
        message:
            'Could not start Filo. Check your connection and restart the app.',
      ),
    );
    return;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      if (kDebugMode) debugPrint('[Filo push] Firebase initialization failed');
      // Inbox and sign-in remain available if push initialization fails.
    }
  }
  try {
    await initializeBackgroundSync();
  } catch (_) {
    /* Foreground sync remains available. */
  }
  runApp(const ProviderScope(child: App()));
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filo could not start',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text(
                  'For development, restart with:\n'
                  'flutter run --dart-define-from-file=.env.dev.json',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
