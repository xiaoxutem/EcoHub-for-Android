import 'package:flutter/material.dart';
import '../common/app_theme.dart';

/// 统一图标组件
class AppIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const AppIcon({
    super.key,
    required this.icon,
    this.size = 20,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}

/// 启动 Logo，对齐 OHOS `$r('app.media.startIcon')`
class StartIconImage extends StatelessWidget {
  static const assetPath = 'assets/images/start_icon.png';

  final double size;
  final double radius;

  const StartIconImage({
    super.key,
    this.size = 56,
    this.radius = AppTheme.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
