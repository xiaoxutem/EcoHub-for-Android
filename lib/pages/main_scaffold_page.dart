import 'dart:async';
import 'package:flutter/material.dart';
import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../api/film_api.dart';
import '../utils/server_config_manager.dart';
import '../utils/site_heartbeat.dart';
import '../utils/source_guard.dart';
import '../utils/app_version_util.dart';
import '../utils/tv_mode.dart';
import '../api/http_client.dart';
import '../components/notice_dialog.dart';
import '../components/version_update_dialog.dart';
import '../components/loading_view.dart';
import '../components/tv_side_nav.dart';
import 'recommend_tab.dart';
import 'daily_updates_tab.dart';
import 'profile_tab.dart';

/// 主框架脚手架页面
class MainScaffoldPage extends StatefulWidget {
  const MainScaffoldPage({super.key});

  static void resetNoticeSession() {
    _MainScaffoldPageState.resetNoticeSession();
  }

  @override
  State<MainScaffoldPage> createState() => _MainScaffoldPageState();
}

class _MainScaffoldPageState extends State<MainScaffoldPage> with WidgetsBindingObserver {
  /// 会话内最近一次关闭的公告指纹（换源清空；公告变动后再弹）
  static String _dismissedNoticeKey = '';

  static void resetNoticeSession() {
    _dismissedNoticeKey = '';
  }

