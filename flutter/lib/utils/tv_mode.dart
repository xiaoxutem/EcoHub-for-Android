import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

/// Android TV / 遥控器模式适配层。
///
/// TV 判定以平台通道 [probe] 为准 —— Android 侧读取 `PackageManager.FEATURE_LEANBACK`
/// 与 `Configuration.uiMode == UI_MODE_TYPE_TELEVISION`，这是系统级的准确判据。
///
/// [looksLikeTv] 仅用于单元测试与「平台通道不可用」时的兜底判断，
/// 生产路径不依赖它（平台通道异常时按非 TV 处理，宁可保持手机端体验，
/// 也不误判成 TV 后布局错乱）。
///
/// 该模式一旦开启，全局生效的差异集中在：
/// - [tvScale]：全局尺寸/字号放大系数（TV 观看距离远）；
/// - [showFocusHighlight]：是否展示焦点高亮框（遥控器必须看得见当前焦点）；
/// - [orientations]：TV 端强制横屏。
class TvMode {
  TvMode._();

  static const MethodChannel _channel = MethodChannel('com.ecohub.ecohub/device');

  /// 是否运行在 Android TV（或等价的大屏遥控器）设备上。
  static bool _isTv = false;

  /// 是否已完成过一次设备探测。用于避免重复调用平台通道。
  static bool _probed = false;

  /// 用户手动强制开启 TV 模式（用于在非 TV 设备上预览遥控器布局）。
  static bool _forcedTv = false;

  static const String _forceKey = 'setting_force_tv_mode';

  /// 强制 TV 模式开关。开启后即使设备不是 TV 也套用 TV 布局与遥控器适配。
  static bool get forceTv => _forcedTv;

  /// 是否应按 TV 模式渲染 —— 设备形态判定 + 用户手动强制。
  static bool get isTvActive => _isTv || _forcedTv;

  /// TV 模式下的全局放大系数。
  ///
  /// TV 通常 10 英尺观看距离，同等像素密度下字号需要放大约 1.25 倍才够清晰。
  static const double tvScale = 1.25;

  /// 焦点高亮描边宽度（TV 上必须明显）。
  static const double focusBorderWidth = 2.0;

  /// 焦点高亮外扩距离。
  static const double focusSpread = 3.0;

  static bool get isTv => _isTv;

  /// 探测设备类型。App 启动时调用一次即可。
  ///
  /// 平台通道不可用（非 Android 平台或宿主未实现该方法）时按非 TV 处理。
  static Future<void> probe() async {
    if (_probed) return;
    _probed = true;
    try {
      final value = await _channel.invokeMethod<bool>('isTvDevice');
      _isTv = value == true;
    } catch (_) {
      _isTv = false;
    }
    await _loadForced();
  }

  /// 读取「强制 TV 模式」的持久化设置。
  static Future<void> _loadForced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _forcedTv = prefs.getBool(_forceKey) ?? false;
    } catch (_) {
      _forcedTv = false;
    }
  }

  /// 设置「强制 TV 模式」。开启后需重启应用生效（布局在启动时确定）。
  static Future<void> setForcedTv(bool value) async {
    _forcedTv = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_forceKey, value);
    } catch (_) {}
  }

  /// 依据窗口尺寸做启发式判断。
  ///
  /// 仅供单元测试与特殊场景参考；生产路径以平台通道为准。
  ///
  /// Android TV 屏幕通常 ≥ 960dp 宽且为横屏；手机横屏一般 < 900dp。
  static bool looksLikeTv(Size size, {double? devicePixelRatio}) {
    if (size.width <= 0) return false;
    if (size.width >= 960 && size.height > 0 && size.width > size.height) {
      // 排除平板/桌面级窗口：TV 一般 density 较低（1.0~1.5）。
      final dpr = devicePixelRatio ?? 1.0;
      return dpr <= 2.0;
    }
    return false;
  }

  /// 全局尺寸缩放。非 TV 设备恒为 1.0。
  static double scale(double value) => _isTv ? value * tvScale : value;

  /// 字号缩放。
  static double font(double value) => _isTv ? value * tvScale : value;

  /// 是否应展示 TV 焦点高亮框。
  static bool get showFocusHighlight => _isTv;

  /// TV 端导航模式：强制横屏（TV 只有横屏形态）。
  static List<DeviceOrientation> get orientations => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];

  /// 供测试注入用的内部 setter。
  @visibleForTesting
  static void debugSetTv(bool value) {
    _isTv = value;
    _forcedTv = false;
    _probed = true;
  }
}
