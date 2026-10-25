import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/live_play_error_view.dart';

void main() {
  testWidgets('LivePlayErrorView displays error prompt, search button and remove favorite', (tester) async {
    bool removed = false;
    bool retried = false;
    bool backed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivePlayErrorView(
            filmName: '测试电影',
            errorText: '采集源不存在',
            isFavorite: true,
            onBack: () => backed = true,
            onRetry: () => retried = true,
            onRemoveFavorite: () => removed = true,
          ),
        ),
      ),
    );

    expect(find.text('采集源已失效或下线'), findsOneWidget);
    expect(find.textContaining('采集源不存在'), findsOneWidget);
    expect(find.text('全网搜索「测试电影」'), findsOneWidget);
    expect(find.text('移出收藏'), findsOneWidget);
    expect(find.text('重新尝试'), findsOneWidget);

    await tester.tap(find.text('移出收藏'));
    await tester.pump();
    expect(removed, isTrue);

    await tester.tap(find.text('重新尝试'));
    await tester.pump();
    expect(retried, isTrue);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(backed, isTrue);
  });

  testWidgets('LivePlayErrorView hides remove favorite when not favorited', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivePlayErrorView(
            filmName: '',
            errorText: '网络超时',
            isFavorite: false,
            onBack: () {},
            onRetry: () {},
            onRemoveFavorite: () {},
          ),
        ),
      ),
    );

    expect(find.text('采集源已失效或下线'), findsOneWidget);
    expect(find.text('全网重新搜索'), findsOneWidget);
    expect(find.text('移出收藏'), findsNothing);
  });
}
