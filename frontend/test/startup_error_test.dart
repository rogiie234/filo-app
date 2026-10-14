import 'package:filo/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing configuration displays an actionable screen', (
    tester,
  ) async {
    await app.main();
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
