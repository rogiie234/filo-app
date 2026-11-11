import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';

class StudyPrivacy {
  StudyPrivacy(this.db);
  final AppDatabase db;
  static const key = 'study_privacy_v1';
  Future<bool> accepted() async =>
      (await db
              .customSelect(
                'SELECT value FROM ai_settings WHERE key=? AND value=?',
                variables: [Variable(key), Variable('accepted')],
              )
              .get())
          .isNotEmpty;
  Future<void> accept() => db.customStatement(
    'INSERT OR REPLACE INTO ai_settings(key,value) VALUES(?,?)',
    [key, 'accepted'],
  );
}

/// Future request handlers must await this gate immediately before dispatch.
Future<bool> ensureStudyPrivacy(
  BuildContext context,
  WidgetRef ref, {
  bool showAgain = false,
}) async {
  try {
    final db = await ref.read(accountDatabaseProvider.future);
    if (db == null || !context.mounted) return false;
    bool current() =>
        context.mounted &&
        ref.read(accountDatabaseProvider).asData?.value == db;
    final privacy = StudyPrivacy(db);
    final accepted = await privacy.accepted();
    if (!current()) return false;
    if (accepted && !showAgain) return true;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Before you use AI Study',
      message: "Your messages and file text are sent to Google for AI processing under the free tier's terms. Personal files may contain private information. Do not add files containing other people's private data.\n\nAI can make mistakes. Check important answers.",
      confirmLabel: 'OK',
      cancelLabel: 'Cancel',
      icon: FiloIcons.sparkle,
    );
    if (!confirmed || !current()) return false;
    await privacy.accept();
    return current();
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not save your privacy choice. Try again.');
    }
    return false;
  }
}
