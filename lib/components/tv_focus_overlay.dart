import 'package:flutter/material.dart';

import '../utils/tv_mode.dart';

/// 全局 TV 焦点框层。
///
/// ## 为什么需要它
///
/// Material 自带控件（`InkWell` / `TextButton` / `ElevatedButton` / `Switch` …）
/// 虽然默认可聚焦，但**默认焦点高亮在电视上几乎不可见**。
/// 此前只能逐个用 [FocusHighlight] 包裹 —— 实测漏了一大片
/// （关于页、我的收藏、历史记录、影片详情弹窗、错误页、投屏面板……），
/// 逐个补永远补不干净。
///
/// 这个组件改为**在应用顶层监听焦点节点的位置并绘制描边**：
/// 任何能获得焦点的控件都会自动带上橙色高亮框，一劳永逸。
///
/// ## 实现要点
///
/// - 监听 [FocusManager.primaryFocus] 的变化；
/// - 用焦点节点的 RenderObject 拿到屏幕上的矩形；
/// - 用 [Overlay] 画在所有内容之上，不影响布局（不引起焦点漂移）；
/// - 只在 TV 模式启用，手机端零影响。
class TvFocusOverlay extends StatefulWidget {
  final Widget child;

  const TvFocusOverlay({
    super.key,
    required this.child,
  });

  @override
  State<TvFocusOverlay> createState() => _TvFocusOverlayState();
}

class _TvFocusOverlayState extends State<TvFocusOverlay> {
  /// 当前焦点控件在屏幕上的矩形。
  Rect? _rect;

  /// 焦点矩形上一次的值，用于做平滑过渡。
  Rect? _previousRect;

  /// 焦点框绘制层。
  ///
  /// 必须插到 **rootOverlay** 顶层 —— 否则会被 Dialog / 弹窗盖住
  ///（弹窗在 Navigator 的 Overlay 里，而本组件在 builder 子树里）。
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    if (TvMode.isTvActive) {
      FocusManager.instance.addListener(_handleFocusChange);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _insertEntry();
        _handleFocusChange();
      });
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  /// 把焦点框绘制层插到 rootOverlay 顶层。
  void _insertEntry() {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (ctx) {
        final rect = _rect;
        if (rect == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FocusRingPainter(rect: rect, previous: _previousRect),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    final rect = _currentFocusRect();
    if (rect == null) {
      if (_rect != null) {
        setState(() => _rect = null);
        _entry?.markNeedsBuild();
      }
      return;
    }
    // 位置没变就不重绘，避免每次焦点事件都触发 rebuild。
    if (_rect != null && _rect == rect) return;
    setState(() {
      _previousRect = _rect;
      _rect = rect;
    });
    // OverlayEntry 需要手动 markNeedsBuild 才会重绘。
    _entry?.markNeedsBuild();
  }

  /// 取当前焦点控件在屏幕上的矩形。
  Rect? _currentFocusRect() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return null;

    // 焦点节点可能还没挂载到渲染树（刚创建、或正在切换）。
    final ctx = primary.context;
    if (ctx == null || !ctx.mounted) return null;

    final object = ctx.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    if (!object.attached) return null;

    final origin = object.localToGlobal(Offset.zero);
    return origin & object.size;
  }

  @override
  Widget build(BuildContext context) {
    if (!TvMode.isTvActive) return widget.child;
    return widget.child;
  }
}

/// 绘制橙色焦点框。
class _FocusRingPainter extends CustomPainter {
  final Rect rect;
  final Rect? previous;

  const _FocusRingPainter({
    required this.rect,
    this.previous,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = BorderRadius.circular(8);
    final color = const Color(0xFFFA8C16);

    // 外发光
    canvas.drawRRect(
      radius.toRRect(rect.inflate(1)),
      Paint()
        ..color = color.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 主描边
    canvas.drawRRect(
      radius.toRRect(rect.inflate(1)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = TvMode.focusBorderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.previous != previous;
  }
}
