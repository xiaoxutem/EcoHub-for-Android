import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../api/film_api.dart';
import '../utils/server_config_manager.dart';
import '../utils/source_guard.dart';
import '../utils/app_version_util.dart';
import '../utils/nav_util.dart';
import '../components/profile_site_card.dart';
import '../components/focus_wrap.dart';

/// 我的 Tab，对齐 OHOS `ProfileTab.ets`
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  BasicConfig _config = BasicConfig();
  String _sourceUrl = '';
  AppUpdateInfo _updateInfo = AppUpdateInfo(
    currentVersion: '',
    latestVersion: '',
    hasUpdate: false,
    releaseName: '',
    releaseNotes: '',
    releaseUrl: '',
    downloadUrl: '',
  );

  @override
  void initState() {
    super.initState();
    SourceGuard.onReconnect(_onReconnect);
    AppVersionUtil.hasUpdate.addListener(_onHasUpdate);
    final cached = AppVersionUtil.getCachedUpdateInfo();
    if (cached != null) {
      _updateInfo = cached;
    }
    _initData();
  }

  @override
  void dispose() {
    SourceGuard.offReconnect(_onReconnect);
    AppVersionUtil.hasUpdate.removeListener(_onHasUpdate);
    super.dispose();
  }

  void _onHasUpdate() {
    final info = AppVersionUtil.getCachedUpdateInfo();
    if (!mounted || info == null) return;
    setState(() {
      _updateInfo = info;
    });
  }

  void _onReconnect() {
    _reload();
  }

  Future<void> _initData() async {
    _checkUpdateSilent();
    await _reload();
  }

  Future<void> _checkUpdateSilent() async {
    try {
      final info = await AppVersionUtil.checkUpdate(force: false);
      if (mounted) {
        setState(() {
          _updateInfo = info;
        });
      }
    } catch (_) {}
  }

  Future<void> _reload() async {
    final url = await ServerConfigManager.instance.getServerUrl();
    try {
      final config = await FilmApi.getSiteConfig(force: false);
      if (mounted) {
        setState(() {
          _sourceUrl = url;
          _config = config;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sourceUrl = url;
        });
      }
    }
  }

  String _sourceHost() {
    if (_sourceUrl.isEmpty) return '未配置';
    var host = ServerConfigManager.stripApiSuffix(
      ServerConfigManager.instance.normalizeRaw(_sourceUrl),
    );
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    return host.isNotEmpty ? host : '未配置';
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    String extra = '',
    bool hasBadge = false,
    String badgeText = '',
    bool extraHighlight = false,
    required VoidCallback onTap,
  }) {
    // TV：InkWell 自身可聚焦但默认高亮很弱，用 FocusHighlight 补明显的焦点框，
    // 否则用户在「我的」页看不到当前选中了哪一项。
    return FocusHighlight(
      radius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 18, color: AppTheme.accent),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                  ),
                  if (hasBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        badgeText.isNotEmpty ? badgeText : 'NEW',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (extra.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  extra,
                  style: TextStyle(
                    fontSize: 13,
                    color: extraHighlight ? AppTheme.accent : AppTheme.textMuted,
                    fontWeight: extraHighlight ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.textMuted),
          ],
        ),
        ),
      ),
    );
  }

  Widget _menuLine() {
    return const Padding(
      padding: EdgeInsets.only(left: 64),
      child: Divider(color: AppTheme.border, height: 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bg,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                0,
                AppTheme.spaceLg,
                AppTheme.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                      top: AppTheme.spaceSm,
                      bottom: AppTheme.spaceLg,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: AppTheme.accent, size: 20),
                        SizedBox(width: AppTheme.spaceSm),
                        Text(
                          '我的',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ProfileSiteCard(
                    siteName: _config.siteName,
                    logoUrl: ServerConfigManager.instance.resolveMediaUrl(_config.logo),
                    sourceHost: _sourceHost(),
                    onOpenSource: () {
                      Navigator.pushNamed(context, '/server_config').then((_) => _reload());
                    },
                    onOpenFavorite: () => Navigator.pushNamed(context, '/favorite'),
                    onOpenHistory: () => Navigator.pushNamed(context, '/history'),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: Icons.play_circle_fill_rounded,
                          title: '自定义播放',
                          onTap: () => NavUtil.openCustomPlayer(context),
                        ),
                        if (_config.tipEnabled) ...[
                          _menuLine(),
                          _buildMenuRow(
                            icon: Icons.card_giftcard_rounded,
                            title: _config.tipTitle.isNotEmpty ? _config.tipTitle : '赞赏支持',
                            onTap: () => Navigator.pushNamed(context, '/tip'),
                          ),
                        ],
                        _menuLine(),
                        _buildMenuRow(
                          icon: Icons.settings_rounded,
                          title: '设置',
                          onTap: () => NavUtil.openSettings(context),
                        ),
                        _menuLine(),
                        _buildMenuRow(
                          icon: Icons.info_outline_rounded,
                          title: '关于',
                          extra: _updateInfo.hasUpdate ? '发现新版本 v${_updateInfo.latestVersion}' : '',
                          hasBadge: _updateInfo.hasUpdate,
                          extraHighlight: _updateInfo.hasUpdate,
                          onTap: () => NavUtil.openAbout(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
