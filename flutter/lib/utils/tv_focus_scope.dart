import 'package:flutter/material.dart';

import 'tv_focus_bridge.dart';

/// 把 [TvFocusBridge] 下发给子树。
///
/// 用途：协调器需要被深层组件使用（例如「更新」页的网格在
/// `DailyUpdatePane` 内部，而分类切换 chip 在页面层），
/// 用 InheritedWidget 下发比逐层传参干净得多。
class TvFocusScope extends InheritedWidget {
  final TvFocusBridge bridge;

  const TvFocusScope({
    super.key,
    required this.bridge,
    required super.child,
  });

  /// 取最近的 [TvFocusScope]（没有则返回 null）。
  static TvFocusBridge? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvFocusScope>()?.bridge;
  }

  /// 取最近的 [TvFocusScope]，没有则返回一个空协调器（所有跳转都是空操作）。
  static TvFocusBridge of(BuildContext context) {
    return maybeOf(context) ?? TvFocusBridge();
  }

  @override
  bool updateShouldNotify(TvFocusScope oldWidget) {
    return oldWidget.bridge != bridge;
  }
}
