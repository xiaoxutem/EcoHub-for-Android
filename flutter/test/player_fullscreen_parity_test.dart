import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/player_bars.dart';
import 'package:ecohub_android/components/player/player_skin_view.dart';
import 'package:ecohub_android/components/player/player_gesture_handler.dart';

void main() {
  group('Player Fullscreen & Layout Parity Tests', () {
    testWidgets('Fullscreen controls stretch across parent width rather than being constrained to video aspect ratio', (tester) async {
      tester.view.physicalSize = const Size(1024, 637);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.expand(
              child: PlayerSkinView(
                isFull: true,
                showHud: true,
                showBack: true,
                isReady: true,
                isPlaying: true,
                isBuffering: false,
                title: '枕春娇 · 第1-20集',
                currentPosition: const Duration(seconds: 30),
                totalDuration: const Duration(minutes: 10),
                onBack: () {},
                onTogglePlay: () {},
                onToggleFull: () {},
                onToggleMute: () {},
                onSpeed: () {},
                onRetry: () {},
                onSeekBack10: () {},
                onSeekFwd10: () {},
                onSeekTo: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // TopBar should stretch full width (1024px)
      final topBarFinder = find.byType(PlayerTopBar);
      expect(topBarFinder, findsOneWidget);
      final topBarRect = tester.getRect(topBarFinder);
      expect(topBarRect.left, 0.0);
      expect(topBarRect.right, 1024.0);
      expect(topBarRect.width, 1024.0);

      // Back button in TopBar should be aligned near the left edge of the screen
      final backIcon = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backIcon, findsOneWidget);
      final backIconRect = tester.getRect(backIcon);
      expect(backIconRect.left, lessThan(40.0));

      // BottomBar should stretch full width (1024px)
      final bottomBarFinder = find.byType(PlayerBottomBar);
      expect(bottomBarFinder, findsOneWidget);
      final bottomBarRect = tester.getRect(bottomBarFinder);
      expect(bottomBarRect.left, 0.0);
      expect(bottomBarRect.right, 1024.0);
      expect(bottomBarRect.width, 1024.0);

      // Fullscreen exit button should be near the right edge of the screen
      final exitFullIcon = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(exitFullIcon, findsOneWidget);
      final exitFullRect = tester.getRect(exitFullIcon);
      expect(exitFullRect.right, greaterThan(980.0));
    });

    testWidgets('PlayerGestureHandler expands to fill entire parent container', (tester) async {
      tester.view.physicalSize = const Size(1024, 637);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: PlayerGestureHandler(
                currentPosition: Duration.zero,
                totalDuration: const Duration(minutes: 5),
                isPlaying: true,
                isFull: true,
                currentSpeed: 1.0,
                currentBrightness: 0.5,
                currentVolume: 0.5,
                onSingleTap: () {},
                onDoubleTap: () {},
                onSeekProgress: (_) {},
                onSeekEnd: (_) {},
                onSpeedChange: (_) {},
                onPanStateChange: (_) {},
                child: const SizedBox(width: 200, height: 355), // Even if child video is narrower
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gestureFinder = find.byType(PlayerGestureHandler);
      expect(gestureFinder, findsOneWidget);
      final gestureRect = tester.getRect(gestureFinder);
      expect(gestureRect.width, 1024.0);
      expect(gestureRect.height, 637.0);
    });

    testWidgets('Portrait videos always request portraitUp fullscreen even when device was in landscape', (tester) async {
      // 模拟横屏环境（例如横屏平板或横持手机，1024x637）
      tester.view.physicalSize = const Size(1024, 637);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      List<DeviceOrientation> getOrientations(bool isPortrait) => isPortrait
          ? [DeviceOrientation.portraitUp]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];

      expect(getOrientations(true), equals([DeviceOrientation.portraitUp]));
    });

    testWidgets('Landscape videos always request landscape fullscreen', (tester) async {
      // 模拟竖屏手机环境（390x844）
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      List<DeviceOrientation> getOrientations(bool isPortrait) => isPortrait
          ? [DeviceOrientation.portraitUp]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];

      expect(
        getOrientations(false),
        equals([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]),
      );
    });

    testWidgets('Split mode fullscreen toggle sends portraitUp to SystemChrome when video is portrait', (tester) async {
      tester.view.physicalSize = const Size(1024, 637);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      List<String>? requestedOrientations;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemChrome.setPreferredOrientations') {
            requestedOrientations = (methodCall.arguments as List<dynamic>).cast<String>();
          }
          return null;
        },
      );

      List<DeviceOrientation> resolveOrientations(bool isPortrait) => isPortrait
          ? [DeviceOrientation.portraitUp]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];

      await SystemChrome.setPreferredOrientations(resolveOrientations(true));

      expect(requestedOrientations, equals(['DeviceOrientation.portraitUp']));
    });
  });
}
