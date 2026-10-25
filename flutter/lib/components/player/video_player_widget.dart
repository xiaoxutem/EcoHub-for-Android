import 'package:flutter/material.dart';
import 'player_gesture_handler.dart';
import 'player_skin_view.dart';
import 'player_speed_sheet.dart';
import 'player_scale.dart';
import 'player_pip_coordinator.dart';
import 'player_video_surface.dart';
import 'player_playback_controller.dart';
import 'player_dpad_controller.dart';
import '../cast/player_cast_controller.dart';
import '../cast/player_cast_hud.dart';
import '../../types/dlna_types.dart';
import '../../utils/tv_focus_scope.dart';

/// 跨平台视频播放器，全量对齐 OHOS `VideoPlayer.ets`
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String poster;
  final double initialTime;
  final bool showBack;
  final bool isFull;
  final bool hasPrev;
  final bool hasNext;
  final bool pageActive;
  final bool edgeHud;
  final int reloadToken;
  final double topInset;
  final double leftInset;
  final double rightInset;
  final double bottomInset;
  final VoidCallback? onBack;
  final VoidCallback? onEnded;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(bool full, {bool isPortrait})? onFullscreenChange;
  final void Function(double current, double duration)? onProgress;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.title = '',
    this.poster = '',
    this.initialTime = 0,
    this.showBack = false,
    this.isFull = false,
    this.hasPrev = false,
    this.hasNext = false,
    this.pageActive = true,
    this.edgeHud = false,
    this.reloadToken = 0,
    this.topInset = 0,
    this.leftInset = 0,
    this.rightInset = 0,
    this.bottomInset = 0,
    this.onBack,
    this.onEnded,
    this.onPrev,
    this.onNext,
    this.onFullscreenChange,
    this.onProgress,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver
    implements PlayerCastHost {

  /// HUD 控制条的焦点作用域。
  ///
  /// ## 为什么需要
  ///
  /// HUD 里的按钮（返回 / 投屏 / 画中画 / 全屏）都是小尺寸元素，
  /// 而播放器上层有一个覆盖整个播放区域的 `Focus` 节点。
  /// Flutter 的方向键遍历是**几何感知**的 —— 从覆盖全屏的大节点出发按 ↑，
  /// 往往找不到 HUD 里那些小按钮（几何距离太远），
  /// 于是焦点永远到不了全屏按钮（用户反馈：无法选择全屏）。
  ///
  /// ## 做法
  ///
  /// 把 HUD 包进独立的 [FocusScope]，非全屏时 HUD 一旦显示，
  /// 就把焦点主动移进这个 scope —— [FocusScopeNode.requestFocus] 会自动
  /// 选中 scope 内的**第一个**可聚焦元素（返回键），
  /// 之后用户用 → 就能依次走到全屏按钮。
  final FocusScopeNode _hudFocusScope = FocusScopeNode(debugLabel: 'playerHud');

  /// 上一次控制条是否处于显示状态（用于检测「刚显示」）。
  bool _lastControlsShown = false;
  final PlayerPlaybackController _playback = PlayerPlaybackController();
  final PlayerCastController _castCtrl = PlayerCastController();
  late final PlayerPipCoordinator _pipCoord;

  int _lastCastPersistMs = 0;

  @override
  double get currentPosition => _castCtrl.isCasting
      ? _castCtrl.session.positionSec
      : _playback.currentPositionSec;
  @override
  double get totalDuration => _castCtrl.isCasting
      ? (_castCtrl.session.durationSec > 0 ? _castCtrl.session.durationSec : _playback.totalDurationSec)
      : _playback.totalDurationSec;
  @override
  bool get isPlaying => _castCtrl.isCasting
      ? (_castCtrl.session.phase == CastPhase.playing)
      : _playback.isPlaying;
  @override
  bool get isOpening => _playback.isOpening;
  @override
  bool get isBuffering => _playback.isBuffering;
  @override
  String get videoUrl => widget.videoUrl;
  @override
  String get title => widget.title;
  @override
  bool get hasNext => widget.hasNext;
  @override
  double get volume => _playback.volume;
  @override
  bool get isFull => widget.isFull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _castCtrl.attachHost(this);
    _playback.onEnded = widget.onEnded;
    _playback.onProgress = (cur, dur) {
      if (!_castCtrl.isCasting) {
        widget.onProgress?.call(cur, dur);
      }
    };
    _playback.onStateChanged = () {
      _syncAutoPip();
      _pipCoord.updateAspectRatio(_playback.controller?.value.size);
    };

    _pipCoord = PlayerPipCoordinator(
      onStateChanged: () {
        if (mounted) setState(() {});
        if (!_pipCoord.isPipActive) _syncAutoPip();
      },
      onPlay: () {
        if (!_castCtrl.isCasting) {
          _playback.play();
        }
      },
      onPause: () {
        if (!_castCtrl.isCasting) {
          _playback.pause();
        }
      },
      onPrev: widget.onPrev,
      onNext: widget.onNext,
    )..init();

    _playback.loadWindowLevels();
    _playback.initPlayer(widget.videoUrl, initialTime: widget.initialTime);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.onEnded = widget.onEnded;
    if (oldWidget.videoUrl != widget.videoUrl || oldWidget.reloadToken != widget.reloadToken) {
      if (_castCtrl.isCasting) {
        final consumed = _castCtrl.handleSourceChange();
        if (!consumed) {
          _playback.initPlayer(widget.videoUrl);
        }
      } else {
        _playback.initPlayer(widget.videoUrl);
      }
    }
    if (oldWidget.hasPrev != widget.hasPrev || oldWidget.hasNext != widget.hasNext) {
      _syncAutoPip();
    }
    _maybeFocusControls();
  }

  /// 控制条刚出现时（非全屏）把焦点送到播放 / 暂停按钮。
  ///
  /// 对齐 React Native TV 版的 `hasTVPreferredFocus` 行为：
  /// 控制条一显示，遥控器就能直接操作它。
  void _maybeFocusControls() {
    final shown = _playback.showHud;
    final justShown = shown && !_lastControlsShown;
    _lastControlsShown = shown;
    if (!justShown) return;
    if (widget.isFull) return; // 全屏下方向键用于音量 / 快进，焦点留在画面上

    // 焦点已经在**播放器之外**（比如用户正在操作侧栏）就不抢；
    // 在播放器区域内（或者还没落点）才把焦点交给播放 / 暂停键。
    //
    // 注意：不能写成 `primaryFocus != null` —— 那个条件几乎恒为真
    // （Flutter 总会给出一个 primary focus），会导致焦点永远送不出去。
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null) {
      // 焦点是否在播放器区域内（沿 Focus 祖先链找 HUD scope）。
      var inHud = false;
      FocusNode? node = primary;
      while (node != null) {
        if (identical(node, _hudFocusScope)) {
          inHud = true;
          break;
        }
        node = node.parent;
      }
      // 焦点在侧栏等**播放器之外**的区域就不抢。
      if (!inHud) {
        final inPlayer = primary.context != null &&
            primary.context!
                .findAncestorWidgetOfExactType<VideoPlayerWidget>() != null;
        if (!inPlayer) return;
      }
    }
    focusPlayButton();
  }

  /// HUD 控制条出现时，把焦点送到**播放 / 暂停**按钮。
  ///
  /// ## 为什么
  ///
  /// 播放器的 HUD 在**左侧视频区**，侧栏在右侧，两者几何上不重叠 ——
  /// 遥控器方向键在侧栏里走不到 HUD，焦点永远到不了全屏按钮。
  ///
  /// 参考 React Native TV 版（`PangHuTV-for-Android` 的 `feat/rn-tv` 分支）
  /// 的做法：它用 `hasTVPreferredFocus={showControls}` ——
  /// **控制条一显示，焦点就自动落到控制条上**。
  ///
  /// 这里选「播放 / 暂停」而不是「返回」：
  /// 焦点落在返回键上时，用户按 OK 想暂停反而会退出播放页。
  void focusPlayButton() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bridge = TvFocusScope.maybeOf(context);
      final node = bridge?.nodeOf('player_play', 0);
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }
      // 兜底：底栏没渲染出来时，退到 HUD 的第一个按钮。
      final hud = bridge?.nodeOf('player_hud', 0);
      hud?.requestFocus();
    });
  }

  /// 把焦点移进 HUD 作用域（选中 scope 内第一个可聚焦元素）。
  ///
  /// 由播放页在需要时调用（例如侧栏按 ↑ 时跳到 HUD）。
  void requestHudFocus() {
    if (!mounted) return;

    // HUD 已隐藏 → 先把它显示出来（否则里面没有可聚焦的按钮）。
    if (!_playback.showHud) {
      _playback.toggleHud();
    }

    // 下一帧再请求：此时 HUD 的按钮已完成构建并注册到 bridge。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 优先直接请求 HUD 第一个按钮（返回键）的节点 ——
      // 比 requestFocus() 到整个 scope 更精确。
      final bridge = TvFocusScope.maybeOf(context);
      final node = bridge?.nodeOf('player_hud', 0);
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }

      // 兜底：请求 scope（Flutter 会在 scope 内选中第一个可聚焦后代）。
      if (!_hudFocusScope.canRequestFocus) return;
      _hudFocusScope.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipCoord.dispose();
    _castCtrl.dispose();
    _playback.dispose();
    super.dispose();
  }

  void _syncAutoPip() {
    _pipCoord.syncAutoPip(
      isCasting: _castCtrl.isCasting,
      videoUrl: widget.videoUrl,
      errorText: _playback.errorText,
      isPlaying: _playback.isPlaying,
      isCompleted: _playback.isCompleted,
      hasPrev: widget.hasPrev,
      hasNext: widget.hasNext,
      videoSize: _playback.controller?.value.size,
    );
  }

  bool _isPortraitVideo() {
    final c = _playback.controller;
    if (c == null || !c.value.isInitialized) return false;
    final size = c.value.size;
    final rot = c.value.rotationCorrection;
    final isRotated = rot == 90 || rot == 270;
    final w = isRotated ? size.height : size.width;
    final h = isRotated ? size.width : size.height;
    if (w > 0 && h > 0) {
      return h > w;
    }
    final aspect = c.value.aspectRatio;
    return aspect > 0 && aspect < 1.0;
  }

  void _toggleFullscreen() {
    if (_castCtrl.isCasting) {
      showToast('投屏中无法全屏，请先停止投屏');
      return;
    }
    widget.onFullscreenChange?.call(!widget.isFull, isPortrait: _isPortraitVideo());
  }

  void _handleManualStartPip() {
    _pipCoord.enterPip(
      videoSize: _playback.controller?.value.size,
      isCasting: _castCtrl.isCasting,
      isFull: widget.isFull,
      onExitFullscreen: () => widget.onFullscreenChange?.call(false, isPortrait: _isPortraitVideo()),
      showToast: showToast,
    );
  }

  @override
  void parkLocal() {
    _playback.parkForCast();
    _syncAutoPip();
  }

  @override
  void pauseLocal() {
    _playback.pauseLocal();
    _syncAutoPip();
  }

  @override
  void exitFullForCast() {
    if (widget.isFull) {
      widget.onFullscreenChange?.call(false, isPortrait: _isPortraitVideo());
    }
  }

  @override
  void resumeLocal(double targetSec, bool wasPlaying) {
    // 投屏选择器取消时本地播放器仍在：只 seek/play，避免 initPlayer 导致画面重载。
    // 仍在打开中也不要重挂，否则会打断进行中的 initialize。
    final c = _playback.controller;
    if ((c != null && c.value.isInitialized) || _playback.isOpening) {
      _playback.resumeLocal(targetSec, wasPlaying);
    } else {
      _playback.initPlayer(widget.videoUrl, initialTime: targetSec, autoPlay: wasPlaying);
    }
    _syncAutoPip();
  }

  @override
  void remountCompleted(double positionSec, double durationSec) {
    _playback.remountCompleted(positionSec, durationSec);
    _syncAutoPip();
  }

  @override
  void onCastEnded() => widget.onEnded?.call();

  @override
  void syncUi() {
    if (mounted) setState(() {});
  }

  @override
  void syncProgress(double currentSec, double durationSec) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (widget.onProgress != null && durationSec > 0) {
      if (now - _lastCastPersistMs >= 5000) {
        _lastCastPersistMs = now;
        widget.onProgress!(currentSec, durationSec);
      }
    }
  }

  @override
  void showToast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void setPipAutoStart(bool enable) {
    _syncAutoPip();
  }

  @override
  void stopPip() {}

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        final pickerOpen = _castCtrl.pausedForPicker && !_castCtrl.isCasting;
        if (_pipCoord.isPipActive) {
          return Container(
            color: Colors.black,
            child: PlayerVideoSurface(
              controller: _playback.controller,
              scaleMode: _playback.scaleMode,
              poster: widget.poster,
              isOpening: _playback.isOpening,
              isReady: _playback.isReady,
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // TV 遥控器 D-pad 控制层：方向键接管进度/音量，OK 键播放暂停。
              // 非 TV 平台直接透传，行为与原来完全一致。
              PlayerDpadController(
                isFull: widget.isFull,
                isPlaying: _castCtrl.isCasting
                    ? (_castCtrl.session.phase == CastPhase.playing)
                    : _playback.isPlaying,
                muted: _playback.muted,
                currentPosition: Duration(seconds: currentPosition.toInt()),
                totalDuration: Duration(seconds: totalDuration.toInt()),
                currentVolume: _playback.volume,
                onTogglePlay: () {
                  if (!_castCtrl.isCasting) {
                    if (_playback.controller == null && _playback.isCompleted) {
                      _playback.initPlayer(widget.videoUrl, initialTime: 0, autoPlay: true);
                    } else {
                      _playback.togglePlay();
                    }
                  }
                },
                onBack: () {
                  if (widget.isFull) {
                    _toggleFullscreen();
                  } else {
                    widget.onBack?.call();
                  }
                },
                onSeekTo: _playback.seekTo,
                onVolumeChange: (v) {
                  _playback.setVolume(v);
                  if (_castCtrl.isCasting) {
                    _castCtrl.pushCastVolume(v);
                  }
                },
                onPanStateChange: _playback.setPanState,
                onToggleMute: () {
                  _playback.toggleMute();
                  if (_castCtrl.isCasting) {
                    _castCtrl.pushCastVolume(_playback.muted ? 0.0 : _playback.volume);
                  }
                },
                // HUD 交给 D-pad 控制器托管：焦点落在 HUD 按钮上时，
                // 方向键交还给焦点导航（可在按钮间移动），
                // 焦点在视频画面上时才用于调音量/快进快退。
                hudOverlay: FocusScope(
                  node: _hudFocusScope,
                  child: PlayerSkinView(
                  isFull: widget.isFull,
                  edgeHud: widget.edgeHud,
                  showHud: _playback.showHud || pickerOpen,
                  showBack: widget.showBack,
                  title: widget.title,
                  isPlaying: _castCtrl.isCasting
                      ? (_castCtrl.session.phase == CastPhase.playing)
                      : _playback.isPlaying,
                  isBuffering: _castCtrl.isCasting
                      ? (_castCtrl.session.phase == CastPhase.launching)
                      : _playback.isBuffering,
                  isOpening: _castCtrl.isCasting ? false : _playback.isOpening,
                  pickerOpen: pickerOpen,
                  loadSessionId: _playback.initSessionId,
                  isReady: _castCtrl.isCasting ? true : _playback.isReady,
                  isCompleted: _castCtrl.isCasting ? false : _playback.isCompleted,
                  muted: _playback.muted,
                  errorText: _playback.errorText,
                  currentPosition: _castCtrl.isCasting
                      ? Duration(seconds: currentPosition.toInt())
                      : _playback.displayPosition,
                  totalDuration: _castCtrl.isCasting
                      ? Duration(seconds: totalDuration.toInt())
                      : _playback.totalDuration,
                  currentSpeed: _playback.currentSpeed,
                  scaleLabel: PlayerScale.label(_playback.scaleMode),
                  hasPrev: widget.hasPrev,
                  hasNext: widget.hasNext,
                  panState: _playback.panState,
                  topInset: widget.topInset,
                  leftInset: widget.leftInset,
                  rightInset: widget.rightInset,
                  bottomInset: widget.bottomInset,
                  castDeviceName: _castCtrl.deviceName,
                  canCast: widget.videoUrl.trim().isNotEmpty,
                  onBack: () {
                    if (widget.isFull) {
                      _toggleFullscreen();
                    } else {
                      widget.onBack?.call();
                    }
                  },
                  onTogglePlay: () {
                    if (!_castCtrl.isCasting) {
                      if (_playback.controller == null && _playback.isCompleted) {
                        _playback.initPlayer(widget.videoUrl, initialTime: 0, autoPlay: true);
                      } else {
                        _playback.togglePlay();
                      }
                    }
                  },
                  onToggleFull: _toggleFullscreen,
                  onToggleMute: () {
                    _playback.toggleMute();
                    if (_castCtrl.isCasting) {
                      _castCtrl.pushCastVolume(_playback.muted ? 0.0 : _playback.volume);
                    }
                  },
                  onSpeed: () => PlayerSpeedSheet.show(context, _playback.currentSpeed, _playback.setSpeed),
                  onScale: _playback.cycleScale,
                  onRetry: () {
                    if (!_castCtrl.isCasting) {
                      _playback.initPlayer(widget.videoUrl);
                    }
                  },
                  onPrev: widget.onPrev,
                  onNext: widget.onNext,
                  onSeekBack10: () {
                    final target = Duration(seconds: (currentPosition - 10).clamp(0, totalDuration).toInt());
                    _playback.seekTo(target);
                  },
                  onSeekFwd10: () {
                    final target = Duration(seconds: (currentPosition + 10).clamp(0, totalDuration).toInt());
                    _playback.seekTo(target);
                  },
                  onSeekStart: _playback.setDragPreview,
                  onSeekProgress: _playback.setDragPreview,
                  onSeekTo: _playback.seekTo,
                  onCast: () => _castCtrl.openCastDialog(context),
                  onStopCast: () => _castCtrl.endCastByUser(),
                  onPip: _pipCoord.pipSupported ? _handleManualStartPip : null,
                ),
                ),
                child: PlayerGestureHandler(
                  currentPosition: _playback.currentPosition,
                  totalDuration: _playback.totalDuration,
                  isPlaying: _playback.isPlaying,
                  isFull: widget.isFull,
                  currentSpeed: _playback.currentSpeed,
                  currentBrightness: _playback.brightness,
                  currentVolume: _playback.volume,
                  onSingleTap: _playback.toggleHud,
                  onDoubleTap: () {
                    if (!_castCtrl.isCasting) _playback.togglePlay();
                  },
                  onSeekProgress: _playback.setDragPreview,
                  onSeekEnd: _playback.seekTo,
                  onSpeedChange: _playback.setSpeed,
                  onBrightnessChange: _playback.setBrightness,
                  onVolumeChange: (v) {
                    _playback.setVolume(v);
                    if (_castCtrl.isCasting) {
                      _castCtrl.pushCastVolume(v);
                    }
                  },
                  onPanStateChange: _playback.setPanState,
                  child: PlayerVideoSurface(
                    controller: _playback.controller,
                    scaleMode: _playback.scaleMode,
                    poster: widget.poster,
                    isOpening: _playback.isOpening,
                    isReady: _playback.isReady,
                  ),
                ),
              ),
              if (_castCtrl.deviceName.isNotEmpty && !widget.isFull)
                Center(
                  child: PlayerCastHud(
                    deviceName: _castCtrl.deviceName,
                    positionSec: _castCtrl.session.positionSec,
                    durationSec: _castCtrl.session.durationSec > 0
                        ? _castCtrl.session.durationSec
                        : totalDuration,
                    phase: _castCtrl.session.phase,
                    transportState: _castCtrl.session.transportState,
                    castSession: _castCtrl.session,
                    onStopCast: () => _castCtrl.endCastByUser(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
