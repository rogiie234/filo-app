import 'package:filo/core/orientation_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <List<String>>[];
  setUp(() {
    requests.clear();
    FiloOrientationPolicy.examProtected = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  testWidgets(
    'viewer, popup, covering page/reset, latest policy and exam priority',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = RouteObserver<PageRoute<dynamic>>();
      await FiloOrientationPolicy.refresh();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: const Scaffold(),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const FiloFileViewerOrientation(
            child: Scaffold(body: Text('Viewer')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last, isEmpty);
      navigator.currentState!.push(
        DialogRoute<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(title: Text('File options')),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last, isEmpty);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Ordinary page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(requests.last, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await FiloOrientationPolicy.refresh();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      final viewer = Object();
      FiloOrientationPolicy.viewer(viewer, true);
      FiloOrientationPolicy.viewer(viewer, false);
      await FiloOrientationPolicy.refresh();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      FiloOrientationPolicy.viewer(viewer, true);
      FiloOrientationPolicy.examProtected = true;
      await FiloOrientationPolicy.refresh();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      FiloOrientationPolicy.examProtected = false;
      await FiloOrientationPolicy.refresh();
      expect(requests.last, isEmpty);
      FiloOrientationPolicy.viewer(viewer, false);
      await FiloOrientationPolicy.refresh();
    },
  );
}
