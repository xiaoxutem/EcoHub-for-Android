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

  const _FocusBorderOverlay({
    required this.focused,
    required this.radius,
    required this.color,
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
                color: color.withValues(alpha: 0.32),
                blurRadius: 10,
                spreadRadius: TvMode.focusSpread,
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

  /// 高亮框是否随焦点一起放大。
  final bool focusScaleEnabled;

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
    this.focusScaleEnabled = true,
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
      alignment: 0.5,
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

    if (!TvMode.isTv) {
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
      child: AnimatedScale(
        scale: _focused && widget.focusScaleEnabled ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Stack(
          // 必须用 passthrough：Stack 默认的 loose 会把传入的紧约束放宽，
          // 导致 Expanded 等场景下子组件塌陷成 0 尺寸（TV 与手机布局不一致）。
          fit: StackFit.passthrough,
          children: [
            detector,
            _FocusBorderOverlay(focused: _focused, radius: radius, color: color),
          ],
        ),
      ),
    );
  }
}

/// TV 焦点高亮描边，用于把既有的可聚焦控件（如 [InkWell]）也纳入统一视觉。
///
/// [InkWell] 本身自带焦点能力（`canRequestFocus` 默认 true），
/// 但默认焦点高亮很弱，在电视上几乎看不出来，这里补一层明显的描边。
///
/// 实现要点：用 `canRequestFocus: false` 的观察型 [Focus] 节点。
/// `FocusNode.hasFocus` 在「焦点位于本节点子树内」时同样为 true，
/// 因此子级 InkWell 获得焦点时，本节点能同步感知到。
class FocusHighlight extends StatefulWidget {
  final Widget child;
  final BorderRadius? radius;
  final Color? color;
  final bool scaleEnabled;

  const FocusHighlight({
    super.key,
    required this.child,
    this.radius,
    this.color,
    this.scaleEnabled = true,
  });

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  final FocusNode _node = FocusNode(debugLabel: 'FocusHighlight');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_handle);
  }

  @override
  void dispose() {
    _node.removeListener(_handle);
    _node.dispose();
    super.dispose();
  }

  void _handle() {
    if (!mounted) return;
    final focused = _node.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    if (!TvMode.isTv) return widget.child;
    final color = widget.color ?? const Color(0xFFFA8C16);
    final radius = widget.radius ?? BorderRadius.circular(8);
    return Focus(
      focusNode: _node,
      // 不参与遍历，只作为焦点状态观察者：真正的焦点节点在子树的 InkWell 上。
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: true,
      child: AnimatedScale(
        scale: _focused && widget.scaleEnabled ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Stack(
          // 与 FocusTap 一致：passthrough 保持传入约束不被放宽，
          // 避免 Expanded 等场景下子组件塌陷。
          fit: StackFit.passthrough,
          children: [
            widget.child,
            _FocusBorderOverlay(focused: _focused, radius: radius, color: color),
          ],
        ),
      ),
    );
  }
}
