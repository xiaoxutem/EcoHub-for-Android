import 'dart:io';

import 'package:flutter/foundation.dart';

/// 网络探测：检查关键图床与源站是否可达。
///
/// 启动时调用一次，结果用于 [ImageHostGuard] 熔断不可用的图床 ——
/// 避免首页 200+ 张卡片发起注定失败的请求（这是首屏卡顿的主要原因）。
Future<List<String>> runNetworkProbe() async {
  const urls = [
    'https://image.jinyingimage.com/cover/db6f1d8c10a1170e858ef8c58dd333f8.jpg',
    'https://image.tmdb.org/t/p/w500/v0k3PygrKjsguztUTxi2d88y6Ie.jpg',
    'https://eco.fe-spark.cn/api/index',
  ];
  final out = <String>[];
  for (final u in urls) {
    try {
      final c = HttpClient();
      c.connectionTimeout = const Duration(seconds: 8);
      final req = await c.getUrl(Uri.parse(u));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close().timeout(const Duration(seconds: 12));
      final n = await resp.fold<int>(0, (a, _) => a + 1);
      final line = '${resp.statusCode} len=$n  ${Uri.parse(u).host}';
      out.add(line);
      debugPrint('DIAG_NET $line');
    } catch (e) {
      final t = e.toString();
      final line = 'ERR ${e.runtimeType} ${t.length > 50 ? t.substring(0, 50) : t}  ${Uri.parse(u).host}';
      out.add(line);
      debugPrint('DIAG_NET $line');
    }
  }
  return out;
}
