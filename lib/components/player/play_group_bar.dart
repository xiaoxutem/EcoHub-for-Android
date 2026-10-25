import 'package:flutter/material.dart';
import '../tv_focus_item.dart';
import '../../utils/tv_focus_bridge.dart';
import '../../common/app_theme.dart';
import '../../models/film_models.dart';

/// 播放源切换与大选集分组横滑栏组件
class PlayGroupBar extends StatelessWidget {
  static const double dividerHeight = 1.0;
  static const double sourceRowHeight = 32.0;
  static const double sourceRowMarginTop = 10.0;
  static const double sourceBottomSpacing = 10.0;
  static const double groupRowHeight = 30.0;
  static const double groupRowMarginTop = 10.0;
  static const double groupBottomSpacing = 12.0;

  static double calculateHeight({
    required bool hasSources,
    required bool needsGrouping,
  }) {
    if (!hasSources && !needsGrouping) return 0.0;
    double h = dividerHeight;
    if (hasSources) {
      h += sourceRowMarginTop + sourceRowHeight;
    }
    if (needsGrouping) {
      h += groupRowMarginTop + groupRowHeight + groupBottomSpacing;
    } else if (hasSources) {
      h += sourceBottomSpacing;
    }
    return h;
  }

  final List<PlaySource> sources;
  final String viewingSourceId;
  final ValueChanged<String>? onViewSource;

  /// 请求进入全屏播放（电视上必需 —— HUD 的全屏按钮在视频区另一侧，走不到）。
  final VoidCallback? onRequestFullscreen;

  /// 焦点协调器：让线路 chip 按 → 显式跳到「全屏」按钮。
  ///
  /// 为什么必须显式跳转：线路 chip 在**横向滚动容器**里，
  /// 而「全屏」按钮在 Tab 行（另一个容器）——
  /// Flutter 的几何感知遍历在跨容器、x 方向重叠时行为不可预测，
  /// 实测焦点会在「HD国语」和「第01集」之间来回跳，永远到不了全屏。
  final TvFocusBridge? focusBridge;
  final bool needsGrouping;
  final int groupCount;
  final int currentGroup;
  final ValueChanged<int> onSelectGroup;
  final String Function(int index) groupLabel;
  final ScrollController? sourceScroller;
  final ScrollController? groupScroller;
  final double rightInset;
  final Map<String, GlobalKey>? sourceKeys;
  final Map<int, GlobalKey>? groupKeys;
  final GlobalKey? sourceRowKey;
  final GlobalKey? groupRowKey;

  const PlayGroupBar({
    super.key,
    required this.sources,
    required this.viewingSourceId,
    this.onViewSource,
    this.onRequestFullscreen,
    this.focusBridge,
    required this.needsGrouping,
    required this.groupCount,
    required this.currentGroup,
    required this.onSelectGroup,
    required this.groupLabel,
    this.sourceScroller,
    this.groupScroller,
    this.rightInset = 0,
    this.sourceKeys,
    this.groupKeys,
    this.sourceRowKey,
    this.groupRowKey,
  });

  Widget _buildSourceChip(PlaySource source, int index) {
    final active = viewingSourceId == source.id;
    final chip = InkWell(
      key: sourceKeys?[source.id],
      onTap: () => onViewSource?.call(source.id),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Container(
        height: sourceRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.bgChip,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.check_rounded, size: 12, color: AppTheme.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(
              source.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
    if (focusBridge == null) return chip;
    // TvFocusItem：按 → 显式跳到「全屏」按钮（绕过不可预测的几何遍历）。
    return TvFocusItem(
      bridge: focusBridge,
      zone: 'player_line',
      index: index,
      // → 直接跳到 Tab 行右上角那个「全屏」按钮
      // （它在固定位置、不会被横向滚动裁掉，始终可见可聚焦）。
      rightZone: 'player_fullscreen',
      rightIndex: 0,
      // ↑ 直接跳到播放器 HUD 的第一个按钮（返回键）。
      //
      // 必须显式指定：线路 chip 在**横向 SingleChildScrollView** 里，
      // Flutter 的 Scrollable 会先消费方向键做滚动 ——
      // 只要右边还有 chip，↑ 就被吃掉，焦点永远出不了这一行。
      upZone: 'player_hud',
      upIndex: 0,
      focusRadius: BorderRadius.circular(AppTheme.radiusPill),
      onTap: () => onViewSource?.call(source.id),
      child: chip,
    );
  }


  Widget _buildGroupChip(int index) {
    final active = currentGroup == index;
    final chip = InkWell(
      key: groupKeys?[index],
      onTap: () => onSelectGroup(index),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: groupRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.bgChip,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          groupLabel(index),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );

    // TvFocusItem：↑ 显式跳到播放器 HUD（返回 / 投屏 / 画中画 / 全屏）。
    //
    // 必须显式指定：分组 chip 在**横向 SingleChildScrollView** 里，
    // Flutter 的 Scrollable 会先消费方向键做滚动 —— 焦点出不了这一行。
    return TvFocusItem(
      bridge: focusBridge,
      zone: 'player_group',
      index: index,
      // ↑ 跳到侧栏右上角的「全屏」按钮。
      //
      // 为什么不是直接跳 HUD：分组 chip 在**横向 SingleChildScrollView** 里，
      // Scrollable 会先消费 ↑ 做滚动 —— 焦点出不了这一行。
      // 侧栏「全屏」按钮不在滚动容器里，焦点能稳稳停住并显示橙色焦点框。
      // 再按一次 ↑ 才会从它跳到视频区顶部的 HUD。
      upZone: 'player_fullscreen',
      upIndex: 0,
      focusRadius: BorderRadius.circular(AppTheme.radiusPill),
      onTap: () => onSelectGroup(index),
      child: chip,
    );

  }

  @override
  Widget build(BuildContext context) {
    final hasSources = sources.length > 1;
    if (!hasSources && !needsGrouping) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppTheme.borderSolid, height: dividerHeight),

        // 播放源横滑栏 (sourceRow)
        if (hasSources)
          Container(
            height: sourceRowHeight,
            margin: const EdgeInsets.only(top: sourceRowMarginTop),
            child: SingleChildScrollView(
              controller: sourceScroller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 12, right: 16 + rightInset),
              child: Row(
                key: sourceRowKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < sources.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildSourceChip(sources[i], i),
                  ],
                ],
              ),
            ),
          ),

        // 选集分组横滑栏 (groupBar)
        if (needsGrouping) ...[
          Container(
            height: groupRowHeight,
            margin: const EdgeInsets.only(top: groupRowMarginTop),
            child: SingleChildScrollView(
              controller: groupScroller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 12, right: 16 + rightInset),
              child: Row(
                key: groupRowKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < groupCount; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildGroupChip(i),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: groupBottomSpacing),
        ] else ...[
          const SizedBox(height: sourceBottomSpacing),
        ],
      ],
    );
  }
}

/// 选集控制栏吸顶 Delegate
class StickyGroupBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyGroupBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      width: double.infinity,
      color: AppTheme.bg,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant StickyGroupBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
