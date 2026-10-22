import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/sync/outbox_processor.dart';
import '../../../core/sync/sqlite_outbox.dart';
import '../../files/data/files_repository.dart';

import '../../../core/supabase/native_google_sign_in.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import 'drive_api.dart';

final driveBackupProvider = FutureProvider.autoDispose<DriveBackupService?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final userId = await ref.watch(verifiedUserIdProvider.future);
  if (db == null || userId == null || !ref.mounted) {
    return null;
  }
  final google = await ref.watch(nativeGoogleSignInProvider.future);
  if (!ref.mounted) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider);
  final service = DriveBackupService(
    db,
    userId,
    google,
    client,
    () =>
        ref.mounted &&
        client.auth.currentUser?.id == userId &&
        ref.read(verifiedUserIdProvider).asData?.value == userId,
    managedByOutbox: true,
  );
  ref.onDispose(service.dispose);
  await service.initialize();
  if (!ref.mounted) {
    return null;
  }
  return service;
});

/// A durable per-account upload outbox. It runs only while Filo is foregrounded.
/// Files selected through the picker are immutable private queue snapshots.
class DriveBackupService extends ChangeNotifier {
  DriveBackupService(
    this.db,
    this.userId,
    this.google,
    this.client,
    this.accountIsCurrent, {
    this.managedByOutbox = false,
    this.backgroundAccountCheck,
  });
  final AppDatabase db;
  final String userId;
  final GoogleSignIn google;
  final SupabaseClient client;
  final bool Function() accountIsCurrent;
  final bool managedByOutbox;
  final Future<bool> Function()? backgroundAccountCheck;
  final _storage = const FlutterSecureStorage();
  final _connectivity = Connectivity();
  DriveApi? _api;
  StreamSubscription<List<ConnectivityResult>>? _network;
  AppLifecycleListener? _lifecycle;
  Timer? _retry;
  bool _disposed = false, _foreground = true;
  bool enabled = false, wifiOnly = true, busy = false;
  String? googleId, folderId, lastSuccess;
  String message = 'Drive backup is off. Your files stay on this phone.';
  List<Map<String, dynamic>> jobs = [];
  bool get active => !_disposed && accountIsCurrent();
  int get pendingCount => jobs.where((j) => j['status'] != 'complete').length;
  String _sessionKey(String id) => 'filo.drive.$userId.$id';

