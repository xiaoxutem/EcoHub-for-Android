import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// EcoHub 全局主题与设计规范
class AppTheme {
  // 色彩规范 (深色设计系统)
  static const Color bg = Color(0xFF0A0B10);
  static const Color bgElevated = Color(0xFF12141C);
  static const Color bgCard = Color(0xFF1A1C24);
  static const Color bgChip = Color(0xFF22242E);
  static const Color accent = Color(0xFFFA8C16);
  static const Color accentSoft = Color(0x2EFA8C16); // rgba(250, 140, 22, 0.18)
  static const Color danger = Color(0xFFFF4D4F);
  static const Color dangerSoft = Color(0x2EFF4D4F); // rgba(255, 77, 79, 0.18)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xA6FFFFFF); // rgba(255, 255, 255, 0.65)
  static const Color textMuted = Color(0x66FFFFFF); // rgba(255, 255, 255, 0.40)
  static const Color border = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color borderSolid = Color(0xFF262832); // 实色不透明边框，彻底阻断滚动漏光
  static const Color overlay = Color(0x8C0A0B10); // rgba(10, 11, 16, 0.55)

  // 间距规范
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;

  // 圆角规范
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusPill = 24.0;

  // 尺寸常量
  static const double tabHeight = 56.0;
  static const double safeEdge = 16.0;
  static const double posterRatio = 1.5;
  static const double contentMaxWidth = 1280.0;
  static const String calligraphyFont = 'CalligraphyFont';

  /// 全局 ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      canvasColor: bgElevated,
      cardColor: bgCard,
      dividerColor: border,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: bgElevated,
        error: danger,
      ),
      // ★ 电视上 Material 控件的焦点高亮（InkWell / IconButton / TextButton /
      // Switch / Checkbox …）默认是几乎看不见的半透明灰 ——
      // 统一改成橙色，遥控器选中什么一眼就看得见。
      //
      // 这比「给每个控件套 FocusHighlight」更彻底：
      // Theme 一改，所有 Material 控件的焦点态立刻生效，零遗漏。
      focusColor: accent.withValues(alpha: 0.30),
      hoverColor: accent.withValues(alpha: 0.18),
      splashColor: accent.withValues(alpha: 0.22),
      highlightColor: accent.withValues(alpha: 0.30),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgElevated,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }
}
