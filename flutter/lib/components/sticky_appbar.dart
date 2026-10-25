import 'package:flutter/material.dart';

/// 固定高度的粘性 Sliver 头，参考 EcoTV `views/filter/sticky_appbar.dart`。
class StickyAppbar extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyAppbar({
    required this.child,
    this.height = 48,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(StickyAppbar oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
