/// 窗口断点，对齐 OHOS `common/utils/Breakpoint.ets`
class Breakpoint {
  static const double md = 600;
  static const double lg = 840;
  static const double xl = 1440;

  static String ofWidth(double vp) {
    if (vp >= xl) return 'xl';
    if (vp >= lg) return 'lg';
    if (vp >= md) return 'md';
    return 'sm';
  }

  static bool isWide(String bp) => bp == 'md' || bp == 'lg' || bp == 'xl';

  static bool isWideWidth(double width) => isWide(ofWidth(width));

  static int gridColsOf(double width) {
    final bp = ofWidth(width);
    if (width >= xl || bp == 'xl') return 8;
    if (width >= 1100) return 7;
    if (width >= lg || bp == 'lg') return 6;
    if (width >= md || bp == 'md') return 4;
    return 3;
  }

  static int listLanesOf(double width) {
    final bp = ofWidth(width);
    if (bp == 'xl') return 3;
    if (bp == 'lg' || bp == 'md') return 2;
    return 1;
  }

  /// 横向 FilmRow 卡片宽，对齐 OHOS `Breakpoint.cardWidth` 与 DailyUpdatePane 栅格卡片宽
  static double cardWidthOf(
    double width, {
    double? windowWidth,
    double horizontalPadding = 32.0,
    int? columns,
    double gap = 8.0,
  }) {
    final w = windowWidth ?? width;
    final cols = columns ?? gridColsOf(w);
    final available = w - horizontalPadding;
    if (available <= 0 || cols <= 0) return 104.0;
    final cardW = (available - (cols - 1) * gap) / cols;
    return cardW < 104 ? 104.0 : cardW;
  }

  /// FilmCard 宽高比：海报 2:3 (高=宽*1.5) + 标题/副标题高度与边距 41
  static double filmCardAspectRatio(double cardWidth) {
    if (cardWidth <= 0) return 0.52;
    return cardWidth / (cardWidth * 1.5 + 41.0);
  }

  /// 网格海报宽高比计算，避免在窄屏或分屏时因固定 0.54 导致文字下溢 (RenderFlex overflow)
  static double gridAspectRatio({
    required double width,
    required int columns,
    double horizontalPadding = 24.0,
    double crossAxisSpacing = 8.0,
  }) {
    final available = width - horizontalPadding;
    if (available <= 0 || columns <= 0) return 0.52;
    final cardW = (available - (columns - 1) * crossAxisSpacing) / columns;
    return filmCardAspectRatio(cardW);
  }

  static double bannerHeight({
    required double width,
    required double height,
    required bool multi,
  }) {
    if (isWideWidth(width)) {
      if (height > 0 && height < 500) {
        return multi ? 240 : 255;
      }
      return multi ? 340 : 360;
    }
    return multi ? 420 : 440;
  }

  static double bannerPeek(double width) {
    if (width >= xl) return 140;
    if (width >= 1100) return 104;
    if (width >= 780 || ofWidth(width) == 'lg' || ofWidth(width) == 'xl') {
      return 84;
    }
    if (isWideWidth(width) || width >= md) return 68;
    return 20;
  }

  static double bannerItemSpace(double width) => isWideWidth(width) ? 14 : 10;
}
