import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 全局图片缓存管理器。
///
/// 项目此前直接使用 `CachedNetworkImage` 的默认缓存，
/// 在电视这类低端设备上缓存条数与体积不可控，
/// 加上封面加载失败时会反复重试，导致列表滚动明显卡顿。
///
/// 这里统一收敛到一个 [CacheManager] 实例：
/// - 限制缓存条数与总体积，避免占满存储；
/// - 失败的请求**不缓存**，但由 [CachedNetworkImage] 的 errorWidget 兜底；
/// - 通过 [imageBuilder] 统一处理占位与错误态。
class ImageCacheManager {
  ImageCacheManager._internal();

  static final ImageCacheManager instance = ImageCacheManager._internal();

  /// 缓存条数上限。电视存储与内存都紧张，控制在 200 张足够覆盖常用内容。
  static const int maxNrOfCacheObjects = 200;

  /// 缓存有效期。
  static const Duration stalePeriod = Duration(days: 30);

  /// 全局缓存实例。
  ///
  /// 用独立 cacheKey（而非默认的 `cachedNetworkImages`），
  /// 便于清理与统计。
  late final CacheManager cacheManager = CacheManager(
    Config(
      'ecohub_images',
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
    ),
  );

  /// 构造一个带统一缓存与错误兜底的图片组件。
  ///
  /// [errorBuilder] 用于在加载失败时展示占位内容（而不是空白）。
  ///
  /// [memCacheWidth] 限制内存中解码的图片宽度 ——
  /// 电视上卡片实际显示尺寸远小于原图，按显示尺寸解码可显著降低内存占用
  /// 与解码耗时（这是列表卡顿的主要来源之一）。
  Widget image({
    required String url,
    required BoxFit fit,
    required Widget Function(BuildContext, String, Object) errorBuilder,
    Widget? placeholder,
    Map<String, String>? headers,
    int? memCacheWidth,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      cacheManager: cacheManager,
      memCacheWidth: memCacheWidth,
      placeholder: (context, _) => placeholder ?? const SizedBox.shrink(),
      errorWidget: errorBuilder,
    );
  }
}
