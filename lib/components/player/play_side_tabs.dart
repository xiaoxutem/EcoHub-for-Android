import 'package:flutter/material.dart';
import '../../utils/tv_focus_scope.dart';
import '../../common/app_theme.dart';
import '../../models/film_models.dart';
import '../empty_state.dart';
import '../film_grid.dart';
import '../loading_view.dart';
import 'play_detail_panel.dart';
import '../tv_focus_item.dart';

/// 播放页面侧边/底部切换面板（详情与相关推荐）
class PlaySideTabs extends StatelessWidget {

  /// 请求把焦点移进播放器的 HUD 控制条。
  ///
  /// 侧栏与 HUD（左侧视频区右上角）几何上完全不重叠，
  /// 纯靠方向键遍历到不了 HUD（用户反馈：全屏按钮选不中）。
  /// 焦点在侧栏内时按 ↑，通过这个回调显式跳过去。
  final VoidCallback? onRequestHudFocus;

  /// 请求进入全屏播放。
  ///
  /// 播放器的 HUD 里虽然有全屏按钮，但它在**左侧视频区**的右上角，
  /// 而侧栏在右侧 —— 两者几何上完全不重叠，遥控器的方向键在侧栏里
  /// 走不到那个按钮（用户反馈：无法选择全屏）。
  /// 这里在侧栏顶部给一个**直观可见**的全屏入口，不依赖焦点遍历技巧。
  final VoidCallback? onRequestFullscreen;
  final int activeTab;
  final ValueChanged<int> onTabChange;
  final String filmId;
  final String picture;
  final String name;
  final String subTitle;
  final String actor;
  final String plot;
  final String sourceName;
  final MovieDescriptor? descriptor;
  final List<PlaySource> sources;
  final String playingSourceId;
  final String viewingSourceId;
  final int episodeIndex;
  final bool isSplit;
  final double rightInset;
  final ValueChanged<String> onViewSource;
  final void Function(String sourceId, int index) onSelectEpisode;
  final bool relateLoading;
  final List<MovieBasicInfo> related;
  final int columns;
  final ValueChanged<MovieBasicInfo> onOpenRelated;

  const PlaySideTabs({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.filmId,
    required this.picture,
    required this.name,
    this.subTitle = '',
    this.actor = '',
    this.plot = '',
    this.sourceName = '',
    this.descriptor,
    required this.sources,
    required this.playingSourceId,
    required this.viewingSourceId,
    required this.episodeIndex,
    this.isSplit = false,
    this.rightInset = 0,
    required this.onViewSource,
    required this.onSelectEpisode,
    required this.relateLoading,
    required this.related,
    required this.columns,
    required this.onOpenRelated,
    this.onRequestHudFocus,
    this.onRequestFullscreen,
  });

  Widget _buildTabItem(String title, int index) {
    final active = activeTab == index;
    // TvFocusItem：按 → 显式跳到「全屏」按钮。
    //
    // 为什么需要：Tab 行与下方的线路 / 清晰度 chip 在 **x 方向重叠**，
    // Flutter 的阅读顺序遍历（几何感知）在 → 时会选到下面的 chip ——
    // 表现为焦点在「详情」和「HD国语」之间来回跳，永远到不了右上角的全屏。
    return TvFocusItem(
      zone: 'player_tab',
      index: index,
      rightZone: 'player_fullscreen',
      rightIndex: 0,
      behavior: HitTestBehavior.opaque,
      focusRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: () => onTabChange(index),
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: active ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
            Container(
              width: 18,
              height: 3,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: active ? AppTheme.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedTab() {
    if (relateLoading) {
      return const LoadingView(label: '加载相关推荐');
    }
    if (related.isEmpty) {
      return EmptyState(
        title: '暂无相关推荐',
        subtitle: sourceName.isNotEmpty ? '当前采集源该分类下暂无其它片源' : '换一部片子再看看',
        icon: Icons.movie_outlined,
      );
    }
    return FilmGrid(
      films: related,
      columns: columns,
      padding: EdgeInsets.fromLTRB(12, 4, 12 + rightInset, 12),
      onClickFilm: onOpenRelated,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusItem(
      // 拦截点放在侧栏**最内层**（而不是外层容器）——
      // 外层容器与焦点之间隔着若干组件，那些组件可能先消费掉 ↑ 事件，
      // 导致焦点跳转的按键根本冒泡不到。
      zone: 'player_side',
      index: 0,
      upZone: 'player_hud',
      upIndex: 0,
      // 容器只做区域登记，**不拦截按键** ——
      // 拦截 ↑ 会阻止 Flutter 默认的几何遍历（HD中字 → 详情 Tab），
      // 表现为焦点在侧栏里上下动不了。
      // 容器也不画焦点框（否则整个侧栏都会有一圈橙框）。
      showHighlight: false,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab Switcher
        Container(
          height: 44,
          padding: EdgeInsets.only(left: 12, right: 12 + rightInset),
          child: Row(
            children: [
              _buildTabItem('详情', 0),
              _buildTabItem(sourceName.isNotEmpty ? '同类推荐' : '相关推荐', 1),
              const Spacer(),
              // 全屏快捷入口（电视上必需 —— HUD 的全屏按钮在另一侧，走不到）
              if (onRequestFullscreen != null)
                TvFocusItem(
                  zone: 'player_fullscreen',
                  index: 0,
                  focusRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: onRequestFullscreen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fullscreen_rounded,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '全屏',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Tab Contents
        Expanded(
          child: activeTab == 0
              ? PlayDetailPanel(
                  onRequestFullscreen: onRequestFullscreen,
                  focusBridge: TvFocusScope.maybeOf(context),
                  filmId: filmId,
                  picture: picture,
                  name: name,
                  subTitle: subTitle,
                  actor: actor,
                  plot: plot,
                  sourceName: '',
                  descriptor: descriptor,
                  sources: sources,
                  playingSourceId: playingSourceId,
                  viewingSourceId: viewingSourceId,
                  episodeIndex: episodeIndex,
                  isSplit: isSplit,
                  episodeColumns: isSplit ? 3 : null,
                  rightInset: rightInset,
                  onViewSource: onViewSource,
                  onSelectEpisode: onSelectEpisode,
                )
              : _buildRelatedTab(),
        ),
      ],
      ),
    );
  }
}
