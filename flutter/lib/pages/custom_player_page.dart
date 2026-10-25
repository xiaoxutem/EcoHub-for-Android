import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/app_theme.dart';
import '../components/page_header.dart';
import '../components/player/video_player_widget.dart';
import '../utils/breakpoint.dart';
import '../utils/app_orientation.dart';
import '../utils/clipboard_sniffer.dart';
import '../services/pip_manager.dart';

/// 自定义播放页面，对齐 OHOS `CustomPlayerPage`
class CustomPlayerPage extends StatefulWidget {
  final String url;

  const CustomPlayerPage({super.key, this.url = ''});

  @override
  State<CustomPlayerPage> createState() => _CustomPlayerPageState();
}

class _CustomPlayerPageState extends State<CustomPlayerPage> {
  final TextEditingController _inputController = TextEditingController();
  String _playUrl = '';
  int _reloadToken = 0;
  bool _isFull = false;
  bool _isPipActive = false;
  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    PipManager.instance.addListener(_onPipChanged);
    _isPipActive = PipManager.instance.isPipActive;
    _applyRouteUrl(widget.url);
  }

  @override
  void dispose() {
    PipManager.instance.removeListener(_onPipChanged);
    _inputController.dispose();
    try {
      SystemChrome.setPreferredOrientations(kAutoRotationOrientations);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    super.dispose();
  }

  void _onPipChanged(bool active) {
    if (mounted && _isPipActive != active) {
      setState(() => _isPipActive = active);
    }
  }

  void _applyRouteUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == _playUrl) return;
    _inputController.text = url;
    _playUrl = url;
  }

  bool get _hasPlayUrl => _playUrl.trim().isNotEmpty;

  void _setFullscreen(bool full, {bool isPortrait = false}) {
    if (_isFull == full) return;
    setState(() {
      _isFull = full;
    });
    try {
      if (full) {
        SystemChrome.setPreferredOrientations(
          isPortrait
              ? [DeviceOrientation.portraitUp]
              : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        );
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations(kAutoRotationOrientations);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _play() {
    FocusScope.of(context).unfocus();
    final url = _inputController.text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      _toast('请输入正确的 mp4 或 m3u8 地址');
      return;
    }
    setState(() {
      _playUrl = url;
      _reloadToken++;
    });
  }

  Future<void> _onPaste() async {
    FocusScope.of(context).unfocus();
    final res = await ClipboardSniffer.sniff();
    if (!mounted) return;
    if (res.url.isNotEmpty) {
      ClipboardSniffer.markHandled(res.raw);
      _inputController.text = res.url;
      setState(() {
        _playUrl = res.url;
        _reloadToken++;
      });
      _toast('已提取剪贴板链接并开始播放');
    } else if (res.raw.isNotEmpty) {
      ClipboardSniffer.markHandled(res.raw);
      _inputController.text = res.raw;
      _play();
    } else {
      _toast('未在剪贴板中检测到有效链接');
    }
  }

  Widget _urlBar() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: '输入 mp4 或 m3u8 播放地址',
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _play(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: _onPaste,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: const SizedBox(
                height: 44,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      '粘贴',
                      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
              minimumSize: const Size(0, 44),
            ),
            onPressed: _play,
            child: const Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 18),
                SizedBox(width: 2),
                Text('播放', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _idlePane() {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Icon(Icons.play_circle_fill_rounded, size: 36, color: AppTheme.accent),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '粘贴直链即可播放',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '仅支持 mp4 / m3u8，不会写入观看历史',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 20 / 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _player({required bool isFull, required bool wide}) {
    final padding = MediaQuery.paddingOf(context);
    final player = VideoPlayerWidget(
      key: _videoKey,
      videoUrl: _playUrl,
      title: '自定义播放',
      showBack: isFull,
      isFull: isFull,
      topInset: isFull ? padding.top : 0,
      bottomInset: isFull ? padding.bottom : 0,
      leftInset: isFull ? padding.left : 0,
      rightInset: isFull ? padding.right : 0,
      reloadToken: _reloadToken,
      onBack: () => _setFullscreen(false),
      onFullscreenChange: _setFullscreen,
    );
    if (isFull) return Expanded(child: player);
    final box = AspectRatio(aspectRatio: 16 / 9, child: player);
    return wide ? Expanded(child: Center(child: box)) : box;
  }

  @override
  Widget build(BuildContext context) {
    if (_isPipActive && _hasPlayUrl) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: VideoPlayerWidget(
              key: _videoKey,
              videoUrl: _playUrl,
              title: '自定义播放',
              showBack: false,
              isFull: false,
              topInset: 0,
              bottomInset: 0,
              leftInset: 0,
              rightInset: 0,
              reloadToken: _reloadToken,
              onFullscreenChange: _setFullscreen,
            ),
          ),
        ),
      );
    }

    final isFullMode = _isFull;
    final wide = Breakpoint.isWideWidth(MediaQuery.sizeOf(context).width);

    return PopScope(
      canPop: !isFullMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullMode) {
          _setFullscreen(false);
        }
      },
      child: Scaffold(
        backgroundColor: isFullMode ? Colors.black : AppTheme.bg,
        body: SafeArea(
          top: !isFullMode,
          bottom: !isFullMode,
          left: false,
          right: false,
          child: Column(
            children: [
              if (!isFullMode) ...[
                const PageHeader(title: '自定义播放'),
                _urlBar(),
              ],
              if (_hasPlayUrl) ...[
                _player(isFull: isFullMode, wide: wide),
                if (!isFullMode)
                  const Padding(
                    padding: EdgeInsets.all(AppTheme.spaceLg),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '仅支持直链 mp4 / m3u8，不会写入观看历史。',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
              ] else if (!isFullMode)
                _idlePane(),
            ],
          ),
        ),
      ),
    );
  }
}
