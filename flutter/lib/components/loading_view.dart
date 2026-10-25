import 'package:flutter/material.dart';
import '../common/app_theme.dart';

/// 统一加载中提示组件
class LoadingView extends StatelessWidget {
  final String label;

  const LoadingView({
    super.key,
    this.label = '加载中...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.accent,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
