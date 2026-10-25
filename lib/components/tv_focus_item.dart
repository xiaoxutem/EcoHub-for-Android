import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_focus_bridge.dart';
import '../utils/tv_focus_scope.dart';
import '../utils/tv_mode.dart';
import 'focus_wrap.dart';

/// TV 焦点项：可聚焦 + 明显高亮框 + 跨区域方向键跳转。
///
/// 解决的问题：
///
/// 1. **焦点高亮** —— Material 自带高亮在电视上几乎不可见，
///    这里用 [FocusHighlight] 画橙色描边 + 外发光。
/// 2. **焦点乱跳** —— 「横向分类标题行 + 若干横向电影行」这种布局里，
///    各区域几何位置挨得很近，Flutter 默认的几何感知焦点遍历会让 ↓/↑
///    在区域之间反复横跳。这里通过 [TvFocusBridge] **显式指定**跳转目标，
///    行为完全确定。
///
/// 用法：
/// ```dart
/// TvFocusItem(
///   bridge: bridge,
///   zone: 'category',
///   index: 0,
///   downZone: 'row',   // 按 ↓ 跳到 row 区域
///   downIndex: 0,
///   child: const MyCard(),
/// )
/// ```
class TvFocusItem extends StatefulWidget {
  final Widget child;

  /// 焦点协调器（可选；不传则只做高亮）。
  final TvFocusBridge? bridge;

  /// 所在区域名。
  final String? zone;

  /// 在区域内的下标。
  final int index;

  /// 按 ↓ 时的目标区域。
  final String? downZone;
  final int downIndex;

  /// 按 ↑ 时的目标区域。
  final String? upZone;
  final int upIndex;

  /// 按 → 时的目标区域。
  final String? rightZone;

  /// 按 → 时的目标区域内的下标。
  final int rightIndex;

  /// 按 ← 时的目标区域。
  final String? leftZone;

  /// 按 ← 时的目标区域内的下标。
  final int leftIndex;

  /// 焦点框形状。
  final BorderRadius? focusRadius;

  /// 是否可聚焦（false 时不可获取焦点，仅渲染高亮）。
  final bool canRequestFocus;

  /// 获得焦点时是否自动滚进视口。
  final bool autoEnsureVisible;

  /// 点击回调（同时响应遥控器 OK 键）。
  final VoidCallback? onTap;

  /// 点击的命中行为。
  final HitTestBehavior behavior;

  /// 是否绘制焦点高亮框。
  ///
  /// 容器型用法（只是包一层做按键拦截）应设为 false ——
  /// 否则整个容器都会画出一圈大橙框，看起来像「整块被选中」。
  final bool showHighlight;

  /// 按 ↑ 时的自定义处理（返回 true 表示已处理）。
  ///
  /// 优先级高于 [bridge] 的登记目标 —— 用于「容器包住子元素」的场景：
  /// 焦点在子元素上时，按键事件冒泡到本组件的 `Focus` 节点，
  /// 此时可以直接执行跳转，不必依赖 bridge 的注册时序。
  final bool Function()? onFocusUp;

  const TvFocusItem({
    super.key,
    required this.child,
    this.bridge,
    this.zone,
    this.index = 0,
    this.downZone,
    this.downIndex = 0,
    this.upZone,
    this.upIndex = 0,
    this.rightZone,
    this.rightIndex = 0,
    this.leftZone,
    this.leftIndex = 0,
    this.focusRadius,
    this.canRequestFocus = true,
    this.autoEnsureVisible = true,
    this.onTap,
    this.behavior = HitTestBehavior.deferToChild,
    this.onFocusUp,
    this.showHighlight = true,
  });

  @override
  State<TvFocusItem> createState() => _TvFocusItemState();
}

class _TvFocusItemState extends State<TvFocusItem> {
  final FocusNode _node = FocusNode(debugLabel: 'TvFocusItem');

  /// 从 [TvFocusScope] 取得的协调器。
  ///
  /// 必须在 [didChangeDependencies] 里缓存 —— 在 [dispose] 中查 InheritedWidget
  /// 会抛「Looking up a deactivated widget's ancestor is unsafe」。
  TvFocusBridge? _scopeBridge;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bridge = TvFocusScope.maybeOf(context);
    if (identical(bridge, _scopeBridge)) return;
    _unregister(oldWidgetZone: widget.zone, oldWidgetIndex: widget.index);
    _scopeBridge = bridge;
    _register();
  }

  @override
  void didUpdateWidget(covariant TvFocusItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone != widget.zone || oldWidget.index != widget.index) {
      _unregister(oldWidgetZone: oldWidget.zone, oldWidgetIndex: oldWidget.index);
      _register();
    }
  }

  @override
  void dispose() {
    _unregister(oldWidgetZone: widget.zone, oldWidgetIndex: widget.index);
    _node.dispose();
    super.dispose();
  }

  void _register() {
    final bridge = widget.bridge ?? _scopeBridge;
    final zone = widget.zone;
    if (bridge == null || zone == null) return;
    bridge.register(
      zone: zone,
      index: widget.index,
      node: _node,
      downZone: widget.downZone,
      downIndex: widget.downIndex,
      upZone: widget.upZone,
      upIndex: widget.upIndex,
      rightZone: widget.rightZone,
      rightIndex: widget.rightIndex,
      leftZone: widget.leftZone,
      leftIndex: widget.leftIndex,
    );
  }

  void _unregister({String? oldWidgetZone, int oldWidgetIndex = 0}) {
    final bridge = widget.bridge ?? _scopeBridge;
    final zone = oldWidgetZone;
    if (bridge == null || zone == null) return;
    bridge.unregister(zone, oldWidgetIndex);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // 遥控器 OK 键 → 触发点击。
    final isActivate = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
    if (isActivate) {
      final tap = widget.onTap;
      if (tap == null) return KeyEventResult.ignored;
      tap();
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.arrowUp && key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    // 自定义回调优先（用于容器包住子元素的场景）。
    final custom = widget.onFocusUp;
    if (custom != null && key == LogicalKeyboardKey.arrowUp) {
      return custom() ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    final bridge = widget.bridge ?? _scopeBridge;
    final zone = widget.zone;
    if (bridge == null || zone == null) return KeyEventResult.ignored;
    final handled = bridge.handleDirection(
      zone: zone,
      index: widget.index,
      key: key,
    );
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // 点击行为在所有平台都保留 —— 非 TV 模式下只去掉焦点能力与高亮框，
    // 交互语义与普通容器完全一致。
    Widget content = widget.child;
    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        child: content,
      );
    }

    if (!TvMode.isTvActive) return content;

    return Focus(
      focusNode: _node,
      canRequestFocus: widget.canRequestFocus,
      onKeyEvent: _handleKey,
      child: widget.showHighlight
          ? FocusHighlight(
              radius: widget.focusRadius,
              child: content,
            )
          : content,
    );
  }
}
