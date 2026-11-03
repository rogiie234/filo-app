import 'package:flutter/services.dart';
import 'package:filo/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing configuration displays an actionable screen', (
    tester,
  ) async {
    final orientations = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await app.main();
    expect(orientations, [
      ['DeviceOrientation.portraitUp'],
    ]);
    await tester.pump();
    expect(find.text('Filo could not start'), findsOneWidget);
    expect(find.textContaining('Provide ENV'), findsOneWidget);
    expect(
      find.textContaining('--dart-define-from-file=.env.dev.json'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
