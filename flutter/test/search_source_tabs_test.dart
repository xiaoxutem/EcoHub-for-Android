import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/search_source_tabs.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/models/api_parser.dart';

void main() {
  testWidgets('SearchSourceTabs shows count and loading on chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchSourceTabs(
            sources: [
              SearchSourceTab(id: '', name: '聚合', count: 8),
              SearchSourceTab(id: 'a', name: '主站', loading: true),
              SearchSourceTab(id: 'b', name: '金鹰', count: 3),
            ],
            activeId: '',
            onChange: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('聚合'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('金鹰'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('ApiParser.parseSearch correctly parses error field from source search', () {
    final rawSuccess = {
      'list': [
        {'id': 100, 'name': '影片测试'}
      ],
      'page': {'pageSize': 10, 'current': 1, 'pageCount': 1, 'total': 1},
      'sources': [
        {'id': 'cj', 'name': '采集源', 'count': 1}
      ]
    };
    final successResult = ApiParser.parseSearch(rawSuccess);
    expect(successResult.list.length, 1);
    expect(successResult.error, isEmpty);

    final rawError = {
      'list': [],
      'page': {'pageSize': 10, 'current': 1, 'pageCount': 0, 'total': 0},
      'sources': [],
      'error': '源站超时'
    };
    final errorResult = ApiParser.parseSearch(rawError);
    expect(errorResult.list, isEmpty);
    expect(errorResult.error, '源站超时');
  });
}

