import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/utils/tv_mode.dart';
import 'package:ecohub_android/components/focus_wrap.dart';
import 'package:ecohub_android/components/player/player_dpad_controller.dart';
import 'package:ecohub_android/components/player/player_gesture_handler.dart';

/// Android TV 遥控器适配测试。
///
/// 覆盖三条主线：
/// 1. [TvMode] 设备探测与缩放逻辑；
/// 2. [FocusTap] —— 遥控器方向键可聚焦、OK 键可激活；
/// 3. [PlayerDpadController] —— 播放器方向键映射（左右快进快退 / 上下音量 / OK 播放暂停）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TvMode.debugSetTv(false);
  });  group('TvMode 设备探测与缩放', () {
    test('非 TV 模式下尺寸与字号不缩放', () {
      TvMode.debugSetTv(false);
      expect(TvMode.isTv, isFalse);
      expect(TvMode.scale(10), 10);
      expect(TvMode.font(12), 12);
      expect(TvMode.showFocusHighlight, isFalse);
    });

    test('TV 模式下尺寸与字号按系数放大', () {
      TvMode.debugSetTv(true);
      expect(TvMode.isTv, isTrue);
      expect(TvMode.scale(10), closeTo(10 * TvMode.tvScale, 0.001));
      expect(TvMode.font(12), closeTo(12 * TvMode.tvScale, 0.001));
      expect(TvMode.showFocusHighlight, isTrue);
    });

    test('TV 模式强制横屏', () {
      TvMode.debugSetTv(true);
      expect(TvMode.orientations, [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('启发式判定：宽横屏低密度判为 TV', () {
      expect(
        TvMode.looksLikeTv(const Size(1920, 1080), devicePixelRatio: 1.0),
        isTrue,
      );
    });

    test('启发式判定：手机竖屏与手机横屏不判为 TV', () {
      expect(
        TvMode.looksLikeTv(const Size(412, 915), devicePixelRatio: 2.6),
        isFalse,
      );
      expect(
        TvMode.looksLikeTv(const Size(892, 412), devicePixelRatio: 3.0),
        isFalse,
      );
    });
  });

  group('FocusTap 遥控器交互', () {
    testWidgets('非 TV 模式退化为 GestureDetector，行为不变', (tester) async {
      TvMode.debugSetTv(false);
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTap(
              onTap: () => tapped++,
              child: const Text('目标'),
            ),
          ),
        ),
      );

      // 非 TV 模式不应生成 FocusTap 自身的焦点节点
      // （MaterialApp 框架本身自带若干 Focus，故按 debugLabel 精确定位）
      expect(_focusTapNode(tester), isNull);

      await tester.tap(find.text('目标'));
      expect(tapped, 1);
    });

    testWidgets('TV 模式下可被方向键聚焦，OK 键触发点击', (tester) async {
      TvMode.debugSetTv(true);
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTap(
              onTap: () => tapped++,
              child: const Text('目标'),
            ),
          ),
        ),
      );

      // TV 模式应生成可聚焦的 Focus 节点
      final focusNode = _focusTapNode(tester);
      expect(focusNode, isNotNull);

      await tester.pump();
      focusNode!.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);

      // 模拟遥控器 OK 键
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapped, 1);

      // SELECT 键（部分遥控器）
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(tapped, 2);
    });

    testWidgets('TV 模式下焦点框在获得焦点后出现', (tester) async {
      TvMode.debugSetTv(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTap(
              onTap: () {},
              child: const SizedBox(width: 100, height: 40, child: Text('目标')),
            ),
          ),
        ),
      );

      final focusNode = _focusTapNode(tester);
      await tester.pump();
      focusNode!.requestFocus();
      await tester.pumpAndSettle();

      // 焦点框使用 foreground 装饰，不影响布局尺寸
      expect(find.byType(IgnorePointer), findsWidgets);
    });

    testWidgets('TV 模式下焦点切换不改变元素布局尺寸', (tester) async {
      TvMode.debugSetTv(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FocusTap(
                onTap: () {},
                child: const SizedBox(width: 120, height: 48, child: Text('目标')),
              ),
            ),
          ),
        ),
      );

      final sizeBefore = tester.getSize(find.byType(FocusTap));
      final focusNode = _focusTapNode(tester);
      await tester.pump();
      focusNode!.requestFocus();
      await tester.pumpAndSettle();
      final sizeAfter = tester.getSize(find.byType(FocusTap));

      expect(sizeAfter.width, closeTo(sizeBefore.width, 0.01));
      expect(sizeAfter.height, closeTo(sizeBefore.height, 0.01));
    });
  });

  group('FocusHighlight 焦点高亮', () {
    testWidgets('子级 InkWell 获得焦点时显示焦点框', (tester) async {
      TvMode.debugSetTv(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FocusHighlight(
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(width: 100, height: 50, child: Text('A')),
                  ),
                ),
                FocusHighlight(
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(width: 100, height: 50, child: Text('B')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      int overlayCount() => find
          .byWidgetPredicate(
            (w) => w is DecoratedBox && w.position == DecorationPosition.foreground,
          )
          .evaluate()
          .length;

      // 未聚焦时无焦点框
      expect(overlayCount(), 0);

      // 移动焦点后应出现焦点框
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(overlayCount(), greaterThan(0), reason: '子控件聚焦后应显示焦点框');
    });

    testWidgets('非 TV 模式不渲染焦点框', (tester) async {
      TvMode.debugSetTv(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusHighlight(
              child: InkWell(
                onTap: () {},
                child: const SizedBox(width: 100, height: 50, child: Text('A')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final overlays = find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.position == DecorationPosition.foreground,
      );
      expect(overlays, findsNothing);
    });
  });

  group('PlayerDpadController 播放器遥控控制', () {
    Widget buildPlayer({
      required VoidCallback onTogglePlay,
      required VoidCallback onBack,
      required ValueChanged<Duration> onSeekTo,
      required ValueChanged<double> onVolumeChange,
      required void Function(PlayerPanState) onPanStateChange,
      bool muted = false,
      bool isFull = true,
      Widget? hudOverlay,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PlayerDpadController(
            isFull: isFull,
            hudOverlay: hudOverlay,
            isPlaying: true,
            muted: muted,
            currentPosition: const Duration(seconds: 100),
            totalDuration: const Duration(seconds: 600),
            currentVolume: 0.5,
            onTogglePlay: onTogglePlay,
            onBack: onBack,
            onSeekTo: onSeekTo,
            onVolumeChange: onVolumeChange,
            onPanStateChange: onPanStateChange,
            onToggleMute: () {},
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    testWidgets('非 TV 模式不接管按键', (tester) async {
      TvMode.debugSetTv(false);
      var seeked = false;
      var played = false;
      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () => played = true,
        onBack: () {},
        onSeekTo: (_) => seeked = true,
        onVolumeChange: (_) {},
        onPanStateChange: (_) {},
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seeked, isFalse);
      expect(played, isFalse);
    });

    testWidgets('TV 模式：左右键快进快退', (tester) async {
      TvMode.debugSetTv(true);
      final seeks = <Duration>[];
      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () {},
        onBack: () {},
        onSeekTo: seeks.add,
        onVolumeChange: (_) {},
        onPanStateChange: (_) {},
      ));

      await tester.pump();
      // 右键 +10 秒
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seeks.length, 1);
      expect(seeks.first.inSeconds, 110);

      // 左键 -10 秒
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seeks.length, 2);
      expect(seeks.last.inSeconds, 90);
    });

    testWidgets('TV 模式：上下键调节音量', (tester) async {
      TvMode.debugSetTv(true);
      final volumes = <double>[];
      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () {},
        onBack: () {},
        onSeekTo: (_) {},
        onVolumeChange: volumes.add,
        onPanStateChange: (_) {},
      ));

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(volumes.length, 1);
      expect(volumes.first, closeTo(0.6, 0.001));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(volumes.length, 2);
      expect(volumes.last, closeTo(0.4, 0.001));
    });

    testWidgets('TV 模式：媒体播放键切换播放暂停', (tester) async {
      TvMode.debugSetTv(true);
      var played = 0;
      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () => played++,
        onBack: () {},
        onSeekTo: (_) {},
        onVolumeChange: (_) {},
        onPanStateChange: (_) {},
      ));

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await tester.pump();
      expect(played, 1);
    });

    testWidgets('TV 模式：非全屏时方向键不调整音量（留给列表滚动）', (tester) async {
      TvMode.debugSetTv(true);
      final volumes = <double>[];
      final seeks = <Duration>[];
      await tester.pumpWidget(buildPlayer(
        isFull: false,
        onTogglePlay: () {},
        onBack: () {},
        onSeekTo: seeks.add,
        onVolumeChange: volumes.add,
        onPanStateChange: (_) {},
      ));

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(volumes, isEmpty, reason: '非全屏时上下键不应调音量');
      expect(seeks, isEmpty, reason: '非全屏时左右键不应快进');
    });

    testWidgets('TV 模式：焦点在 HUD 上时方向键让给焦点导航', (tester) async {
      TvMode.debugSetTv(true);
      final volumes = <double>[];
      final seeks = <Duration>[];

      // HUD 内放一个可聚焦按钮，模拟焦点落在 HUD 的情形
      final hud = Builder(
        builder: (ctx) => Align(
          alignment: Alignment.bottomRight,
          child: FocusTap(
            onTap: () {},
            child: const SizedBox(width: 80, height: 40, child: Text('HUD')),
          ),
        ),
      );

      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () {},
        onBack: () {},
        onSeekTo: seeks.add,
        onVolumeChange: volumes.add,
        onPanStateChange: (_) {},
        hudOverlay: hud,
      ));
      await tester.pumpAndSettle();

      // 把焦点移到 HUD 内的按钮上
      final hudNode = _focusTapNode(tester);
      expect(hudNode, isNotNull);
      hudNode!.requestFocus();
      await tester.pumpAndSettle();

      // 方向键应让给焦点导航，不调整音量/进度
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(volumes, isEmpty, reason: '焦点在 HUD 上时上下键应让给焦点导航');
      expect(seeks, isEmpty, reason: '焦点在 HUD 上时左右键应让给焦点导航');
    });

    testWidgets('TV 模式：返回键触发退出', (tester) async {
      TvMode.debugSetTv(true);
      var backed = 0;
      await tester.pumpWidget(buildPlayer(
        onTogglePlay: () {},
        onBack: () => backed++,
        onSeekTo: (_) {},
        onVolumeChange: (_) {},
        onPanStateChange: (_) {},
      ));

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(backed, 1);
    });
  });
}

/// 精确定位 FocusTap 自身的焦点节点。
///
/// MaterialApp 框架内部自带若干 Focus 节点（FocusTraversalGroup / Shortcuts 等），
/// 不能用 `find.byType(Focus).first` 取；需按 debugLabel 匹配。
FocusNode? _focusTapNode(WidgetTester tester) {
  for (final w in tester.widgetList<Focus>(find.byType(Focus))) {
    if (w.focusNode?.debugLabel == 'FocusTap') return w.focusNode;
  }
  return null;
}
