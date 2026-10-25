import 'package:flutter/services.dart';

/// 剪贴板嗅探结果，对齐 OHOS `SniffResult`
class SniffResult {
  final String url;
  final String raw;

  const SniffResult({this.url = '', this.raw = ''});
}

/// 从剪贴板文本提取 http(s) 直链，对齐 OHOS `ClipboardSniffer`
class ClipboardSniffer {
  static String _lastHandledRawText = '';

  static final _urlRegex = RegExp(
    r'''(https?://[^\s"'<>\u4e00-\u9fa5\r\n]+)''',
    caseSensitive: false,
  );
  static final _trailingPunct = RegExp(r'''[。，！？；：、）】》"'\]\)\>]+$''');

  /// 从文本中解析出有效的 http/https 播放直链
  static String extractVideoUrl(String text) {
    if (text.isEmpty) return '';
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';

    final match = _urlRegex.firstMatch(cleanText);
    if (match == null || match.group(1) == null) return '';

    var url = match.group(1)!.trim();
    url = url.replaceAll(_trailingPunct, '');
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '';
  }

  /// 嗅探当前剪贴板。已处理过的原文返回 url 为空。
  static Future<SniffResult> sniff() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = (data?.text ?? '').trim();
      if (rawText.isEmpty) {
        return const SniffResult();
      }
      if (rawText == _lastHandledRawText) {
        return SniffResult(url: '', raw: rawText);
      }
      return SniffResult(url: extractVideoUrl(rawText), raw: rawText);
    } catch (_) {
      return const SniffResult();
    }
  }

  /// 标记指定剪贴板原始文本已处理，避免重复提取
  static void markHandled(String rawText) {
    _lastHandledRawText = rawText.trim();
  }

  /// 重置处理历史
  static void reset() {
    _lastHandledRawText = '';
  }
}
