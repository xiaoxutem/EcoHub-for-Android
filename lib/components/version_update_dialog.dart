import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/app_theme.dart';
import '../utils/app_version_util.dart';
import 'app_markdown_view.dart';
import 'focus_wrap.dart';

/// 版本更新弹窗组件
class VersionUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onClose;

  const VersionUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onClose,
  });

  @override
  State<VersionUpdateDialog> createState() => _VersionUpdateDialogState();
}

class _VersionUpdateDialogState extends State<VersionUpdateDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animController.reverse().then((_) {
      widget.onClose();
    });
  }

  Future<void> _handleUpdate() async {
    final url = widget.updateInfo.releaseUrl.isNotEmpty
        ? widget.updateInfo.releaseUrl
        : AppVersionUtil.latestReleaseUrl;
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
    _handleClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
          // 0.72 黑色遮罩
          Positioned.fill(
            child: FocusTap(
              onTap: _handleClose,
              child: AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) => Container(
                  color: Colors.black.withValues(alpha: 0.72 * _opacityAnimation.value),
                ),
              ),
            ),
          ),

          // 居中弹窗卡片（受 SafeArea 保护，避让状态栏、灵动岛与屏幕打孔）
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Builder(
                      builder: (context) {
                        final media = MediaQuery.of(context);
                        final landscape = media.size.height > 0 && media.size.height < 500;
                        final safeHeight = media.size.height - media.padding.top - media.padding.bottom;
                        final verticalMargin = landscape ? 20.0 : 36.0;
                        final maxHeight = (safeHeight - verticalMargin).clamp(160.0, 680.0);

                        return Container(
                          width: media.size.width * 0.86,
                          constraints: BoxConstraints(maxWidth: 380, maxHeight: maxHeight),
                          padding: EdgeInsets.all(landscape ? AppTheme.spaceMd : AppTheme.spaceLg),
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.accentSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.update_rounded,
                                size: 16,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            const Expanded(
                              child: Text(
                                '发现新版本',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                              onPressed: _handleClose,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                        SizedBox(height: landscape ? 6 : AppTheme.spaceMd),

                        // Version comparison
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '当前 v${widget.updateInfo.currentVersion}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.textMuted),
                            ),
                            Text(
                              '最新 v${widget.updateInfo.latestVersion}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                        // 分割线
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.border.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: landscape ? 4 : 8),

                        // Release notes (无嵌套底色，紧凑自适应，超出时滚动)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.updateInfo.releaseName.isNotEmpty &&
                                    widget.updateInfo.releaseName != 'v${widget.updateInfo.latestVersion}')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      widget.updateInfo.releaseName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                AppMarkdownView(
                                  data: widget.updateInfo.releaseNotes.isNotEmpty
                                      ? widget.updateInfo.releaseNotes.trim()
                                      : '包含稳定性优化与功能增强。',
                                  fontSize: 13,
                                  textColor: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: landscape ? 4 : 8),

                        // 底部分割线
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.border.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: landscape ? AppTheme.spaceSm : AppTheme.spaceMd),

                        // Actions
                        if (landscape)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: TextButton(
                                    onPressed: _handleClose,
                                    child: const Text(
                                      '稍后再说',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _handleUpdate,
                                    child: const Text(
                                      '前往更新',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _handleUpdate,
                                  child: const Text(
                                    '前往更新',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 36,
                                child: TextButton(
                                  onPressed: _handleClose,
                                  child: const Text(
                                    '稍后再说',
                                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
    ],
  ),
),
);
  }
}
