import 'package:flutter/material.dart';

import '../utils/format_util.dart';
import '../utils/image_cache_manager.dart';
import '../utils/image_host_guard.dart';
import '../utils/image_proxy_config.dart';

/// 支持多候选地址回退的网络图片。
///
/// 背景：部分图床（如 `image.jinyingimage.com`）会对特定网络环境返回 403。
/// 单一地址失败时整张卡片就是一片空白，用户看到的是「内容都没有封面」。
///
/// 本组件按顺序尝试候选地址，全部失败时渲染 [PosterFallback] ——
/// 用影片首字 + 稳定色相生成占位图，至少能区分不同影片，
/// 观感上远好过纯空白。
class ResilientNetworkImage extends StatefulWidget {
  /// 候选地址，按优先级排列。
  final List<String> urls;

  /// 全部失败时用于生成占位图的名字（通常是影片名）。
  final String fallbackName;

  final BoxFit fit;

  /// 占位图与错误图的样式。
  final Color backgroundColor;

  /// 解码目标宽度（物理像素）。按实际显示尺寸解码可显著降低内存与耗时。
  final int? decodeWidth;

  const ResilientNetworkImage({
    super.key,
    required this.urls,
    this.fallbackName = '',
    this.fit = BoxFit.cover,
    this.backgroundColor = const Color(0xFF1E2228),
    this.decodeWidth,
  });

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 候选列表变化时重置回第一个地址。
    if (!listEquals(oldWidget.urls, widget.urls)) {
      _index = 0;
    }
  }

  /// 找到下一个**未被熔断**的候选地址下标；没有则返回 null。
  int? _nextUsableUrl() {
    for (var i = _index + 1; i < widget.urls.length; i++) {
      if (!ImageHostGuard.instance.shouldSkip(widget.urls[i])) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return PosterFallback(name: widget.fallbackName);
    }
    final url = widget.urls[_index.clamp(0, widget.urls.length - 1)];

    // 配置了图片代理时，所有地址都走代理（代理服务器能访问被封的图床）。
    final proxy = ImageProxyConfig.instance;
    final useProxy = proxy.shouldProxy(url);
    final requestUrl = useProxy ? proxy.resolve(url) : url;

    // 已知不可用的图床：直接走占位图，**不发起网络请求**。
    // 首页有 200+ 张卡片指向被封图床，逐个请求会浪费带宽、拖慢首屏，
    // 还会因失败回调触发整卡重绘 —— 这是「推荐页卡」的主因。
    // （配置了代理时不熔断 —— 代理能取到图。）
    if (!useProxy && ImageHostGuard.instance.shouldSkip(url)) {
      // 尝试下一个候选地址；全部被封则显示占位图。
      final next = _nextUsableUrl();
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _index = next);
        });
      }
      return PosterFallback(name: widget.fallbackName);
    }

    return ImageCacheManager.instance.image(
      url: requestUrl,
      fit: widget.fit,
      memCacheWidth: widget.decodeWidth,
      // 走代理时不需要原图床的防盗链头。
      headers: useProxy ? const {} : FormatUtil.imageHeaders(url),
      placeholder: PosterFallback(
        name: widget.fallbackName,
        dimmed: true,
      ),
      errorBuilder: (context, _, _) {
        // 还有候选地址就继续尝试下一个。
        if (_index + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index++);
          });
          return PosterFallback(name: widget.fallbackName, dimmed: true);
        }
        return PosterFallback(name: widget.fallbackName);
      },
    );
  }
}

/// 图片占位图：影片首字 + 稳定色相。
///
/// 用名称哈希决定色相，保证同一影片每次渲染颜色一致，
/// 不同影片之间又能明显区分。
class PosterFallback extends StatelessWidget {
  final String name;
  final bool dimmed;

  const PosterFallback({super.key, this.name = '', this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final text = name.trim();
    final initial = text.isEmpty ? '' : text.characters.first;
    // 名称哈希 → 色相，保证同一部影片颜色稳定。
    final hash = text.isEmpty ? 0 : text.hashCode;
    final hue = (hash.abs() % 360).toDouble();
    final bg = dimmed
        ? HSLColor.fromAHSL(1, hue, 0.18, 0.14).toColor()
        : HSLColor.fromAHSL(1, hue, 0.30, 0.26).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.45, 0.78).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bg,
            HSLColor.fromAHSL(1, hue, 0.26, 0.18).toColor(),
          ],
        ),
      ),
      child: initial.isEmpty
          ? const SizedBox.expand()
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: fg.withValues(alpha: dimmed ? 0.35 : 0.85),
                ),
              ),
            ),
    );
  }
}

/// 判断两个字符串列表是否相等（避免引入 foundation 依赖的额外导入）。
bool listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
