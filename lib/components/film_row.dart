import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../utils/tv_focus_bridge.dart';
import 'tv_focus_item.dart';
import '../models/film_models.dart';
import '../utils/breakpoint.dart';
import 'film_card.dart';
import 'focus_wrap.dart';

/// 首页分类横向影片展示行
class FilmRow extends StatelessWidget {
  final String title;
  final List<MovieBasicInfo> films;
  final String moreText;
  final int pid;
  final VoidCallback? onMore;
  final double? leftInset;
  final double? rightInset;

  /// 焦点协调器：用于把 ↑/↓ 的跨区域跳转变成确定行为。
  final TvFocusBridge? focusBridge;

  /// 本行在协调器中的区域名。
  final String? focusZone;

  /// 本行在区域内的下标。
  final int focusIndex;

  /// 按 ↑ 时跳回的区域（通常是分类标题行）。
  final String? focusUpZone;

  /// 按 ↑ 时跳回区域内的下标。
  final int focusUpIndex;

  const FilmRow({
    super.key,
    required this.title,
    required this.films,
    this.moreText = '查看全部',
    this.pid = 0,
    this.onMore,
    this.leftInset,
    this.rightInset,
    this.focusBridge,
    this.focusZone,
    this.focusIndex = 0,
    this.focusUpZone,
    this.focusUpIndex = 0,
  });

  void _openMore(BuildContext context) {
    if (onMore != null) {
      onMore!();
    } else if (pid > 0) {
      Navigator.pushNamed(context, '/filter', arguments: {'Pid': '$pid'});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) {
      return const SizedBox.shrink();
    }
    final padding = MediaQuery.paddingOf(context);
    final left = leftInset ?? padding.left;
    final right = rightInset ?? padding.right;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (AppTheme.spaceLg * 2) + left + right;
    final cardW = Breakpoint.cardWidthOf(
      windowWidth,
      horizontalPadding: horizontalPadding,
    );
    // 海报 2:3 + 标题上距 6 / 高 18 + 副标上距 2 / 高 15
    final rowHeight = cardW * 1.5 + 41;

    // FocusTraversalGroup：每一行电影划为一个独立的遍历组。
    //
    // 这样 ↓/↑ 键在「分类标题行」与各电影行之间按**组顺序**移动，
    // 不会被几何位置相近的元素反复拉扯（表现为焦点框在标题与卡片间乱跳）。
    return FocusTraversalGroup(
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
          bottom: BorderSide(color: Color(0x0DFFFFFF), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spaceLg + left,
              0,
              AppTheme.spaceLg + right,
              AppTheme.spaceMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FocusTap(
                    onTap: () => _openMore(context),
                    focusRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 15,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FocusTap(
                  onTap: () => _openMore(context),
                  focusRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppTheme.spaceSm),
                    child: SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            moreText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  left: AppTheme.spaceLg + left,
                  right: AppTheme.spaceLg + right,
                ),
                itemCount: films.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppTheme.spaceSm),
                itemBuilder: (context, index) {
                  final card = FilmCard(
                    film: films[index],
                    cardWidth: cardW,
                  );
                  if (focusBridge == null || focusZone == null) return card;
                  // 每一行电影划为一个独立的遍历组（见上方注释），
                  // 卡片按 ↑ 时显式跳回对应的分类标题项。
                  // 垂直方向的焦点序列（严格有序，绝不乱跳）：
                  //   分类项 i ↓ → 本行第 1 张卡
                  //   本行第 1 张卡 ↑ → 上一行第 1 张卡（第 1 行则回到分类项 i）
                  //   本行任意卡 ↓ → 下一行第 1 张卡
                  final isFirst = index == 0;
                  final prevRowFirst = (focusIndex - 1) * 1000;
                  return TvFocusItem(
                    bridge: focusBridge,
                    zone: focusZone,
                    index: focusIndex * 1000 + index,
                    // ↓ → 下一行的第一张卡
                    downZone: focusZone,
                    downIndex: (focusIndex + 1) * 1000,
                    // ↑ → 上一行的第一张卡；第一行则回到分类标题项
                    upZone: isFirst
                        ? (focusIndex > 0 ? focusZone : focusUpZone)
                        : focusZone,
                    upIndex: isFirst ? prevRowFirst : focusUpIndex,
                    focusRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: card,
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}
