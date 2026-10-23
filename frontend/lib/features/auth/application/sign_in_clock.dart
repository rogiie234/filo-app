import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// A diagnosis only; never changes token validation or the exam clock.
bool? signInClockMismatch(
  String? serverDate,
  DateTime requestWall,
  Duration roundTrip, {
  String? age,
}) {
  if (serverDate == null ||
      roundTrip > const Duration(seconds: 5) ||
      age != null && int.tryParse(age) != 0)
    return null;
  try {
    final midpoint = requestWall.toUtc().add(
      Duration(microseconds: roundTrip.inMicroseconds ~/ 2),
    );
    return HttpDate.parse(serverDate).difference(midpoint).abs() >
        const Duration(minutes: 5);
  } on HttpException {
    return null;
  }
}

final signInClockCheckProvider = Provider<Future<bool?> Function()>(
  (ref) => () async {
    final uri = Uri.tryParse(AppConfig.supabaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final client = http.Client();
    final wall = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    try {
      final request = http.Request('GET', uri.resolve('/auth/v1/health'))
        ..followRedirects = false;
      request.headers.addAll({
        'apikey': AppConfig.supabaseAnonKey,
        'cache-control': 'no-cache',
      });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return signInClockMismatch(
        response.headers['date'],
        wall,
        stopwatch.elapsed,
        age: response.headers['age'],
      );
    } catch (_) {
      // Wrong dates can also break TLS; that is insufficient evidence of clock drift.
      return null;
    } finally {
      client.close();
    }
  },
);

final openDateTimeSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await const MethodChannel('com.filo.filo/device_time')
        .invokeMethod<void>('openSettings');
  },
);