  int _currentTabIndex = 0;
  String _siteName = 'EcoHub';
  bool _siteOpen = true;
  String _siteHint = '';
  bool _ready = false;
  bool _showNotice = false;
  String _noticeTitle = '站点公告';
  String _noticeContent = '';
  String _currentNoticeKey = '';
  bool _hasAppUpdate = false;
  bool _showUpdateDialog = false;
  final List<bool> _tabReady = [true, false, false];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FilmApi.onConfigChange(_onConfigChange);
    SourceGuard.onReconnect(_onReconnect);
    AppVersionUtil.hasUpdate.addListener(_onHasUpdate);
    AppVersionUtil.showUpdateDialog.addListener(_onShowUpdateDialog);
    _hasAppUpdate = AppVersionUtil.hasUpdate.value;
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SiteHeartbeat.instance.stop();
    FilmApi.offConfigChange(_onConfigChange);
    SourceGuard.offReconnect(_onReconnect);
    AppVersionUtil.hasUpdate.removeListener(_onHasUpdate);
    AppVersionUtil.showUpdateDialog.removeListener(_onShowUpdateDialog);
    super.dispose();
  }

  void _onHasUpdate() {
    if (!mounted) return;
    setState(() {
      _hasAppUpdate = AppVersionUtil.hasUpdate.value;
    });
  }

  void _onShowUpdateDialog() {
    if (!mounted) return;
    setState(() {
      _showUpdateDialog = AppVersionUtil.showUpdateDialog.value;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ServerConfigManager.instance.getCachedServerUrl().isNotEmpty) {
        SiteHeartbeat.instance.start();
      }
      if (_ready) {
        _loadSite(false);
      }
    } else if (state == AppLifecycleState.paused) {
      SiteHeartbeat.instance.stop();
    }
  }

  void _onReconnect() {
    _loadSite(false);
  }

  void _onConfigChange(BasicConfig config) {
    if (!mounted) return;
    setState(() {
      _siteName = config.siteName.isNotEmpty ? config.siteName : 'EcoHub';
      _siteOpen = config.state;
      _siteHint = config.hint;
    });
    _checkNotice(config);
  }

  Future<void> _checkNotice(BasicConfig config) async {
    if (!config.state || !config.noticeEnabled || !config.noticeShowInApp || config.noticeContent.trim().isEmpty) {
      if (mounted) setState(() => _showNotice = false);
      return;
    }
    final targetVersion = config.noticeAppVersion.isNotEmpty ? config.noticeAppVersion : config.noticeVersion;
    final appVersion = await AppVersionUtil.getVersionName();
    final isMatched = AppVersionUtil.isVersionMatched(appVersion, targetVersion);

    final serverUrl = ServerConfigManager.instance.getCachedServerUrl();
    final content = config.noticeContent.trim();
    final summary = content.length > 32 ? content.substring(0, 32) : content;
    final noticeKey = '$serverUrl::${config.noticeTitle.trim()}::${content.length}_$summary';

    if (isMatched && _dismissedNoticeKey != noticeKey) {
      if (!mounted) return;
      setState(() {
        _noticeTitle = config.noticeTitle.isNotEmpty ? config.noticeTitle : '站点公告';
        _noticeContent = config.noticeContent;
        _currentNoticeKey = noticeKey;
        _showNotice = true;
      });
    } else if (!isMatched || _dismissedNoticeKey == noticeKey) {
      if (!mounted) return;
      setState(() {
        _showNotice = false;
      });
    }
  }

  Future<void> _bootstrap() async {
    AppVersionUtil.checkUpdate(force: false).then((info) {
      if (mounted) {
        setState(() {
          _hasAppUpdate = info.hasUpdate;
        });
      }
    }).catchError((_) {});

    final url = await ServerConfigManager.instance.getServerUrl();
    if (url.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/server_config');
      }
      return;
    }

    // 对齐 OHOS Index.aboutToAppear: 走 loadSite(false) 直接复用开屏自检探测缓存，避免二次 loading
    await _loadSite(false);
    HttpClient.instance.trackView('browse', '', 'IndexPage');
    SiteHeartbeat.instance.start();
  }

  Future<void> _loadSite(bool first) async {
    if (first) {
      setState(() {
        _ready = false;
      });
    }
    try {
      final config = await FilmApi.getSiteConfig(force: first);
      if (!mounted) return;
      setState(() {
        _siteName = config.siteName.isNotEmpty ? config.siteName : 'EcoHub';
        _siteOpen = config.state;
        _siteHint = config.hint;
        _ready = true;
      });
      _checkNotice(config);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _siteOpen = true;
        _ready = true;
      });
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentTabIndex = index;
      _tabReady[index] = true;
    });
  }

  /// 包裹非当前 tab 的内容。
  ///
  /// [IndexedStack] 会把所有 tab 都保持挂载，未选中的 tab 里的可聚焦控件
  /// 仍在焦点树中 —— 遥控器方向键会遍历到看不见的元素，切 tab 后焦点也可能
  /// 停留在已隐藏的控件上。TV 模式下用 [ExcludeFocus] 把非当前 tab 移出焦点链。
  Widget _tabGuard(int index, Widget child) {
    if (index == _currentTabIndex) return child;
    // 非当前 tab：移出焦点链（遥控器不该遍历到看不见的元素），
    // 并停止其动画与定时器（TickerMode.enabled = false）——
    // 隐藏的 tab 继续跑轮播定时器是卡顿的主要来源之一。
    return TickerMode(
      enabled: false,
      child: ExcludeFocus(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showNoticeOverlay = _showNotice && _ready && _siteOpen;
    final showUpdateOverlay = _showUpdateDialog && AppVersionUtil.getCachedUpdateInfo() != null;
    // 返回键统一由下方的 PopScope 回调处理（见该处注释）。

    // TV 端使用左侧竖排导航（Android TV 标准布局）；其余平台沿用底部导航
    final isTv = TvMode.isTvActive;

    final contentBody = !_ready
        ? const LoadingView(label: '正在接入服务')
        : !_siteOpen
            ? _buildMaintenanceView()
            : IndexedStack(
                index: _currentTabIndex,
                children: [
                  if (_tabReady[0])
                    _tabGuard(0, RecommendTab(
                      siteName: _siteName,
                      onOpenSearch: () => Navigator.pushNamed(context, '/search'),
                    ))
                  else
                    const SizedBox.shrink(),
                  if (_tabReady[1])
                    _tabGuard(1, const DailyUpdatesTab())
                  else
                    const SizedBox.shrink(),
                  if (_tabReady[2])
                    _tabGuard(2, const ProfileTab())
                  else
                    const SizedBox.shrink(),
                ],
              );

    final scaffold = Scaffold(
      backgroundColor: AppTheme.bg,
      body: isTv && _ready && _siteOpen
          ? Row(
              children: [
                TvSideNav(
                  currentIndex: _currentTabIndex,
                  onSelect: _selectTab,
                  hasAppUpdate: _hasAppUpdate,
                ),
                Expanded(child: contentBody),
              ],
            )
          : contentBody,
      bottomNavigationBar: !isTv && _ready && _siteOpen
          ? Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgElevated,
                border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentTabIndex,
                onTap: _selectTab,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded),
                    label: '推荐',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.local_fire_department_outlined),
                    activeIcon: Icon(Icons.local_fire_department_rounded),
                    label: '更新',
                  ),
                  BottomNavigationBarItem(
                    icon: Stack(
                      children: [
                        const Icon(Icons.person_outline_rounded),
                        if (_hasAppUpdate)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    activeIcon: const Icon(Icons.person_rounded),
                    label: '我的',
                  ),
                ],
              ),
            )
          : null,
    );

    return PopScope(
      // 始终拦截返回键，由回调自己决定行为。
      //
      // 为什么不在 build 里用 `Navigator.canPop()` 判断根路由：
      // 那个时机 Navigator 尚未完成当前路由注册，判断不可靠 ——
      // 实测会导致第一次按 BACK 直接退出 App。
      //
      // 行为：
      // - 有弹窗 → 关弹窗
      // - 路由栈里还有上层页面 → 正常 pop
      // - 已在根页面 → 「再按一次退出」（电视上 BACK 极易误触）
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (showNoticeOverlay) {
          if (_currentNoticeKey.isNotEmpty) {
            _dismissedNoticeKey = _currentNoticeKey;
          }
          setState(() {
            _showNotice = false;
          });
        } else if (showUpdateOverlay) {
          AppVersionUtil.showUpdateDialog.value = false;
          setState(() {
            _showUpdateDialog = false;
          });
        }
      },
      child: Stack(
        children: [
          scaffold,

          // Notice modal (全屏遮罩，完整覆盖包括 TabBar 在内的整个视口)
          if (showNoticeOverlay)
            NoticeDialog(
              title: _noticeTitle,
              content: _noticeContent,
              onClose: () {
                if (_currentNoticeKey.isNotEmpty) {
                  _dismissedNoticeKey = _currentNoticeKey;
                }
                setState(() {
                  _showNotice = false;
                });
              },
            ),

          // Version update modal
          if (showUpdateOverlay)
            VersionUpdateDialog(
              updateInfo: AppVersionUtil.getCachedUpdateInfo()!,
              onClose: () {
                AppVersionUtil.showUpdateDialog.value = false;
                setState(() {
                  _showUpdateDialog = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(38),
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              _siteName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: const Text(
                '站点维护中',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Text(
                _siteHint.isNotEmpty
                    ? _siteHint
                    : '当前站点正在进行系统维护，暂无法提供观影服务，请稍后刷新重试或更换其他软件源。',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bgCard,
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      onPressed: () => _loadSite(true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('刷新重试'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/server_config'),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('更换软件源'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
