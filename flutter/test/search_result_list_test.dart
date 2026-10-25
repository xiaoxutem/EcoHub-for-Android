import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/search_result_list.dart';
import 'package:ecohub_android/components/loading_view.dart';
import 'package:ecohub_android/models/film_models.dart';

void main() {
  testWidgets('LoadingView does not overflow in constrained 15.7px height', (tester) async {
    // 复现用户遇到的极端高度约束 (0.0 <= h <= 15.7)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 750.0,
              height: 15.7,
              child: LoadingView(label: '正在搜索'),
            ),
          ),
        ),
      ),
    );

    // 确保没有抛出任何 RenderFlex overflowed 异常
    expect(tester.takeException(), isNull);
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('SearchResultList shows loading-more indicator when loadingMore is true', (tester) async {
    final list = [
      MovieBasicInfo(id: 1, name: '电影A', cName: '动作片', remarks: 'HD'),
    ];
    final page = PageInfo(pageSize: 10, current: 1, pageCount: 3, total: 25);
    final scrollCtrl = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchResultList(
            list: list,
            page: page,
            loadingMore: true,
            sourceError: '',
            submitted: '测试',
            scrollController: scrollCtrl,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('正在加载更多...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SearchResultList shows 没有更多了 when page reached end', (tester) async {
    final list = [
      MovieBasicInfo(id: 1, name: '电影A', cName: '动作片', remarks: 'HD'),
    ];
    final page = PageInfo(pageSize: 10, current: 3, pageCount: 3, total: 25);
    final scrollCtrl = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchResultList(
            list: list,
            page: page,
            loadingMore: false,
            sourceError: '',
            submitted: '测试',
            scrollController: scrollCtrl,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('没有更多了'), findsOneWidget);
    expect(find.text('正在加载更多...'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
