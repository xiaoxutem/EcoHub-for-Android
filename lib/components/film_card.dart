import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../utils/format_util.dart';
import '../utils/nav_util.dart';
import '../utils/server_config_manager.dart';
import '../utils/favorite_manager.dart';
import 'focus_wrap.dart';

/// 影片海报卡片组件
class FilmCard extends StatelessWidget {
  final MovieBasicInfo film;
  final double? cardWidth;
  final bool showMeta;
  final void Function(MovieBasicInfo film)? onClickCard;

  const FilmCard({
    super.key,
    required this.film,
    this.cardWidth,
    this.showMeta = true,
    this.onClickCard,
  });

  String _resolvedPosterUrl() {
    final raw = FormatUtil.poster(film);
    return ServerConfigManager.instance.resolveMediaUrl(raw);
  }

  void _handleClick(BuildContext context) {
    if (onClickCard != null) {
      onClickCard!(film);
      return;
    }
    NavUtil.openPlay(
      context,
      FormatUtil.filmId(film),
      sourceId: film.sourceId,
      sourceMid: film.sourceMid > 0 ? '${film.sourceMid}' : '',
      title: film.name,
    );
  }

  Widget _buildPosterTag(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xC70A0B10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFavoriteTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE60A0B10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x66FA8C16), width: 0.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 11,
            color: Color(0xFFFA8C16),
          ),
          SizedBox(width: 2),
          Text(
            '已收藏',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFFFA8C16),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvedPosterUrl();

    // TV：InkWell 自身可聚焦，但需要明显的焦点高亮框，遥控器下才看得出选中项
    final card = InkWell(
      onTap: () => _handleClick(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.hasBoundedHeight && constraints.maxHeight > 50;

          Widget poster = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (posterUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: posterUrl,
                      httpHeaders: FormatUtil.imageHeaders(posterUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: AppTheme.bgCard,
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.65, 1.0],
                        colors: [
                          Color(0x00000000),
                          Color(0x990A0B10),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ValueListenableBuilder<int>(
                      valueListenable: FavoriteManager.favoriteVersion,
                      builder: (context, _, child) {
                        final isFav = FavoriteManager.isFavoriteSync(FormatUtil.filmId(film));
                        if (!isFav) return const SizedBox.shrink();
                        return _buildFavoriteTag();
                      },
                    ),
                  ),
                  if (film.remarks.isNotEmpty || film.cName.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _buildPosterTag(
                        film.remarks.isNotEmpty ? film.remarks : film.cName,
                      ),
                    ),
                ],
              ),
            ),
          );

          if (hasBoundedHeight) {
            poster = Expanded(child: poster);
          } else {
            poster = AspectRatio(
              aspectRatio: 2 / 3,
              child: poster,
            );
          }

          final card = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              poster,
              if (showMeta) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: Text(
                    film.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      height: 1.38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 15,
                  child: Text(
                    film.subTitle.isNotEmpty
                        ? film.subTitle
                        : FormatUtil.joinMeta([film.year, film.cName]),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      height: 1.36,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          );

          return cardWidth != null ? SizedBox(width: cardWidth, child: card) : card;
        },
      ),
    );

    return FocusHighlight(
      radius: BorderRadius.circular(AppTheme.radiusMd),
      child: card,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.bgCard,
      child: Center(
        child: Text(
          film.name.isNotEmpty ? film.name.substring(0, 1) : '影',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
