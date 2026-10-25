import 'package:flutter/material.dart';

/// 筛选栏 Sliver，对齐 EcoTV `views/filter/dynamic_sliver_appbar.dart`。
///
/// 用 [SliverAppBar] 实现「视差闭合」：滚动时 FilterBar 随 flexibleSpace
/// 按视差（parallax）收缩到 toolbarHeight(0)，下方导航头再吸顶。
/// expandedHeight 由子组件实测高度动态算出（[onHeightListener] 上报），
/// 首帧用 [maxHeight] 兜底，避免写死高度。
class DynamicSliverAppBar extends StatefulWidget {
  final Widget? child;
  final double maxHeight;
  final ValueChanged<double>? onHeightListener;

  const DynamicSliverAppBar({
    super.key,
    required this.maxHeight,
    this.child,
    this.onHeightListener,
  });

  @override
  State<DynamicSliverAppBar> createState() => _DynamicSliverAppBarState();
}

class _DynamicSliverAppBarState extends State<DynamicSliverAppBar> {
  final GlobalKey _childKey = GlobalKey();
  double? _height;

  void _syncHeight() {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    var h = box.size.height;
    if (h <= 0) return;
    if (widget.maxHeight > 0 && h > widget.maxHeight) h = widget.maxHeight;
    if (_height != null && (h - _height!).abs() < 0.5) return;
    setState(() => _height = h);
    widget.onHeightListener?.call(h);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeight());
    return SliverAppBar(
      pinned: true,
      stretch: true,
      toolbarHeight: 0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      expandedHeight: _height ?? widget.maxHeight,
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (notification) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeight());
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: KeyedSubtree(
                  key: _childKey,
                  child: widget.child ?? const SizedBox.shrink(),
                ),
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
