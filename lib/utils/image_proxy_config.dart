import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'server_config_manager.dart';

/// 图片代理配置。
///
/// 背景：部分图床（如 `image.jinyingimage.com`）会对特定网络环境返回 403，
/// 这是**图床/源站侧**的防盗链限制，客户端无法通过改请求头绕过。
///
/// 唯一彻底的解法是让请求经过一个能访问该图床的服务器（即图片代理）。
/// 本类支持配置一个「图片代理前缀」，例如：
/// ```
/// https://eco.fe-spark.cn/api/img?url=
/// ```
/// 客户端会把原始图片地址 URL-encode 后拼在前缀后面：
/// ```
/// https://eco.fe-spark.cn/api/img?url=https%3A%2F%2Fimage.jinyingimage.com%2Fcover%2Fxxx.jpg
/// ```
/// 若前缀为空（默认），则直接使用原始地址。
class ImageProxyConfig {
  ImageProxyConfig._internal();

  static final ImageProxyConfig instance = ImageProxyConfig._internal();

  static const String _key = 'image_proxy_prefix';

  SharedPreferences? _pref;
  String _prefix = '';

  /// 变化通知（用于让正在显示的图片重新加载）。
  final List<VoidCallback> _listeners = [];

  /// 当前代理前缀（空串表示未配置）。
  String get prefix => _prefix;

  /// 是否已配置代理。
  bool get enabled => _prefix.isNotEmpty;

  Future<void> init() async {
    try {
      _pref = await SharedPreferences.getInstance();
      _prefix = _pref?.getString(_key) ?? '';
    } catch (_) {
      _prefix = '';
    }
  }

  /// 设置代理前缀。传空串表示关闭代理。
  Future<void> setPrefix(String value) async {
    final clean = value.trim();
    if (clean == _prefix) return;
    _prefix = clean;
    try {
      if (_pref == null) await init();
      if (clean.isEmpty) {
        await _pref?.remove(_key);
      } else {
        await _pref?.setString(_key, clean);
      }
    } catch (_) {}
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 把原始图片地址转换为最终应请求的地址。
  ///
  /// - 配置了代理前缀 → 拼接到前缀后（原始地址做 URL-encode）；
  /// - 未配置 → 原样返回。
  String resolve(String url) {
    if (url.isEmpty) return url;
    if (_prefix.isEmpty) return url;
    // 已经是代理地址则不再二次包装。
    if (url.startsWith(_prefix)) return url;
    final encoded = Uri.encodeComponent(url);
    // 前缀若已带 ? 则用 & 拼接。
    final sep = _prefix.contains('?') ? '&' : '?';
    if (_prefix.endsWith('=') || _prefix.endsWith('&')) {
      return '$_prefix$encoded';
    }
    return '$_prefix$sep$encoded';
  }

  /// 判断某个原始地址是否应该走代理。
  ///
  /// 只对**相对地址**或已知的第三方图床走代理；
  /// 源站自身的地址（如软件源域名下的静态资源）无需代理。
  bool shouldProxy(String url) {
    if (_prefix.isEmpty || url.isEmpty) return false;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final origin = ServerConfigManager.instance.getOrigin();
      if (origin.isNotEmpty && url.startsWith(origin)) return false;
    }
    return true;
  }
}
