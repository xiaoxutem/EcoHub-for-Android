import 'package:flutter/material.dart';
import '../common/app_theme.dart';

/// 统一空状态/错误状态占位，对齐 OHOS `EmptyState`
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.icon = Icons.movie_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
