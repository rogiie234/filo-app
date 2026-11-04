import 'package:filo/features/files/presentation/remote_file_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed preview can retry without saving a local file', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteFilePreview(
          name: 'document.docx',
          mimeType: null,
          browserOnly: false,
          load: () async {
            if (++attempts == 1) throw StateError('Unavailable');
            return Uri.parse('https://example.com/document.docx');
          },
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Could not preview this file. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Open in browser'), findsOneWidget);
  });
}
