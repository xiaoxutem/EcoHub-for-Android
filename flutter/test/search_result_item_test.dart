import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/search_result_item.dart';
import 'package:ecohub_android/models/film_models.dart';

void main() {
  testWidgets('SearchResultItem renders title with maxLines: 2', (tester) async {
    final film = MovieBasicInfo(
      id: 101,
      name: '这是一个非常非常长的影片搜索标题展示用于测试两行排版之后再截断省略号的效果',
      cName: '动作片',
      remarks: '超清',
      director: '张三',
      actor: '李四 / 王五',
      blurb: '这是一段简介文字内容',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            child: SearchResultItem(film: film),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final titleFinder = find.text(film.name);
    expect(titleFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(titleFinder);
    expect(textWidget.maxLines, 2);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets('SearchResultItem renders cleanly in multi-lane grid', (tester) async {
    final film = MovieBasicInfo(
      id: 102,
      name: '这是一个非常非常长的影片搜索标题展示用于测试两行排版之后再截断省略号的效果',
      cName: '动作片',
      remarks: '超清',
      director: '张三',
      actor: '李四 / 王五',
      blurb: '这是一段简介文字内容，包含两行简介描述，测试在网格布局下的高度适应性',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: CustomScrollView(
              slivers: [
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 168,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SearchResultItem(film: film),
                    childCount: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('SearchResultItem in SliverList with semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final film = MovieBasicInfo(
      id: 103,
      name: '测试影片标题',
      cName: '动作片',
      remarks: '超清',
      director: '张三',
      actor: '李四',
      blurb: '简介文字',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SearchResultItem(film: film),
                  childCount: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
