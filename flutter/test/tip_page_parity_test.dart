import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/pages/tip_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TipPage Parity Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('TipPage message text is centered and has matching padding', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: TipPage(),
        ),
      );
      // Wait for async loadConfig to settle/fail gracefully
      await tester.pumpAndSettle();

      final textFinder = find.text('如果这个站对你有帮助，欢迎请作者喝杯咖啡');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.textAlign, TextAlign.center);

      // Verify Center widget is an ancestor of the text
      final centerFinder = find.ancestor(of: textFinder, matching: find.byType(Center));
      expect(centerFinder, findsWidgets);

      // Verify the horizontal center of the text matches the screen center (200.0)
      final textCenter = tester.getCenter(textFinder);
      expect(textCenter.dx, closeTo(200.0, 1.0));

      // Verify padding is EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16)
      final paddingFinder = find.ancestor(of: textFinder, matching: find.byType(Padding)).first;
      final paddingWidget = tester.widget<Padding>(paddingFinder);
      expect(paddingWidget.padding, const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16));
    });
  });
}
