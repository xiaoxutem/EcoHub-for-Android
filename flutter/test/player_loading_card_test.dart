import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/player_loading_card.dart';
import 'package:ecohub_android/components/player/player_skin_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

PlayerSkinView _skin({
  required int loadSessionId,
  bool isOpening = true,
}) {
  return PlayerSkinView(
    isFull: false,
    showHud: true,
    title: '测试剧集',
    isPlaying: true,
    isBuffering: true,
    isOpening: isOpening,
    loadSessionId: loadSessionId,
    currentPosition: Duration.zero,
    totalDuration: const Duration(minutes: 1),
    onBack: () {},
    onTogglePlay: () {},
    onToggleFull: () {},
    onToggleMute: () {},
    onSpeed: () {},
    onRetry: () {},
    onSeekBack10: () {},
    onSeekFwd10: () {},
    onSeekTo: (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerLoadingCard slow-network reset', () {
    testWidgets('shows 网络较慢 after 6s while still visible', (tester) async {
      await tester.pumpWidget(_wrap(const PlayerLoadingCard(
        visible: true,
        isOpening: true,
        resetToken: 1,
        onRetry: _noop,
      )));
      await tester.pump();
      expect(find.text('正在打开...'), findsOneWidget);
      expect(find.text('网络较慢'), findsNothing);

      await tester.pump(const Duration(milliseconds: 6001));
      expect(find.text('网络较慢'), findsOneWidget);
      expect(find.text('点击重试'), findsOneWidget);
    });

    testWidgets('resetToken hides tip and restarts the 6s clock while visible stays true', (tester) async {
      await tester.pumpWidget(_wrap(const PlayerLoadingCard(
        visible: true,
        isOpening: true,
        resetToken: 1,
        onRetry: _noop,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6001));
      expect(find.text('网络较慢'), findsOneWidget);

      await tester.pumpWidget(_wrap(const PlayerLoadingCard(
        visible: true,
        isOpening: true,
        resetToken: 2,
        onRetry: _noop,
      )));
      await tester.pump();
      expect(find.text('网络较慢'), findsNothing);
      expect(find.text('正在打开...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 5999));
      expect(find.text('网络较慢'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2));
      expect(find.text('网络较慢'), findsOneWidget);
    });

    testWidgets('点击重试 hides the tip immediately', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_wrap(PlayerLoadingCard(
        visible: true,
        isOpening: true,
        resetToken: 1,
        onRetry: () => retries++,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6001));
      expect(find.text('网络较慢'), findsOneWidget);

      await tester.tap(find.text('点击重试'));
      await tester.pump();
      expect(retries, 1);
      expect(find.text('网络较慢'), findsNothing);
    });

    testWidgets('hiding the card clears the tip', (tester) async {
      await tester.pumpWidget(_wrap(const PlayerLoadingCard(
        visible: true,
        isOpening: true,
        resetToken: 1,
        onRetry: _noop,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6001));
      expect(find.text('网络较慢'), findsOneWidget);

      await tester.pumpWidget(_wrap(const PlayerLoadingCard(
        visible: false,
        isOpening: false,
        resetToken: 1,
        onRetry: _noop,
      )));
      await tester.pump();
      expect(find.text('网络较慢'), findsNothing);
    });
  });

  group('PlayerSkinView loadSessionId', () {
    testWidgets('new load session clears 网络较慢 while still opening', (tester) async {
      await tester.pumpWidget(_wrap(_skin(loadSessionId: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6001));
      expect(find.text('网络较慢'), findsOneWidget);

      await tester.pumpWidget(_wrap(_skin(loadSessionId: 2)));
      await tester.pump();
      expect(find.text('网络较慢'), findsNothing);
      expect(find.text('正在打开...'), findsOneWidget);
    });
  });
}

void _noop() {}
