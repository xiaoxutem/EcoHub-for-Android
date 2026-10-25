import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/services/pip_manager.dart';
import 'package:ecohub_android/components/player/player_pip_coordinator.dart';
import 'package:ecohub_android/components/player/player_video_surface.dart';
import 'package:ecohub_android/components/player/video_player_widget.dart';
import 'package:ecohub_android/pages/custom_player_page.dart';
import 'package:ecohub_android/utils/app_settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = [];
  bool mockSupported = true;

  setUp(() {
    calls.clear();
    mockSupported = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ecohub.ecohub/pip'), (call) async {
      calls.add(call);
      if (call.method == 'isPipSupported') return mockSupported;
      if (call.method == 'enterPip') return true;
      if (call.method == 'setAutoPip') return true;
      if (call.method == 'updatePipActions') return true;
      if (call.method == 'updateAspectRatio') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ecohub.ecohub/pip'), null);
  });

  group('PipManager Tests', () {
    test('isPipSupported invokes channel and returns value', () async {
      final supported = await PipManager.instance.isPipSupported();
      expect(supported, isTrue);
      expect(calls.any((c) => c.method == 'isPipSupported'), isTrue);
    });

    test('enterPip and setAutoPip forward correct parameters', () async {
      final enterRes = await PipManager.instance.enterPip(numerator: 16, denominator: 9);
      expect(enterRes, isTrue);
      final enterCall = calls.firstWhere((c) => c.method == 'enterPip');
      expect(enterCall.arguments, {'numerator': 16, 'denominator': 9});

      await PipManager.instance.setAutoPip(enabled: true, numerator: 4, denominator: 3);
      final autoCall = calls.firstWhere((c) => c.method == 'setAutoPip');
      expect(autoCall.arguments, {'enabled': true, 'numerator': 4, 'denominator': 3});
    });

    test('updatePipActions and updateAspectRatio forward parameters', () async {
      await PipManager.instance.updatePipActions(isPlaying: true, hasPrev: false, hasNext: true);
      final actionCall = calls.firstWhere((c) => c.method == 'updatePipActions');
      expect(actionCall.arguments, {'isPlaying': true, 'hasPrev': false, 'hasNext': true});

      await PipManager.instance.updateAspectRatio(numerator: 1920, denominator: 1080);
      final ratioCall = calls.firstWhere((c) => c.method == 'updateAspectRatio');
      expect(ratioCall.arguments, {'numerator': 1920, 'denominator': 1080});
    });

    test('onPipModeChanged and onPipAction distribute to listeners', () async {
      bool pipActiveReceived = false;
      String actionReceived = '';

      void onPip(bool active) => pipActiveReceived = active;
      void onAction(String action) => actionReceived = action;

      PipManager.instance.addListener(onPip);
      PipManager.instance.addActionListener(onAction);

      // 模拟原生发送 onPipModeChanged
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', true)),
        (data) {},
      );
      expect(pipActiveReceived, isTrue);
      expect(PipManager.instance.isPipActive, isTrue);

      // 模拟原生发送 onPipAction
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipAction', 'next')),
        (data) {},
      );
      expect(actionReceived, 'next');

      PipManager.instance.removeListener(onPip);
      PipManager.instance.removeActionListener(onAction);

      // 还原状态
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', false)),
        (data) {},
      );
      expect(PipManager.instance.isPipActive, isFalse);
    });
  });

  group('PlayerPipCoordinator Parity Tests', () {
    test('action delegation to play/pause/prev/next', () async {
      bool played = false;
      bool paused = false;
      bool prevCalled = false;
      bool nextCalled = false;

      final coord = PlayerPipCoordinator(
        onStateChanged: () {},
        onPlay: () => played = true,
        onPause: () => paused = true,
        onPrev: () => prevCalled = true,
        onNext: () => nextCalled = true,
      )..init();

      // 触发 play
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipAction', 'play')),
        (data) {},
      );
      expect(played, isTrue);

      // 触发 pause
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipAction', 'pause')),
        (data) {},
      );
      expect(paused, isTrue);

      // 触发 prev
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipAction', 'prev')),
        (data) {},
      );
      expect(prevCalled, isTrue);

      // 触发 next
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipAction', 'next')),
        (data) {},
      );
      expect(nextCalled, isTrue);

      coord.dispose();
    });

    test('syncAutoPip enables pip and updates actions when playing without error', () async {
      final coord = PlayerPipCoordinator(onStateChanged: () {});
      coord.pipSupported = true;

      AppSettingsManager.instance.pipAutoStartNotifier.value = true;
      calls.clear();

      coord.syncAutoPip(
        isCasting: false,
        videoUrl: 'https://example.com/movie.mp4',
        errorText: '',
        isPlaying: true,
        isCompleted: false,
        hasPrev: true,
        hasNext: true,
        videoSize: const Size(1920, 1080),
      );

      final autoCall = calls.firstWhere((c) => c.method == 'setAutoPip');
      expect(autoCall.arguments['enabled'], isTrue);
      expect(autoCall.arguments['numerator'], 1920);
      expect(autoCall.arguments['denominator'], 1080);

      final actionCall = calls.firstWhere((c) => c.method == 'updatePipActions');
      expect(actionCall.arguments['isPlaying'], isTrue);
      expect(actionCall.arguments['hasPrev'], isTrue);
      expect(actionCall.arguments['hasNext'], isTrue);

      coord.dispose();
    });

    test('syncAutoPip disables pip when isCasting or has error or paused', () async {
      final coord = PlayerPipCoordinator(onStateChanged: () {});
      coord.pipSupported = true;

      calls.clear();
      // 投屏中禁用
      coord.syncAutoPip(
        isCasting: true,
        videoUrl: 'https://example.com/movie.mp4',
        errorText: '',
        isPlaying: true,
        isCompleted: false,
        hasPrev: false,
        hasNext: false,
        videoSize: null,
      );
      expect(calls.firstWhere((c) => c.method == 'setAutoPip').arguments['enabled'], isFalse);

      // 暂停禁用
      calls.clear();
      coord.syncAutoPip(
        isCasting: false,
        videoUrl: 'https://example.com/movie.mp4',
        errorText: '',
        isPlaying: false,
        isCompleted: false,
        hasPrev: false,
        hasNext: false,
        videoSize: null,
      );
      expect(calls.firstWhere((c) => c.method == 'setAutoPip').arguments['enabled'], isFalse);

      coord.dispose();
    });

    test('enterPip blocks if casting or unsupported', () {
      String toastMsg = '';
      final coord = PlayerPipCoordinator(onStateChanged: () {});
      coord.pipSupported = false;

      coord.enterPip(
        videoSize: null,
        isCasting: true,
        isFull: false,
        onExitFullscreen: () {},
        showToast: (msg) => toastMsg = msg,
      );
      expect(toastMsg, '当前正在投屏，无法开启画中画');

      toastMsg = '';
      coord.enterPip(
        videoSize: null,
        isCasting: false,
        isFull: false,
        onExitFullscreen: () {},
        showToast: (msg) => toastMsg = msg,
      );
      expect(toastMsg, '当前设备不支持画中画');

      coord.dispose();
    });
  });

  group('PiP UI Rendering Parity Tests', () {
    testWidgets('VideoPlayerWidget renders PlayerVideoSurface and does not render PlayerPipHud when PiP is active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/test.mp4',
              title: '测试画中画',
            ),
          ),
        ),
      );
      await tester.pump();

      // 原生发送进入画中画
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', true)),
        (data) {},
      );
      await tester.pumpAndSettle();

      expect(find.text('正在画中画播放中'), findsNothing);
      expect(find.text('恢复原位播放'), findsNothing);
      expect(find.byType(PlayerVideoSurface), findsOneWidget);

      // 退出画中画
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', false)),
        (data) {},
      );
      await tester.pumpAndSettle();
    });

    testWidgets('CustomPlayerPage hides PageHeader and shows only VideoPlayerWidget when PiP is active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomPlayerPage(url: 'https://example.com/stream.m3u8'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('自定义播放'), findsWidgets);

      // 切换画中画状态
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', true)),
        (data) {},
      );
      await tester.pumpAndSettle();

      // 处于画中画状态时，Header 和输入框隐藏，全幅展示播放器
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(VideoPlayerWidget), findsOneWidget);

      // 退出画中画恢复
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.ecohub.ecohub/pip',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onPipModeChanged', false)),
        (data) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
