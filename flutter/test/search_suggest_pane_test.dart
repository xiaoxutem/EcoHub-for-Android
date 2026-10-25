import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/search_suggest_pane.dart';

void main() {
  testWidgets('SearchSuggestPane does not overflow with long keywords on standard phone width', (tester) async {
    final longKeyword = '情侣自拍情侣在家爱爱私拍视频流出_颜值不错的女友逼_超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            child: SearchSuggestPane(
              searchHistory: [longKeyword],
              hotKeywords: [longKeyword, '短词'],
              onSelectKeyword: (_) {},
              onClearHistory: () {},
              onRemoveHistory: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('SearchSuggestPane does not overflow on narrow split-screen width', (tester) async {
    final longKeyword = '情侣自拍情侣在家爱爱私拍视频流出_颜值不错的女友逼_超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长超长';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: SearchSuggestPane(
              searchHistory: [longKeyword],
              hotKeywords: [longKeyword, '短词'],
              onSelectKeyword: (_) {},
              onClearHistory: () {},
              onRemoveHistory: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
