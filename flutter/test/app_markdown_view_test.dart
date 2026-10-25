import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/app_markdown_view.dart';

void main() {
  test('isSafeMarkdownLink 只放行 http/https/mailto', () {
    expect(isSafeMarkdownLink('https://example.com'), isTrue);
    expect(isSafeMarkdownLink('http://example.com'), isTrue);
    expect(isSafeMarkdownLink('mailto:a@b.com'), isTrue);
    expect(isSafeMarkdownLink('javascript:alert(1)'), isFalse);
    expect(isSafeMarkdownLink('file:///etc/passwd'), isFalse);
    expect(isSafeMarkdownLink('intent://scan/#Intent;end'), isFalse);
    expect(isSafeMarkdownLink('hap://app/com.example'), isFalse);
    expect(isSafeMarkdownLink(''), isFalse);
    expect(isSafeMarkdownLink(null), isFalse);
  });

  test('isSafeMarkdownImageUrl 只放行 https', () {
    expect(isSafeMarkdownImageUrl('https://example.com/a.png'), isTrue);
    expect(isSafeMarkdownImageUrl('http://example.com/a.png'), isFalse);
    expect(isSafeMarkdownImageUrl('file:///tmp/a.png'), isFalse);
    expect(isSafeMarkdownImageUrl('javascript:alert(1)'), isFalse);
  });

  final testCases = <String, String>{
    'hello': 'Hello world',
    'title': '# Title\nSome text',
    'empty code': '```\n```',
    'empty code with lang': '```dart\n```',
    'code with content': '```dart\nvoid main() {\n  print("hello world");\n}\n```',
    'inline code': '`inline code`',
    'link': '[Link](https://example.com)',
    'table': '| a | b |\n|---|---|\n| 1 | 2 |',
    'quote': '> quote\n> quote 2',
    'list': '* list 1\n* list 2',
    'hr': '---\n***',
    'html': '<div>html</div>',
    'br': '<br>',
    'whitespace': '   \n\n   ',
    'empty link': '[]()',
    'badges': '[![alt](img)](https://example.com)',
  };

  for (final entry in testCases.entries) {
    testWidgets('AppMarkdownView renders: ${entry.key}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppMarkdownView(data: entry.value),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
