import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/app_theme.dart';
import '../utils/server_config_manager.dart';
import '../utils/tv_mode.dart';
import '../utils/source_guard.dart';
import '../utils/site_heartbeat.dart';
import '../api/http_client.dart';
import '../api/film_api.dart';
import '../components/app_icon.dart';
import '../components/server_history_dialog.dart';
import '../components/focus_wrap.dart';
import '../components/tv_text_field.dart';
import '../components/tv_keyboard_panel.dart';
import 'main_scaffold_page.dart';

/// 软件源配置页，对齐 OHOS `ServerConfigPage`
class ServerConfigPage extends StatefulWidget {
  final String mode;

  const ServerConfigPage({super.key, this.mode = ''});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<String> _serverHistory = [];
  bool _reconnect = false;
  int _lastBackPressMs = 0;

  @override
  void initState() {
    super.initState();
    _reconnect = widget.mode == 'reconnect';
    _loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    SourceGuard.markClosed();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    _controller.text = await ServerConfigManager.instance.getServerUrl();
    _serverHistory = await ServerConfigManager.instance.getServerHistory();
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    final list = await ServerConfigManager.instance.getServerHistory();
    if (mounted) {
      setState(() {
        _serverHistory = list;
      });
    }
  }

  Future<void> _saveAndConnect() async {
    FocusScope.of(context).unfocus();
    final url = _controller.text.trim();
    if (url.isEmpty) {
      _toast('请输入软件源地址');
      return;
    }

    setState(() => _isLoading = true);
    final res = await HttpClient.instance.testConnection(url);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!res.ok) {
      _toast(res.message ?? '无法连接该源，请检查地址');
      return;
    }

    await ServerConfigManager.instance.setServerUrl(url);
    await _loadHistory();
    FilmApi.clearSiteConfig();
    SiteHeartbeat.instance.resetFailures();
    MainScaffoldPage.resetNoticeSession();
    SourceGuard.markReconnectedCooldown();

    if (!mounted) return;
    _toast(_reconnect ? '已重新接入' : '源已接入');
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    SourceGuard.notifyReconnected();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onReconnectBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackPressMs < 2000) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressMs = now;
    _toast('再按一次退出应用');
  }

  void _showHistoryDialog() {
    FocusScope.of(context).unfocus();
    final currentFull = _controller.text.trim();
    showServerHistoryDialog(
      context: context,
      historyOf: () => _serverHistory,
      currentUrl: currentFull,
      onSelect: (item) {
        setState(() {
          _controller.text = item;
        });
      },
      onReload: _loadHistory,
      onToastCleared: () => _toast('已清空历史软件源'),
    );
  }

  Widget _brand({required bool landscape}) {
    final subtitle = _reconnect
        ? (landscape ? '软件源连接失败\n请重新接入' : '软件源连接失败，请检查后重新接入')
        : (landscape ? '配置软件源后观影' : '配置软件源后即可观影');
    final iconSize = landscape ? 72.0 : 88.0;
    final iconRadius = landscape ? 16.0 : 20.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StartIconImage(size: iconSize, radius: iconRadius),
        SizedBox(height: landscape ? 8 : 14),
        Text(
          'EcoHub',
          style: TextStyle(
            fontSize: landscape ? 22 : 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: landscape ? 4 : 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: landscape ? 11 : 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _form({required bool landscape}) {
    final inputH = landscape ? 42.0 : 48.0;
    final inputFont = landscape ? 13.0 : 14.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '软件源地址',
              style: TextStyle(fontSize: landscape ? 12 : 13, color: AppTheme.textSecondary),
            ),
            if (_serverHistory.isNotEmpty)
              FocusTap(
                focusRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: _showHistoryDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: landscape ? 6 : 8, vertical: landscape ? 3 : 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: landscape ? 11 : 12, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '历史记录 (${_serverHistory.length})',
                        style: TextStyle(fontSize: landscape ? 11 : 12, color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: landscape ? 6 : 8),
        Container(
          height: inputH,
          padding: EdgeInsets.only(left: landscape ? 12 : 14, right: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                // TvTextField：TV 上聚焦时主动拉起输入法，并画出明显的焦点框 ——
                // 原生 TextField 在 Android TV 上键盘不弹、焦点几乎不可见。
                child: TvTextField(
                  controller: _controller,
                  style: TextStyle(fontSize: inputFont, color: AppTheme.textPrimary),
                  hintText: '请输入软件源地址',
                  hintStyle: TextStyle(fontSize: inputFont, color: AppTheme.textMuted),
                  cursorColor: AppTheme.accent,
                  textInputAction: TextInputAction.done,
                  focusRadius: BorderRadius.circular(AppTheme.radiusMd),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _saveAndConnect(),
                ),
              ),
              if (_controller.text.isNotEmpty)
                FocusTap(
                  focusRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _controller.clear()),
                  child: SizedBox(
                    width: landscape ? 32 : 36,
                    height: inputH,
                    child: Icon(Icons.cancel_rounded, size: landscape ? 15 : 16, color: AppTheme.textMuted),
                  ),
                ),
            ],
          ),
        ),
        // TV：很多 Android TV 定制系统不提供 TV 版软键盘面板
        // （`TextInput.show` 只会标记「已请求」但界面不弹），
        // 用户因此完全无法输入。这里提供应用内自绘键盘，遥控器可逐键选择。
        if (TvMode.isTvActive) ...[
          SizedBox(height: landscape ? 8 : 12),
          TvKeyboardPanel(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            onDone: _saveAndConnect,
          ),
        ],
        SizedBox(height: landscape ? 12 : 24),
        SizedBox(
          width: double.infinity,
          height: inputH,
          // FocusHighlight：Material 按钮自带焦点能力，但高亮太弱，
          // 电视上看不出当前选中的是哪个按钮。
          child: FocusHighlight(
            radius: BorderRadius.circular(AppTheme.radiusMd),
            child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textPrimary,
              disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _saveAndConnect,
            child: Text(
              _isLoading ? '正在连接...' : (_reconnect ? '重新接入' : '开始观影'),
              style: TextStyle(fontSize: landscape ? 15 : 16, fontWeight: FontWeight.bold),
            ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final canBack = !_reconnect && Navigator.canPop(context);

    return PopScope(
      canPop: !_reconnect,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onReconnectBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              if (canBack)
                SizedBox(
                  height: landscape ? 36 : 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              landscape ? 16 : 24,
                              landscape ? 4 : 20,
                              landscape ? 16 : 24,
                              24,
                            ),
                            child: landscape
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 160, child: _brand(landscape: true)),
                                      const SizedBox(width: 28),
                                      Expanded(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 440),
                                          child: _form(landscape: true),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _brand(landscape: false),
                                      const SizedBox(height: 28),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        child: _form(landscape: false),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
