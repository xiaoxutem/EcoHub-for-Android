import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common/app_theme.dart';
import 'components/tv_focus_overlay.dart';
import 'utils/app_orientation.dart';
import 'utils/source_guard.dart';
import 'utils/tv_mode.dart';
import 'utils/image_host_guard.dart';
import 'utils/image_proxy_config.dart';
import 'pages/splash_page.dart';
import 'utils/net_probe.dart';
import 'pages/main_scaffold_page.dart';
import 'pages/server_config_page.dart';
import 'pages/filter_page.dart';
import 'pages/search_page.dart';
import 'pages/history_page.dart';
import 'pages/favorite_page.dart';
import 'pages/tip_page.dart';
import 'pages/custom_player_page.dart';
import 'pages/play_page.dart';
import 'pages/live_play_page.dart';
import 'pages/about_page.dart';
import 'pages/settings_page.dart';
import 'services/route_observer.dart';
import 'utils/server_config_manager.dart';
import 'utils/history_manager.dart';
import 'utils/site_heartbeat.dart';
import 'utils/app_settings_manager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 全局默认沉浸式系统 UI 覆盖样式：全透明状态栏与导航条，并彻底关闭 Android 10+ 的对比度强制浅色遮罩
const SystemUiOverlayStyle kDefaultSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 探测设备形态（Android TV / 遥控器模式），需在首帧前完成，
  // 否则布局与焦点策略会先按手机形态渲染一次再跳变。
  await TvMode.probe();

  // 探测图床可用性：不可用的图床会被熔断，后续图片直接走占位图，
  // 避免首页 200+ 张卡片发起注定失败的请求（这是首屏卡顿的主因）。
  ImageHostGuard.instance.init();
  await ImageProxyConfig.instance.init();
  unawaited(runNetworkProbe().then((lines) {
    for (final line in lines) {
      // 形如 "403 len=23682  image.jinyingimage.com"
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      final host = parts.last;
      final ok = parts.first == '200';
      ImageHostGuard.instance.recordProbe(host, ok);
    }
  }));

  // TV 模式强制焦点高亮模式为 traditional。
  // Android 默认是 touch 模式 —— 首次硬件按键前不显示任何焦点高亮，
  // 而 TV 上必须始终能看到当前选中项。Material 自带控件（Slider、IconButton 等）
  // 的焦点高亮也依赖这个模式。
  if (TvMode.isTvActive) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  // 沉浸式透明状态栏与边缘到边缘布局，透明导航条并禁用系统浅色强制对比度遮罩
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(kDefaultSystemUiOverlayStyle);

  // TV 端强制横屏；其余设备沿用自动旋转（竖屏 + 左右横屏，排除倒置）
  SystemChrome.setPreferredOrientations(
    TvMode.isTvActive ? TvMode.orientations : kAutoRotationOrientations,
  );

  SourceGuard.navigatorKey = appNavigatorKey;

  // 对齐 OHOS EntryAbility.onWindowStageCreate 初始化管线
  await Future.wait([
    ServerConfigManager.instance.init(),
    AppSettingsManager.instance.init(),
  ]);
  await HistoryManager.migrateLegacy();

  runApp(const EcoHubApp());
}

/// 全局根组件，对齐 OHOS EntryAbility 前后台事件全局调度 SiteHeartbeat
class EcoHubApp extends StatefulWidget {
  const EcoHubApp({super.key});

  @override
  State<EcoHubApp> createState() => _EcoHubAppState();
}

