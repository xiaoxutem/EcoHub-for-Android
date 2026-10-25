import 'package:flutter/foundation.dart';

/// 图床可用性探测与熔断。
///
/// 背景：某些图床（如 `image.jinyingimage.com`）会对特定网络环境返回 403。
/// 若不处理，首页 200+ 张卡片会各自发起一次**注定失败**的请求：
/// - 每次都要建连 + 下载几十 KB 的错误页 HTML；
/// - 失败后还要走 errorWidget 回调 → 触发 setState → 整卡重绘。
/// 这正是「推荐页很卡」的直接原因。
///
/// 本类做两件事：
/// 1. 维护一份**已知不可用**的图床域名名单（启动时探测确认）；
/// 2. 一旦某个域名确认不可用，后续同域名的图片**直接走占位图**，
///    不再发起网络请求 —— 页面瞬间可交互，且零无效流量。
///
/// 名单可持久化：探测一次即可长期生效，不必每次启动都重试。
class ImageHostGuard {
  ImageHostGuard._internal();

  static final ImageHostGuard instance = ImageHostGuard._internal();

  /// 已确认不可用的图床域名。
  final Set<String> _blockedHosts = <String>{};

  /// 探测结果缓存（key = 域名）。
  final Map<String, bool> _probeCache = <String, bool>{};

  /// 已知被封的图床（内置名单）。
  ///
  /// 这些是实测确认会返回 403 的图床，先验加入避免首次启动时的无效请求风暴。
  ///
  /// 注意：`fffgood.com`（部分自建源使用）实测可用，**不要**加进来。
  static const Set<String> knownBlockedHosts = {
    'image.jinyingimage.com',
  };

  bool _initialized = false;

  /// 初始化：载入内置名单。
  void init() {
    if (_initialized) return;
    _initialized = true;
    _blockedHosts.addAll(knownBlockedHosts);
  }

  /// 判断给定 URL 是否应跳过网络请求（直接用占位图）。
  bool shouldSkip(String url) {
    if (url.isEmpty) return true;
    final host = _hostOf(url);
    if (host == null) return false;
    return _blockedHosts.contains(host);
  }

  /// 记录一次探测结果。
  void recordProbe(String host, bool reachable) {
    init();
    _probeCache[host] = reachable;
    if (reachable) {
      _blockedHosts.remove(host);
    } else {
      _blockedHosts.add(host);
    }
  }

  /// 某域名是否已知不可用。
  bool isBlocked(String host) {
    init();
    return _blockedHosts.contains(host);
  }

  /// 需要探测的域名列表（取自当前页面用到的图床）。
  static String? _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.host.toLowerCase();
  }

  /// 调试输出。
  @visibleForTesting
  Set<String> get blockedHosts {
    init();
    return Set.unmodifiable(_blockedHosts);
  }
}
