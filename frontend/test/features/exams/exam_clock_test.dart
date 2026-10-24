import 'package:flutter_test/flutter_test.dart';

import 'exam_test_support.dart';

void main() {
  test('midpoint offset includes half the trip at response receipt', () {
    final time = FakeExamTime();
    time.wall = examEpoch.subtract(const Duration(minutes: 2));
    time.elapsed = const Duration(seconds: 4);
    time.clock.synchronize(
      serverNow: examEpoch,
      deadline: examEpoch.add(const Duration(minutes: 10)),
      requestWall: time.wall,
      requestElapsed: Duration.zero,
      responseElapsed: time.elapsed,
    );
    expect(time.clock.offset, const Duration(seconds: 118));
    expect(time.clock.serverNow, examEpoch.add(const Duration(seconds: 2)));
    expect(time.clock.remaining, const Duration(minutes: 9, seconds: 58));
  });
  test(
    'phone wall clock moving forward and backward cannot alter live countdown',
    () {
      final time = FakeExamTime()..synchronize();
      time.wall = time.wall.add(const Duration(days: 2));
      time.elapsed += const Duration(seconds: 30);
      expect(time.clock.remaining, const Duration(minutes: 9, seconds: 30));
      time.wall = time.wall.subtract(const Duration(days: 4));
      time.elapsed += const Duration(seconds: 30);
      expect(time.clock.remaining, const Duration(minutes: 9));
    },
  );
  test(
    'editing stops at deadline and sends stop exactly at plus 14 seconds',
    () {
      final time = FakeExamTime()..synchronize();
      time.elapsed = const Duration(minutes: 10);
      expect(time.clock.remaining, Duration.zero);
      expect(time.clock.canEdit, isFalse);
      expect(time.clock.canSend, isTrue);
      time.elapsed += const Duration(seconds: 14);
      expect(time.clock.canSend, isFalse);
    },
  );
  test(
    'restart estimate cannot authorize sends and refresh replaces estimate',
    () {
      final time = FakeExamTime();
      time.wall = examEpoch.add(const Duration(minutes: 3));
      time.clock.restore(
        serverAtReceipt: examEpoch,
        deviceAtReceipt: examEpoch,
        deadline: examEpoch.add(const Duration(minutes: 10)),
      );
      expect(time.clock.remaining, const Duration(minutes: 7));
      expect(time.clock.verified, isFalse);
      expect(time.clock.canEdit, isFalse);
      expect(time.clock.expired, isFalse);
      expect(time.clock.canSend, isFalse);
      time.wall = examEpoch.add(const Duration(days: 4));
      expect(time.clock.remaining, const Duration(minutes: 7));
      time.synchronize();
      expect(time.clock.verified, isTrue);
      expect(time.clock.canEdit, isTrue);
      expect(time.clock.remaining, const Duration(minutes: 10));
    },
  );
  test(
    'unverified zero is not expiry and loss copy follows verified cutoff',
    () {
      final time = FakeExamTime()
        ..wall = examEpoch.add(const Duration(days: 1));
      time.clock.restore(
        serverAtReceipt: examEpoch,
        deviceAtReceipt: examEpoch,
        deadline: examEpoch.add(const Duration(minutes: 10)),
      );
      expect(time.clock.remaining, Duration.zero);
      expect(time.clock.expired, isFalse);
      expect(time.clock.canEdit, isFalse);
      expect(time.clock.acceptanceClosed, isFalse);
      time.synchronize();
      time.elapsed += const Duration(minutes: 10, seconds: 15);
      expect(time.clock.expired, isTrue);
      expect(time.clock.acceptanceClosed, isFalse);
      expect(time.clock.timeoutMessage, contains('will be lost'));
      time.elapsed += const Duration(microseconds: 1);
      expect(time.clock.acceptanceClosed, isTrue);
      expect(time.clock.timeoutMessage, contains('are lost'));
    },
  );
}
