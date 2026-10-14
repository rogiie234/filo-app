import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// The auth owner must await openForUser on login and close on logout.
/// Repositories must use the returned database for the current account.
class UserDatabaseManager {
  UserDatabaseManager({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  AppDatabase? _database;
  String? _userId;
  Future<void> _pending = Future.value();

  static String filenameForUser(String userId) {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
    // Supabase UUIDs remain readable; encode other IDs without collisions.
    final name = RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)
        ? userId
        : '~${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';
    return '$name.sqlite';
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<AppDatabase> openForUser(String userId) => _serialize(() async {
    final filename = filenameForUser(userId);
    if (_userId == userId && _database != null) return _database!;
    await _closeCurrent();
    final root = await _directoryProvider();
    final directory = Directory(p.join(root.path, 'databases'));
    await directory.create(recursive: true);
    final database = AppDatabase(
      NativeDatabase.createInBackground(File(p.join(directory.path, filename))),
    );
    try {
      // Force the lazy connection to create and validate the schema now.
      await database.customSelect('SELECT 1').get();
    } catch (_) {
      await database.close();
      rethrow;
    }
    _database = database;
    _userId = userId;
    return database;
  });

  Future<void> _closeCurrent() async {
    final database = _database;
    _database = null;
    _userId = null;
    await database?.close();
  }

  Future<void> close() => _serialize(_closeCurrent);
}
