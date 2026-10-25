import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/cast/player_cast_controller.dart';
import 'package:ecohub_android/components/player/player_playback_controller.dart';
import 'package:ecohub_android/components/player/player_skin_view.dart';

class _Host implements PlayerCastHost {
  double currentPos = 0;
  double totalDur = 0;
  bool playing = false;
  bool opening = true;
  bool buffering = true;
  String url = 'https://example.com/ep.mp4';

  bool pauseLocalCalled = false;
  bool parkLocalCalled = false;
  double? resumeTargetSec;
  bool? resumeWasPlaying;

  @override
  double get currentPosition => currentPos;
  @override
  double get totalDuration => totalDur;
  @override
  bool get isPlaying => playing;
  @override
  bool get isOpening => opening;
  @override
  bool get isBuffering => buffering;
  @override
  String get videoUrl => url;
  @override
  String get title => '测试';
  @override
  bool get hasNext => false;
  @override
  double get volume => 0.8;
  @override
  bool get isFull => false;

  @override
  void parkLocal() => parkLocalCalled = true;
  @override
  void pauseLocal() => pauseLocalCalled = true;
  @override
  void resumeLocal(double targetSec, bool wasPlaying) {
    resumeTargetSec = targetSec;
    resumeWasPlaying = wasPlaying;
  }
  @override
  void remountCompleted(double positionSec, double durationSec) {}
  @override
  void exitFullForCast() {}
  @override
  void onCastEnded() {}
  @override
  void syncUi() {}
  @override
  void syncProgress(double currentSec, double durationSec) {}
  @override
  void showToast(String message) {}
  @override
  void setPipAutoStart(bool enable) {}
  @override
  void stopPip() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening the cast picker while loading pauses and shows no remount', (tester) async {
    final castCtrl = PlayerCastController();
    final host = _Host();
    castCtrl.attachHost(host);

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ),
    ));

    host.playing = false;
    host.opening = true;
    host.buffering = true;
    castCtrl.openCastSheet(
      ctx,
      mediaUrl: host.videoUrl,
      currentPosition: 0,
      autoStartScan: false,
    );
    await tester.pump();

    expect(castCtrl.pausedForPicker, isTrue);
    expect(castCtrl.wasPlaying, isTrue);
    expect(host.pauseLocalCalled, isTrue);
    expect(host.parkLocalCalled, isFalse);

    Navigator.pop(ctx);
    await tester.pumpAndSettle();
    expect(host.resumeWasPlaying, isTrue);
    expect(host.parkLocalCalled, isFalse);
  });

  testWidgets('pickerOpen hides 正在打开 and shows the pause/play button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerSkinView(
          isFull: false,
          showHud: true,
          title: '测试',
          isPlaying: false,
          isBuffering: true,
          isOpening: true,
          pickerOpen: true,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
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
    ));
    await tester.pump();

    expect(find.text('正在打开...'), findsNothing);
    expect(find.text('加载中...'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  test('pauseLocal during opening keeps isOpening and reveals HUD', () {
    final ctrl = PlayerPlaybackController();
    ctrl.debugArmOpeningSession();
    expect(ctrl.isOpening, isTrue);
    ctrl.pauseLocal();
    expect(ctrl.isOpening, isTrue);
    expect(ctrl.isPlaying, isFalse);
    expect(ctrl.showHud, isTrue);
  });
}