  void _publish() {
    if (active) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    await reload();
    if (!active) {
      return;
    }
    if (enabled) {
      message = 'Choose files to back up, or retry pending files.';
    }
    _network = _connectivity.onConnectivityChanged.listen((_) => _kick());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _kick();
      },
      onPause: () => _foreground = false,
      onHide: () => _foreground = false,
    );
    _retry = Timer.periodic(const Duration(minutes: 1), (_) => _kick());
    _kick();
  }

  void _kick() {
    if (managedByOutbox) {
      return;
    }
    if (active && enabled && !busy && _foreground && pendingCount > 0) {
      unawaited(run()); // run reports failures without leaking raw exceptions.
    }
  }

  Future<void> queueLibrary() async {
    if (!active || !enabled) {
      return;
    }
    final rows = await (db.select(
      db.localFiles,
    )..where((f) => f.backedUpAt.isNull())).get();
    final store = SqliteOutbox(db);
    for (final row in rows) {
      final event = const Uuid().v5(
        Namespace.url.value,
        'filo-drive:$userId:${row.id}',
      );
      await store.enqueue(event, 'drive_backup', {'file_id': row.id});
    }
  }

  Future<void> markLibrarySuccess() async {
    if (!active || !enabled) {
      return;
    }
    final rows = await db.select(db.localFiles).get();
    if (rows.isEmpty || rows.any((f) => f.backedUpAt == null)) {
      return;
    }
    final latest = rows
        .map((f) => f.backedUpAt!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (lastSuccess == null || latest.isAfter(DateTime.parse(lastSuccess!))) {
      await db.customStatement(
        'UPDATE drive_backup_settings SET last_success=? WHERE id=1',
        [latest.toUtc().toIso8601String()],
      );
    }
    await reload();
  }

  Future<void> backupLocalFile(
    LocalFileRecord row,
    FilesRepository files,
  ) async {
    if (busy || !enabled) {
      throw const DeferredAction();
    }
    try {
      await _checkNetwork();
    } on BackupPaused {
      throw const DeferredAction();
    }
    final local = files.storage.file(row.relativePath);
    final digest = (await md5.bind(local.openRead()).first).toString();
    await enqueue(local, row.name, localFileId: row.id);
    await run();
    final done = jobs
        .where(
          (job) =>
              job['local_file_id'] == row.id &&
              job['digest'] == digest &&
              job['status'] == 'complete',
        )
        .firstOrNull;
    if (done == null) {
      if (!enabled || message.contains('queued')) {
        throw const DeferredAction();
      }
      throw DriveFailure(message);
    }
    if (!active) {
      throw const DeferredAction();
    }
    await (db.update(db.localFiles)..where((f) => f.id.equals(row.id))).write(
      LocalFilesCompanion(
        backedUpAt: Value(DateTime.parse(done['completed_at'] as String)),
      ),
    );
  }

  Future<void> reload() async {
    if (!active) {
      return;
    }
    final settings =
        (await db
                .customSelect(
                  'SELECT * FROM drive_backup_settings WHERE id = 1',
                )
                .getSingle())
            .data;
    if (!active) {
      return;
    }
    enabled = settings['enabled'] == 1;
    wifiOnly = settings['wifi_only'] == 1;
    googleId = settings['google_id'] as String?;
    folderId = settings['folder_id'] as String?;
    lastSuccess = settings['last_success'] as String?;
    jobs =
        (await db
                .customSelect('SELECT * FROM drive_backup_jobs ORDER BY rowid')
                .get())
            .map((row) => Map<String, dynamic>.from(row.data))
            .toList();
    _publish();
  }

  Future<void> _checkNetwork() async {
    if (backgroundAccountCheck != null && !await backgroundAccountCheck!()) {
      throw const BackupPaused();
    }
    if (!active || !enabled || !_foreground) {
      throw const BackupPaused();
    }
    final network = await _connectivity.checkConnectivity();
    if (!active || !enabled || !_foreground) {
      throw const BackupPaused();
    }
    if (!network.any((n) => n != ConnectivityResult.none)) {
      message = 'Backup queued. It will start when you’re connected.';
      throw const BackupPaused();
    }
    if (wifiOnly && !network.contains(ConnectivityResult.wifi)) {
      message = 'Backup queued. It will start when you’re connected to Wi-Fi.';
      throw const BackupPaused();
    }
  }

  Future<GoogleSignInAccount> _account({required bool interactive}) async {
    var account = await google.attemptLightweightAuthentication();
    if (account == null && interactive && active) {
      account = await google.authenticate();
    }
    if (!active) {
      throw const BackupPaused();
    }
    if (account == null) {
      if (backgroundAccountCheck != null) {
        throw const DeferredAction();
      }
      throw const DrivePermissionRequired(
        'Reconnect your Google account to resume Drive backup. Turn backup on to continue.',
      );
    }
    if (account.email.toLowerCase() !=
        client.auth.currentUser?.email?.toLowerCase()) {
      throw const DriveFailure(
        'Use the same Google account you used to sign in to Filo.',
      );
    }
    if (googleId != null && googleId != account.id) {
      throw const DriveFailure('The backup belongs to another Google account.');
    }
    return account;
  }

  Future<void> enable() async {
    if (busy || !active) {
      return;
    }
    busy = true;
    _publish();
    try {
      final account = await _account(interactive: true);
      final api = DriveApi(account, _checkNetwork);
      _api?.close();
      _api = api;
      await api.authorize(interactive: true);
      if (!active) {
        throw const BackupPaused();
      }
      await db.customStatement(
        'UPDATE drive_backup_settings SET enabled=1, google_id=? WHERE id=1',
        [account.id],
      );
      await reload();
      message = 'Drive backup is on. New local files will be backed up.';
      await queueLibrary();
      await _folder(api);
    } on GoogleSignInException {
      message = 'Drive backup is off. Allow Google Drive access to turn it on.';
    } on DriveFailure catch (error) {
      message = error.message;
    } on BackupPaused {
      // Account switched or the screen/session was disposed.
    } catch (_) {
      message =
          'Could not connect to Drive. Check your connection and try again.';
    } finally {
      busy = false;
      _publish();
    }
    _kick();
  }

  Future<void> disable() async {
    if (!active) {
      return;
    }
    enabled = false;
    _api?.close();
    _api = null;
    await db.customStatement(
      'UPDATE drive_backup_settings SET enabled=0 WHERE id=1',
    );
    await reload();
    message =
        'Drive backup is off. Pending files are paused; Drive copies stay.';
    _publish();
  }

  Future<void> setWifiOnly(bool value) async {
    if (!active || busy) {
      return;
    }
    await db.customStatement(
      'UPDATE drive_backup_settings SET wifi_only=? WHERE id=1',
      [value ? 1 : 0],
    );
    await reload();
    _kick();
  }

  /// Public integration point for a future local-file library.
  Future<void> enqueue(File source, String name, {String? localFileId}) async {
    if (!active || !enabled || busy) {
      return;
    }
    busy = true;
    _publish();
    File? snapshot;
    var persisted = false;
    try {
      await reload();
      if (localFileId != null &&
          jobs.any((job) => job['local_file_id'] == localFileId)) {
        return;
      }
      final id = localFileId == null
          ? const Uuid().v4()
          : const Uuid().v5(
              Namespace.url.value,
              'filo-drive-job:$userId:$localFileId',
            );
      final root = await getApplicationSupportDirectory();
      final directory = Directory(p.join(root.path, 'drive_backup', userId));
      await directory.create(recursive: true);
      snapshot = await source.copy(p.join(directory.path, id));
      final size = await snapshot.length();
      final digest = (await md5.bind(snapshot.openRead()).first).toString();
      if (!active) {
        throw const BackupPaused();
      }
      // Library uploads are identified by local-file ID, not by content hash.
      await db.customStatement(
        '''
        INSERT OR IGNORE INTO drive_backup_jobs
          (id,name,local_path,size,digest,local_file_id) VALUES (?,?,?,?,?,?)
      ''',
        [id, p.basename(name), snapshot.path, size, digest, localFileId],
      );
      // Once INSERT returns, logout must not delete a referenced queue copy.
      persisted = true;
      if (active) {
        await reload();
        persisted = jobs.any((job) => job['id'] == id);
      }
      message = persisted
          ? 'Backup queued. Keep Filo open to upload.'
          : 'This file is already queued or backed up.';
    } on DriveFailure catch (error) {
      message = error.message;
    } on BackupPaused {
      // Do not publish old-account data.
    } catch (_) {
      message = 'Could not queue this file. Check free space and try again.';
    } finally {
      if (!persisted && snapshot != null && await snapshot.exists()) {
        await snapshot.delete();
      }
      busy = false;
      _publish();
    }
    _kick();
  }

  Future<DriveApi> _connectedApi() async {
    if (_api != null) {
      return _api!;
    }
    final account = await _account(interactive: false);
    final api = DriveApi(account, _checkNetwork);
    _api = api;
    await api.authorize(interactive: false);
    return api;
  }

  Future<String> _folder(DriveApi api) async {
    if (folderId == null) {
      final id = await api.generateId();
      if (!active) {
        throw const BackupPaused();
      }
      await db.customStatement(
        'UPDATE drive_backup_settings SET folder_id=? WHERE id=1',
        [id],
      );
      folderId = id;
    }
    final existing = await api.metadata(folderId!);
    if (existing.status == 404) {
      await api.createFolder(folderId!);
    } else {
      api.requireSuccess(existing);
      if (existing.json['trashed'] == true ||
          existing.json['mimeType'] != 'application/vnd.google-apps.folder') {
        throw const DriveFailure(
          'Restore the Filo Backup folder in Drive, then try again.',
        );
      }
    }
    return folderId!;
  }

  Future<void> run() async {
    if (!active || busy || !enabled || !_foreground) {
      return;
    }
    busy = true;
    _publish();
    try {
      await _checkNetwork();
      await reload();
      if (pendingCount == 0) {
        message = 'Choose files to back up.';
        return;
      }
      final api = await _connectedApi();
      final folder = await _folder(api);
      for (final job in jobs.where((j) => j['status'] != 'complete').toList()) {
        await _upload(api, folder, job);
      }
      if (!active) {
        throw const BackupPaused();
      }
      // Whole selected queue completed, not the entire phone/library.
      if (!managedByOutbox) {
        await db.customStatement(
          'UPDATE drive_backup_settings SET last_success=? WHERE id=1',
          [DateTime.now().toUtc().toIso8601String()],
        );
      }
      message = 'Backup complete.';
    } on DeferredAction {
      message = 'Backup queued. Open Filo to sign in and resume backup.';
    } on BackupPaused {
      // Durable jobs and secure upload sessions remain ready to resume.
    } on DrivePermissionRequired catch (error) {
      message = error.message;
      if (active) {
        await db.customStatement(
          'UPDATE drive_backup_settings SET enabled=0 WHERE id=1',
        );
      }
      _api?.close();
      _api = null;
    } on DriveFailure catch (error) {
      message = error.message;
    } on GoogleSignInException {
      message = 'Allow Google Drive access again to resume backup.';
    } catch (_) {
      message = enabled
          ? 'Backup failed. Your files are still on this phone. Try again.'
          : 'Drive backup is off. Pending files are paused; Drive copies stay.';
    } finally {
      busy = false;
      if (active) {
        try {
          await reload();
        } catch (_) {
          // Account database may close during logout; the persisted queue stays.
        }
        _publish();
      }
    }
  }

  Future<void> _upload(
    DriveApi api,
    String folder,
    Map<String, dynamic> job,
  ) async {
    await _checkNetwork();
    final id = job['id'] as String;
    final file = File(job['local_path'] as String);
    final size = job['size'] as int;
    if (!await file.exists()) {
      throw const DriveFailure('A queued file is missing from this phone.');
    }
    var fileId = job['file_id'] as String?;
    if (fileId == null) {
      fileId = await api.generateId();
      if (!active) {
        throw const BackupPaused();
      }
      await db.customStatement(
        'UPDATE drive_backup_jobs SET file_id=? WHERE id=?',
        [fileId, id],
      );
    }
    // Reconcile uncertain completion before resending; the same ID is reused.
    final existing = await api.metadata(fileId);
    if (size == 0 && existing.status == 404) {
      await api.createEmptyFile(
        fileId,
        folder,
        job['name'] as String,
        job['digest'] as String,
      );
      await _verifyComplete(api, fileId, job, 0);
      return;
    }
    if (existing.status != 404) {
      api.requireSuccess(existing);
      if (existing.json['trashed'] == true) {
        throw const DriveFailure('Restore the backup file in Drive and retry.');
      }
      final properties = existing.json['appProperties'] as Map?;
      if (properties?['filoBackup'] != 'v1' ||
          properties?['digest'] != job['digest']) {
        throw const DriveFailure('This Drive file is not the queued backup.');
      }
      if (existing.json['size'] == '$size' &&
          (existing.json['md5Checksum'] == job['digest'] || size == 0)) {
        await _complete(job, 0);
        return;
      }
    }
    final timer = Stopwatch()..start();
    final location = await _storage.read(key: _sessionKey(id));
    Uri? session = location == null ? null : Uri.tryParse(location);
    var offset = 0;
    if (session != null) {
      final status = await api.uploadStatus(session, size);
      if (status.status == 200 || status.status == 201) {
        await _verifyComplete(api, fileId, job, timer.elapsedMilliseconds);
        return;
      } else if (status.status == 308) {
        offset = DriveApi.receivedBytes(status);
      } else if (status.status == 404 || status.status == 410) {
        session = null;
        await _storage.delete(key: _sessionKey(id));
      } else {
        api.requireSuccess(status);
      }
    }
    if (session == null) {
      session = await api.startUpload(
        fileId: fileId,
        folderId: folder,
        name: job['name'] as String,
        digest: job['digest'] as String,
        size: size,
        update: existing.status != 404,
      );
      await _storage.write(key: _sessionKey(id), value: session.toString());
    }
    final input = await file.open();
    try {
      while (offset < size) {
        await _checkNetwork();
        message = 'Backing up ${job['name']}…';
        _publish();
        await input.setPosition(offset);
        final chunk = await input.read(math.min(1024 * 1024, size - offset));
        if (chunk.isEmpty) {
          throw const DriveFailure('The queued file changed.');
        }
        final response = await api.uploadChunk(session, chunk, offset, size);
        if (response.status == 200 || response.status == 201) {
          await _verifyComplete(api, fileId, job, timer.elapsedMilliseconds);
          return;
        }
        if (response.status != 308) api.requireSuccess(response);
        final next = DriveApi.receivedBytes(response);
        if (next <= offset || next > size) {
          throw const DriveFailure('Upload paused. Try again to resume.');
        }
        offset = next;
        if (!active) {
          throw const BackupPaused();
        }
        await db.customStatement(
          'UPDATE drive_backup_jobs SET uploaded=? WHERE id=?',
          [offset, id],
        );
        job['uploaded'] = offset;
        _publish();
      }
      // A completed byte range still needs provider completion evidence.
      await _verifyComplete(api, fileId, job, timer.elapsedMilliseconds);
    } finally {
      await input.close();
    }
  }

  Future<void> _verifyComplete(
    DriveApi api,
    String fileId,
    Map<String, dynamic> job,
    int elapsed,
  ) async {
    final response = await api.metadata(fileId);
    api.requireSuccess(response);
    if (response.json['trashed'] == true ||
        response.json['size'] != '${job['size']}' ||
        (response.json['md5Checksum'] != job['digest'] && job['size'] != 0)) {
      throw const DriveFailure(
        'Drive has not confirmed the complete file yet.',
      );
    }
    await _complete(job, elapsed);
  }

  Future<void> _complete(Map<String, dynamic> job, int elapsed) async {
    if (!active) {
      throw const BackupPaused();
    }
    await db.customStatement(
      '''
      UPDATE drive_backup_jobs SET status='complete', uploaded=size,
        completed_at=?, elapsed_ms=? WHERE id=?
    ''',
      [DateTime.now().toUtc().toIso8601String(), elapsed, job['id']],
    );
    await _storage.delete(key: _sessionKey(job['id'] as String));
    // Remove only the private queue snapshot; never the picked source file.
    final snapshot = File(job['local_path'] as String);
    if (await snapshot.exists()) {
      await snapshot.delete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _api?.close();
    _retry?.cancel();
    _lifecycle?.dispose();
    unawaited(_network?.cancel());
    super.dispose();
  }
}
