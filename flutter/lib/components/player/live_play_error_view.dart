import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import '../../utils/nav_util.dart';

/// 现场播放源失效/异常容错视图，支持全网重搜与移出收藏
class LivePlayErrorView extends StatelessWidget {
  final String filmName;
  final String errorText;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback onRemoveFavorite;

  const LivePlayErrorView({
    super.key,
    required this.filmName,
    required this.errorText,
    required this.isFavorite,
    required this.onBack,
    required this.onRetry,
    required this.onRemoveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final searchKeyword = filmName.trim();
    final searchButtonText = searchKeyword.isNotEmpty
        ? '全网搜索「$searchKeyword」'
        : '全网重新搜索';

    return Column(
      children: [
        // 顶部返回导航栏
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
                tooltip: '返回',
              ),
              const SizedBox(width: 4),
              const Text(
                '现场播放',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // 中间错误说明与操作面板
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.tv_off_rounded,
                        size: 36,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    const Text(
                      '采集源已失效或下线',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      errorText.isNotEmpty
                          ? '错误原因：$errorText\n该采集源可能已被管理员下线或源站响应超时，建议全网重搜其他片源。'
                          : '该采集源可能已被管理员下线或源站响应超时，建议全网重搜其他片源。',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceXl),
                    // 操作按钮群
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => NavUtil.openSearch(context, searchKeyword),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(
                          searchButtonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (isFavorite) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onRemoveFavorite,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                          label: const Text('移出收藏', style: TextStyle(color: AppTheme.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.dangerSoft),
                            backgroundColor: AppTheme.dangerSoft,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceMd),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
                      label: const Text('重新尝试', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
