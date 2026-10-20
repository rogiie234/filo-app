import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/sync/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
