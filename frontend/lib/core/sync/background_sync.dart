import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/local/user_database_manager.dart';
import '../../features/drive_backup/data/drive_backup_service.dart';
import '../../features/files/data/file_storage.dart';
import '../../features/files/data/files_repository.dart';
import '../config/app_config.dart';
import 'sync_coordinator.dart';

@pragma('vm:entry-point')
void filoBackgroundDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    const storage = FlutterSecureStorage();
    final id = data?['user_id'] as String?;
    if (id == null || await storage.read(key: 'filo.sync.active') != id) {
      return true;
    }
    final manager = UserDatabaseManager();
    DriveBackupService? backup;
    SyncCoordinator? coordinator;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      final client = Supabase.instance.client;
      if (client.auth.currentUser?.id != id) {
        return true;
      }
      if (await client.rpc('is_session_verified') != true) {
        return false;
      }
      final db = await manager.openForUser(id);
      final files = FilesRepository(
        db,
        await FileStorage.forAccount(id, cleanTemporary: false),
      );
      var current = true;
      bool active() => current && client.auth.currentUser?.id == id;
      try {
        final google = GoogleSignIn.instance;
        await google.initialize(serverClientId: AppConfig.googleWebClientId);
        backup = DriveBackupService(
          db,
          id,
          google,
          client,
          active,
          managedByOutbox: true,
          backgroundAccountCheck: () async =>
              await storage.read(key: 'filo.sync.active') == id,
        );
        await backup.reload();
      } catch (_) {
        backup = null;
      }
      coordinator = SyncCoordinator(
        db,
        client,
        id,
        active,
        files: files,
        backup: backup,
        currentAccountCheck: () async =>
            await storage.read(key: 'filo.sync.active') == id,
      );
      await coordinator.run();
      current = false;
      return coordinator.errors.isEmpty;
    } catch (_) {
      return false;
    } finally {
      coordinator?.dispose();
      backup?.dispose();
      await manager.close();
    }
  });
}

Future<void> initializeBackgroundSync() async {
  await Workmanager().initialize(filoBackgroundDispatcher);
}

Future<void> scheduleBackgroundSync(String userId) async {
  await const FlutterSecureStorage().write(
    key: 'filo.sync.active',
    value: userId,
  );
  await Workmanager().registerPeriodicTask(
    'filo.sync',
    'filo.sync',
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    inputData: {'user_id': userId},
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

Future<void> stopBackgroundSync() async {
  await const FlutterSecureStorage().delete(key: 'filo.sync.active');
  await Workmanager().cancelByUniqueName('filo.sync');
}
