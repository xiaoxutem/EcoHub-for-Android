import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_mode.dart';

/// 绘制 TV 焦点高亮框的叠加层。
///
/// 关键点：焦点框用 [DecoratedBox] 的 `DecorationPosition.foreground` 叠加绘制，
/// **不占用布局空间**。若改用 `BoxDecoration` + `Border`，其 `decoration.padding`
/// 会把边框宽度加进内边距，导致获得/失去焦点时元素尺寸跳动（电视上会引发焦点漂移）。
class _FocusBorderOverlay extends StatelessWidget {
  final bool focused;
  final BorderRadius radius;
  final Color color;
  final double spread;

  const _FocusBorderOverlay({
    required this.focused,
    required this.radius,
    required this.color,
    required this.spread,
  });

  @override
  Widget build(BuildContext context) {
    if (!focused) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color, width: TvMode.focusBorderWidth),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 12,
                spreadRadius: spread,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 遥控器可聚焦的点击容器。
///
/// Flutter 的 `GestureDetector` **不可聚焦**，因此原项目里大量
/// `GestureDetector(onTap: ...)` 在 TV 遥控器下完全无法被选中。
///
/// 本组件在 TV 模式下额外提供：
/// - [Focus] 节点，参与方向键焦点遍历；
/// - `Enter` / `Select` / `Space` / `gameButtonA` 等按键映射到点击；
/// - 明显的焦点高亮框（描边 + 轻微放大），让用户知道当前选中项；
/// - 焦点进入时自动把目标滚动进可视区域。
///
/// 非 TV 模式下退化为原始 [GestureDetector]，行为与原来完全一致，
/// 因此手机端交互与现有单测都不受影响。
class FocusTap extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final Widget child;

  /// 焦点高亮形状，默认圆角矩形。
  final BorderRadius? focusRadius;

  /// 自定义焦点高亮描边色，默认主题橙色。
  final Color? focusColor;

  /// 焦点高亮框的外发光扩散距离。
  final double focusSpread;

  /// 是否在获得焦点时自动滚动进视口。
  final bool autoEnsureVisible;

  const FocusTap({
    super.key,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.deferToChild,
    required this.child,
    this.focusRadius,
    this.focusColor,
    this.focusSpread = TvMode.focusSpread,
    this.autoEnsureVisible = true,
  });

  @override
  State<FocusTap> createState() => _FocusTapState();
}

class _FocusTapState extends State<FocusTap> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'FocusTap');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    final focused = _focusNode.hasFocus;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
    if (focused && widget.autoEnsureVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  void _ensureVisible() {
    if (!mounted || !_focusNode.hasFocus) return;
    if (!context.mounted) return;
    // [Scrollable.ensureVisible] 需要 BuildContext：它内部会用
    // context.findRenderObject() 定位要滚入视口的目标。
    Scrollable.ensureVisible(
      context,
      // alignment: 0 —— 与项目既有约定一致（见 filter_tag_row.dart 的 _jumpSelected）：
      // 焦点项贴到可视区边缘而非被居中，避免长列表每次移动焦点都大幅重排。
      alignment: 0,
      duration: const Duration(milliseconds: 180),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // 遥控器 OK 键在 Android 上通常是 ENTER / DPAD_CENTER(映射为 enter)，
    // 部分遥控器额外发送 SELECT；手柄 A 键一并兼容。
    final isActivate = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!isActivate) return KeyEventResult.ignored;
    if (widget.onTap == null) return KeyEventResult.ignored;
    widget.onTap!.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final detector = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );

    if (!TvMode.isTvActive) {
      // 手机/平板：保持原始行为，零差异。
      return detector;
    }

    final radius = widget.focusRadius ?? BorderRadius.circular(8);
    final color = widget.focusColor ?? const Color(0xFFFA8C16);

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.onTap != null || widget.onLongPress != null,
      skipTraversal: widget.onTap == null && widget.onLongPress == null,
      onKeyEvent: _handleKey,
      // 刻意**不用** AnimatedScale 做「选中放大」：缩放会改变渲染尺寸，
      // 焦点框与相邻元素的相对位置随之漂移，电视上表现为焦点框跳动/错位。
      // 纯描边高亮不影响布局，位置绝对稳定。
      child: Stack(
        // 必须用 passthrough：Stack 默认的 loose 会把传入的紧约束放宽，
        // 导致 Expanded 等场景下子组件塌陷成 0 尺寸（TV 与手机布局不一致）。
        fit: StackFit.passthrough,
        children: [
          detector,
          _FocusBorderOverlay(
            focused: _focused,
            radius: radius,
            color: color,
            spread: widget.focusSpread,
          ),
        ],
      ),
    );
  }
}

/// TV 焦点高亮描边，用于把既有的可聚焦控件（如 [InkWell]）也纳入统一视觉。
///
/// [InkWell] 本身自带焦点能力（`canRequestFocus` 默认 true），
/// 但默认焦点高亮很弱，在电视上几乎看不出来，这里补一层明显的描边。
///
/// 实现要点：**监听 [FocusManager.primaryFocus] 的变化**，
/// 沿焦点节点的祖先链回溯，判断当前焦点是否落在本组件子树内。
///
/// 为什么不用 `FocusableActionDetector`：
/// 它的 `onShowFocusHighlight` 受 `FocusManager.highlightMode` 门控 ——
/// Android 默认是 `touch` 模式（首次硬件按键前不显示焦点框），
/// 而 TV 上焦点框必须**始终可见**，该机制不可靠。
///
/// 为什么不用自建的观察型 `Focus` 节点：
/// `canRequestFocus: true` 的观察节点会**抢走**方向键焦点，
/// 导致真正的 InkWell 反而拿不到焦点（实测按方向键后 `primaryFocus` 变为 null）。
class FocusHighlight extends StatefulWidget {
  final Widget child;
  final BorderRadius? radius;
  final Color? color;
  final double focusSpread;

  const FocusHighlight({
    super.key,
    required this.child,
    this.radius,
    this.color,
    this.focusSpread = TvMode.focusSpread,
  });

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    final focused = _primaryFocusInSubtree();
    if (focused != _focused) setState(() => _focused = focused);
  }

  /// 判断当前主焦点是否位于本组件子树内。
  ///
  /// 沿焦点节点的祖先链回溯，比较其所属 Element 是否是本组件的后代。
  bool _primaryFocusInSubtree() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    FocusNode? node = primary;
    while (node != null) {
      final ctx = node.context;
      if (ctx != null) {
        var found = false;
        ctx.visitAncestorElements((ancestor) {
          if (identical(ancestor.widget, widget)) {
            found = true;
            return false;
          }
          return true;
        });
        if (found) return true;
      }
      node = node.parent;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!TvMode.isTvActive) return widget.child;
    final color = widget.color ?? const Color(0xFFFA8C16);
    final radius = widget.radius ?? BorderRadius.circular(8);
    return Stack(
      // passthrough 保持传入约束不被放宽，
      // 避免 Expanded 等场景下子组件塌陷。
      fit: StackFit.passthrough,
      children: [
        widget.child,
        _FocusBorderOverlay(
          focused: _focused,
          radius: radius,
          color: color,
          spread: widget.focusSpread,
        ),
      ],
    );
  }
}