class _EcoHubAppState extends State<EcoHubApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SiteHeartbeat.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ServerConfigManager.instance.getCachedServerUrl().isNotEmpty) {
        SiteHeartbeat.instance.start();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      SiteHeartbeat.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kDefaultSystemUiOverlayStyle,
      child: MaterialApp(
        title: 'EcoHub',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        navigatorObservers: [EcoHubRouteObserver()],
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          // TV 端整体字号放大：观看距离 2~3 米，手机端的字号在电视上偏小。
          // 仅在系统未做额外放大（scale == 1.0）时叠加 TV 系数，
          // 用户主动调过字号时以系统设置为准，不覆盖无障碍需求。
          final baseScale = mediaQuery.textScaler.scale(1);
          final scaler = baseScale == 1.0 && TvMode.isTvActive
              ? const TextScaler.linear(1.25)
              : mediaQuery.textScaler;
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: scaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: TvMode.isTvActive ? 1.6 : 1.1,
              ),
            ),
            // TV 模式：建立焦点遍历组，让方向键在可聚焦控件之间按序移动；
            // 同时提供全局快捷键（Esc 返回 / 媒体播放键）。
            child: _buildRoot(child ?? const SizedBox.shrink(), mediaQuery),
          );
        },
        initialRoute: '/',
        onGenerateRoute: (settings) {
          final args = settings.arguments as Map<String, dynamic>? ?? {};

          Widget page;
          switch (settings.name) {
            case '/':
              page = const SplashPage();
              break;
            case '/main':
              page = const MainScaffoldPage();
              break;
            case '/server_config':
              page = ServerConfigPage(
                mode: args['mode'] ?? '',
              );
              break;
            case '/filter':
              page = FilterPage(
                pid: args['Pid'] ?? args['pid'] ?? '',
                category: args['Category'] ?? '',
                sort: args['Sort'] ?? '',
              );
              break;
            case '/search':
              page = SearchPage(
                initialKeyword: args['keyword'] ?? '',
              );
              break;
            case '/history':
              page = const HistoryPage();
              break;
            case '/favorite':
              page = const FavoritePage();
              break;
            case '/tip':
              page = const TipPage();
              break;
            case '/custom_player':
              page = CustomPlayerPage(url: args['url'] ?? '');
              break;
            case '/play':
              page = PlayPage(
                id: args['id'] ?? '',
                sourceId: args['sourceId'] ?? '',
                episodeIndex: args['episodeIndex'] != null ? int.tryParse('${args['episodeIndex']}') : null,
                currentTime: args['currentTime'] != null ? double.tryParse('${args['currentTime']}') : null,
              );
              break;
            case '/play/live':
              page = LivePlayPage(
                sourceId: args['sourceId'] ?? '',
                sourceMid: args['sourceMid'] ?? '',
                episodeIndex: args['episodeIndex'] != null ? int.tryParse('${args['episodeIndex']}') : null,
                currentTime: args['currentTime'] != null ? double.tryParse('${args['currentTime']}') : null,
                title: args['title'] ?? '',
              );
              break;
            case '/about':
              page = const AboutPage();
              break;
            case '/settings':
              page = const SettingsPage();
              break;
            default:
              page = const SplashPage();
          }

          return MaterialPageRoute(settings: settings, builder: (_) => page);
        },
      ),
    );
  }

  /// 构建根节点内容：TV 模式下套上焦点遍历组与全局遥控器快捷键。
  Widget _buildRoot(Widget child, MediaQueryData mediaQuery) {
    if (!TvMode.isTvActive) return child;

    return FocusTraversalGroup(
      // 阅读顺序策略：在网格/列表里按行优先的方向键遍历，与视觉排布一致，
      // 避免使用 OrderedTraversalPolicy 时因缺少显式 order 而无法移动焦点。
      policy: ReadingOrderTraversalPolicy(),
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          // 遥控器返回键：Esc 等价于关闭当前层
          const SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
          // 媒体键
          const SingleActivator(LogicalKeyboardKey.mediaPlay): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPause): const ActivateIntent(),
        },
        child: Focus(
          autofocus: true,
          // 全局焦点框层：监听焦点节点并在顶层画橙色描边。
          //
          // 为什么放在最外层：Material 自带控件的默认焦点高亮在电视上
          // 几乎不可见，逐个用 FocusHighlight 包裹永远补不干净
          // （关于页、收藏页、历史页、详情弹窗、错误页、投屏面板…都漏过）。
          // 在应用顶层统一绘制，任何能获得焦点的控件都会自动带上高亮框。
          child: TvFocusOverlay(child: child),
        ),
      ),
    );
  }
}
