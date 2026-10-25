import 'package:flutter/services.dart';

/// 全局默认屏幕方向，对齐 OHOS `window.Orientation.AUTO_ROTATION_RESTRICTED`
/// （竖屏 + 左右横屏，排除倒置竖屏）。
const List<DeviceOrientation> kAutoRotationOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
