import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import '../../components/player/play_side_tabs.dart';
import '../../models/film_models.dart';
import '../../utils/breakpoint.dart';
import '../../utils/split_cutout_insets.dart';
import '../tv_focus_item.dart';

/// 现场播放页的主体布局（分屏与非分屏），对齐 PlayPage
class LivePlayBody extends StatelessWidget {

  /// 请求把焦点移进播放器的 HUD 控制条。
  ///
  /// 侧栏（线路 / 选集 / 详情）在**右侧**，HUD 按钮在**左侧视频区**右上角，
  /// 两者几何上完全不重叠 —— 纯靠方向键遍历永远到不了 HUD
  /// （用户反馈：全屏按钮选不中）。侧栏按 ↑ 时通过这个回调显式跳过去。
  final VoidCallback? onRequestHudFocus;

  /// 请求进入全屏播放（侧栏顶部的全屏按钮）。
  final VoidCallback? onRequestFullscreen;
  final bool isSplit;
  final Widget playerWidget;
  final int activeTab;
  final ValueChanged<int> onTabChange;
  final String filmId;
  final String picture;
  final String name;
  final String subTitle;
  final String actor;
  final String plot;
  final MovieDescriptor? descriptor;
  final List<PlaySource> sources;
  final String playingSourceId;
  final String viewingSourceId;
  final int episodeIndex;
  final ValueChanged<String> onViewSource;
  final void Function(String sourceId, int index) onSelectEpisode;
  final bool relateLoading;
  final List<MovieBasicInfo> related;
  final void Function(MovieBasicInfo film) onOpenRelated;
  final String sourceName;

  const LivePlayBody({
    super.key,
    required this.isSplit,
    required this.playerWidget,
    required this.activeTab,
    required this.onTabChange,
    required this.filmId,
    required this.picture,
    required this.name,
    required this.subTitle,
    required this.actor,
    required this.plot,
    this.descriptor,
    required this.sources,
    required this.playingSourceId,
    required this.viewingSourceId,
    required this.episodeIndex,
    required this.onViewSource,
    required this.onSelectEpisode,
    required this.relateLoading,
    required this.related,
    required this.onOpenRelated,
    required this.sourceName,
    this.onRequestHudFocus,
    this.onRequestFullscreen,
  });

  Widget _buildSideTabs(BuildContext context, {required int columns, bool split = false, double rightInset = 0}) {
    return PlaySideTabs(
      onRequestHudFocus: onRequestHudFocus,
      onRequestFullscreen: onRequestFullscreen,
      activeTab: activeTab,
      onTabChange: onTabChange,
      filmId: filmId,
      picture: picture,
      name: name,
      subTitle: subTitle,
      actor: actor,
      plot: plot,
      descriptor: descriptor,
      sources: sources,
      playingSourceId: playingSourceId,
      viewingSourceId: viewingSourceId,
      episodeIndex: episodeIndex,
      isSplit: split,
      rightInset: rightInset,
      onViewSource: onViewSource,
      onSelectEpisode: onSelectEpisode,
      relateLoading: relateLoading,
      related: related,
      columns: columns,
      onOpenRelated: onOpenRelated,
      sourceName: sourceName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSplit) {
      final media = MediaQuery.of(context);
      final cutout = SplitCutoutInsets.resolve(
        media.viewPadding,
        padding: media.padding,
        displayFeatures: media.displayFeatures,
        size: media.size,
      );

      return Row(
        children: [
          Expanded(
            flex: 7,
            child: playerWidget,
          ),
          Container(width: 1, color: const Color(0x24FFFFFF)),
          Expanded(
            flex: 5,
            // TvFocusItem：侧栏按 ↑ 显式跳到播放器的 HUD 按钮
            //（全屏按钮就在那里）。
            //
            // 为什么需要显式跳转：HUD 按钮在左侧视频区的右上角，
            // 侧栏在右侧，两者**几何上完全不重叠** ——
            // 纯靠方向键的几何遍历永远走不到 HUD。
            child: TvFocusItem(
              zone: 'player_side',
              index: 0,
              upZone: 'player_hud',
              upIndex: 0,
              showHighlight: false,
              child: Container(
                color: AppTheme.bgElevated,
                child: SafeArea(
                  top: true,
                  bottom: true,
                  left: false,
                  right: false,
                  child: _buildSideTabs(
                    context,
                    columns: 3,
                    split: true,
                    rightInset: cutout.right,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: playerWidget,
        ),
        Container(height: 8, color: AppTheme.bgElevated),
        Expanded(
          // 同上：侧栏按 ↑ 显式跳到播放器 HUD（返回 / 投屏 / 画中画 / 全屏）。
          child: TvFocusItem(
            zone: 'player_side',
            index: 0,
            upZone: 'player_hud',
            upIndex: 0,
            showHighlight: false,
            child: _buildSideTabs(
              context,
              columns: Breakpoint.gridColsOf(MediaQuery.sizeOf(context).width),
              split: false,
            ),
          ),
        ),
      ],
    );
  }
}
