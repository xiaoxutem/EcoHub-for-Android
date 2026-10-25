import 'package:flutter/material.dart';
import '../common/app_theme.dart';

/// 子页面通用顶部导航栏
class PageHeader extends StatelessWidget {
  final String title;
  final String rightText;
  final Color rightTextColor;
  final VoidCallback? onRight;
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.rightText = '',
    this.rightTextColor = AppTheme.accent,
    this.onRight,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
      color: AppTheme.bg,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
            onPressed: onBack ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (rightText.isNotEmpty)
            TextButton(
              onPressed: onRight,
              child: Text(
                rightText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: rightTextColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
