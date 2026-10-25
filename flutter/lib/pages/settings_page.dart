import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../components/page_header.dart';
import '../utils/app_settings_manager.dart';
import '../utils/tv_mode.dart';
import '../utils/image_proxy_config.dart';
import '../components/focus_wrap.dart';

/// 设置页面，全量对齐 OHOS `SettingsPage.ets`
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// TV 模式开关的状态（供 ValueListenableBuilder 监听）。
  final ValueNotifier<bool> _tvModeNotifier = ValueNotifier<bool>(false);

  /// 图片代理前缀输入框。
  final TextEditingController _proxyController = TextEditingController();

  @override
  void dispose() {
    _tvModeNotifier.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  Widget _proxyActionButton(String label, Future<void> Function() onTap) {
    return FocusTap(
      onTap: onTap,
      focusRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.accentSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Future<void> _saveProxy(String? _) async {
    final value = _proxyController.text.trim();
    await ImageProxyConfig.instance.setPrefix(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value.isEmpty ? '已关闭图片代理' : '图片代理已保存，刷新页面后生效'),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _clearProxy() async {
    _proxyController.clear();
    await ImageProxyConfig.instance.setPrefix('');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已关闭图片代理'),
        duration: Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _setTvMode(bool value) async {
    await TvMode.setForcedTv(value);
    _tvModeNotifier.value = value;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? '已开启 TV 模式，重启应用后生效' : '已关闭 TV 模式，重启应用后生效'),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  String _cacheSize = '0.0 MB';

  @override
  void initState() {
    super.initState();
    _tvModeNotifier.value = TvMode.forceTv;
    _proxyController.text = ImageProxyConfig.instance.prefix;
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await AppSettingsManager.instance.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = size;
      });
    }
  }

  void _handleClearCache() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text(
          '清理本地缓存',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          '确定清理本地缓存吗？',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          // TV：弹窗按钮同样需要明显的焦点框，
          // 否则用户在电视上看不清当前选中「取消」还是「清理」。
          FocusHighlight(
            radius: BorderRadius.circular(AppTheme.radiusSm),
            child: TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ),
          FocusHighlight(
            radius: BorderRadius.circular(AppTheme.radiusSm),
            child: TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AppSettingsManager.instance.clearCache();
              await _refreshCacheSize();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('缓存已清理'),
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
            child: const Text(
              '清理',
              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _cardDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 0.5,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    // TV：Switch 自身可聚焦，但 Material 默认高亮在电视上几乎不可见 ——
    // 整行包一层 FocusHighlight，让用户能确认当前选中的是哪个开关。
    return FocusHighlight(
      radius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: AppTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildActionRow({
    required String title,
    required String subtitle,
    required String extra,
    required VoidCallback onTap,
  }) {
    // TV：InkWell 可聚焦但默认高亮几乎不可见，补明显的焦点框，
    // 否则用户在设置页看不到当前选中了哪一项。
    return FocusHighlight(
      radius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              extra,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppTheme.textMuted,
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: '设置'),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 播放设置分类
                        _sectionTitle('播放'),
                        ValueListenableBuilder<bool>(
                          valueListenable: AppSettingsManager.instance.pipAutoStartNotifier,
                          builder: (context, pipAutoStart, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: AppSettingsManager.instance.autoPlayNextNotifier,
                              builder: (context, autoPlayNext, _) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgElevated,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      width: 0.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      _buildSwitchRow(
                                        title: '回到桌面开启画中画',
                                        subtitle: '返回桌面时自动开启小窗悬浮',
                                        value: pipAutoStart,
                                        onChanged: (v) => AppSettingsManager.instance.setPipAutoStart(v),
                                      ),
                                      _cardDivider(),
                                      _buildSwitchRow(
                                        title: '自动连播下一集',
                                        subtitle: '当前视频播完后自动播放下一集',
                                        value: autoPlayNext,
                                        onChanged: (v) => AppSettingsManager.instance.setAutoPlayNext(v),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // 1.5 TV 模式（遥控器适配）—— 便于在非 TV 设备上预览
                        _sectionTitle('TV 模式'),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _tvModeNotifier,
                            builder: (context, forced, _) {
                              return _buildSwitchRow(
                                title: '强制启用 TV 模式',
                                subtitle: '在非电视设备上套用遥控器导航布局与焦点框（需重启应用生效）',
                                value: forced,
                                onChanged: (v) => _setTvMode(v),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 1.6 图片代理 —— 部分图床对特定网络返回 403，
                        // 配置一个能访问该图床的代理前缀即可显示原始封面。
                        _sectionTitle('图片代理'),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '代理前缀',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '部分图床对当前网络返回 403（防盗链限制），'
                                  '配置代理前缀后由代理服务器取图。留空则使用原地址。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _proxyController,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'https://your-proxy/api/img?url=',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.bg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (v) => _saveProxy(v),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _proxyActionButton('保存', () => _saveProxy(null)),
                                    const SizedBox(width: 8),
                                    _proxyActionButton('清除', () => _clearProxy()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. 通用设置分类
                        _sectionTitle('通用'),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildActionRow(
                            title: '清理本地缓存',
                            subtitle: '清理图片与临时网络数据',
                            extra: _cacheSize,
                            onTap: _handleClearCache,
                          ),
                        ),
                      ],
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
