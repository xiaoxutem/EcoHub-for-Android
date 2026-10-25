import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../utils/breakpoint.dart';
import 'film_card.dart';

/// 影片网格列表组件
class FilmGrid extends StatelessWidget {
  final List<MovieBasicInfo> films;
  final int columns;
  final double? childAspectRatio;
  final void Function(MovieBasicInfo film)? onClickFilm;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  const FilmGrid({
    super.key,
    required this.films,
    this.columns = 3,
    this.childAspectRatio,
    this.onClickFilm,
    this.physics,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final hPadding = padding is EdgeInsets ? (padding as EdgeInsets).horizontal : 24.0;
        final resolvedRatio = childAspectRatio ??
            Breakpoint.gridAspectRatio(
              width: totalWidth,
              columns: columns,
              horizontalPadding: hPadding,
              crossAxisSpacing: AppTheme.spaceSm,
            );

        return GridView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: resolvedRatio,
            crossAxisSpacing: AppTheme.spaceSm,
            mainAxisSpacing: AppTheme.spaceMd,
          ),
          itemCount: films.length,
          itemBuilder: (context, index) {
            return FilmCard(
              film: films[index],
              onClickCard: onClickFilm,
            );
          },
        );
      },
    );
  }
}
