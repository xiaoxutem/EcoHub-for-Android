import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// 横屏分栏左右 inset。
/// 每边用自己的 padding；挖孔用 [displayFeatures] 补。
/// 只在某一边确认有挖孔时，对侧归零贴边。
class SplitCutoutInsets {
  const SplitCutoutInsets({required this.left, required this.right});

  final double left;
  final double right;

  factory SplitCutoutInsets.resolve(
    EdgeInsets viewPadding, {
    EdgeInsets padding = EdgeInsets.zero,
    List<DisplayFeature> displayFeatures = const [],
    Size size = Size.zero,
  }) {
    var left = math.max(viewPadding.left, padding.left);
    var right = math.max(viewPadding.right, padding.right);

    var holeLeft = 0.0;
    var holeRight = 0.0;
    if (size.width > 0) {
      for (final f in displayFeatures) {
        if (f.type != DisplayFeatureType.cutout) continue;
        if (f.bounds.center.dx >= size.width / 2) {
          holeRight = math.max(holeRight, size.width - f.bounds.left);
        } else {
          holeLeft = math.max(holeLeft, f.bounds.right);
        }
      }
    }

    if (holeLeft > 0) left = math.max(left, holeLeft);
    if (holeRight > 0) right = math.max(right, holeRight);

    // 1. 如果 displayFeatures 明确包含挖孔，优先以挖孔侧为准，对侧归零
    if (holeRight > 0 && holeLeft == 0) {
      return SplitCutoutInsets(left: 0, right: right);
    }
    if (holeLeft > 0 && holeRight == 0) {
      return SplitCutoutInsets(left: left, right: 0);
    }

    // 2. 真实设备上 displayFeatures 通常为空，通过左右两边 inset 差异识别单侧刘海
    // 主刘海侧通常显著大于非刘海侧（非刘海侧可能为手势条、虚拟按键等系统边距）
    if (left > right) {
      right = 0;
    } else if (right > left) {
      left = 0;
    }

    return SplitCutoutInsets(left: left, right: right);
  }
}
