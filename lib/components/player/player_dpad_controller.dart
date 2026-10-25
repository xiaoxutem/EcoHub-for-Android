import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/tv_mode.dart';
import 'player_gesture_handler.dart';

/// TV 遥控器 D-pad 播放控制。
///
/// 手机端的进度/音量/亮度调整全部依赖触摸拖拽，遥控器无法操作。
/// 本组件把 D-pad 方向键映射到标准 TV 播放器手势：
///
/// | 遥控器按键 | 行为                        |
/// |-----------|-----------------------------|
/// | 上下       | 音量 ±10%（静音状态下先取消静音）|
/// | 左右       | 快进 / 快退（长按连续加速）     |
/// | OK / 播放键 | 播放 / 暂停切换              |
/// | 返回键     | 退出全屏 / 关闭播放器          |
///
/// ## 与方向键焦点导航的分工（重要）
///
/// Flutter 默认把方向键映射为 `DirectionalFocusIntent`（移动焦点）。
/// 若本组件无条件消费方向键，HUD 上的播放/暂停/±10s/倍速按钮将**无法被
/// 遥控器选中**，成为死代码。
///
/// 因此这里的策略是：**焦点位于 HUD 可交互控件上时，方向键交还给焦点导航；
/// 焦点在视频画面上时，方向键才用于调整音量与进度。**
/// 判定方式为「当前主焦点的 Element 是否位于 HUD 区域内」。
class PlayerDpadController extends StatefulWidget {
  final Widget child;
  final bool isFull;
  final bool isPlaying;
  final bool muted;
  final Duration currentPosition;
  final Duration totalDuration;
  final double currentVolume;
  final VoidCallback onTogglePlay;
  final VoidCallback onBack;
  final ValueChanged<Duration> onSeekTo;
  final ValueChanged<double> onVolumeChange;
  final void Function(PlayerPanState state) onPanStateChange;
  final VoidCallback onToggleMute;

  /// HUD 区域的控件（播放/暂停、±10s、倍速、全屏等）。
  ///
  /// 焦点落在这个子树里时，方向键让给焦点导航，不用于调整音量/进度。
  final Widget? hudOverlay;

  const PlayerDpadController({
    super.key,
    required this.child,
    required this.isFull,
    required this.isPlaying,
    required this.muted,
    required this.currentPosition,
    required this.totalDuration,
    required this.currentVolume,
    required this.onTogglePlay,
    required this.onBack,
    required this.onSeekTo,
    required this.onVolumeChange,
    required this.onPanStateChange,
    required this.onToggleMute,
    this.hudOverlay,
  });

  @override
  State<PlayerDpadController> createState() => _PlayerDpadControllerState();
}

class _PlayerDpadControllerState extends State<PlayerDpadController> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PlayerDpad');

  /// 长按左右键的连续快进/快退步长倍率与计时器
  int _seekHoldSeconds = 10;
  Timer? _seekHoldTimer;

  /// 累积的 seek 目标，避免连续快进基于陈旧的 currentPosition 累加。
  Duration? _seekAccumulated;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _seekHoldTimer?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    // 焦点离开视频区时终止长按，避免定时器在后台继续跳进度。
    if (!_focusNode.hasFocus) _stopSeekHold();
  }

  void _stopSeekHold() {
    _seekHoldTimer?.cancel();
    _seekHoldTimer = null;
    if (_seekHoldSeconds != 10) _seekHoldSeconds = 10;
  }

  /// 跳转到指定位置（相对当前）。
  void _seekBy(int seconds) {
    final total = widget.totalDuration.inSeconds;
    final base = _seekAccumulated ?? widget.currentPosition;
    final target = (base.inSeconds + seconds).clamp(0, total > 0 ? total : base.inSeconds);
    final dur = Duration(seconds: target);
    _seekAccumulated = dur;
    widget.onSeekTo(dur);
    final sign = seconds >= 0 ? '+' : '';
    // 用 showTransient 播报：它会自动在提示结束后复位 kind=none，
    // 而 setPanState 不会复位（会导致 HUD 永久驻留且 toggleHud 失效）。
    widget.onPanStateChange(const PlayerPanState(kind: PlayerTipKind.none));
    widget.onPanStateChange(PlayerPanState(
      kind: seconds >= 0 ? PlayerTipKind.seekFwd : PlayerTipKind.seekBack,
      text: '$sign$seconds 秒',
      previewTime: dur,
    ));
  }

  void _adjustVolume(double delta) {
    final next = (widget.currentVolume + delta).clamp(0.0, 1.0);
    widget.onVolumeChange(next);
    widget.onPanStateChange(const PlayerPanState(kind: PlayerTipKind.none));
    widget.onPanStateChange(PlayerPanState(
      kind: PlayerTipKind.volume,
      text: '${(next * 100).round()}%',
    ));
  }

  /// 开始长按连续快进/快退。步长按 10s → 30s → 60s 逐级提升并封顶。
  void _startSeekHold(int direction) {
    _stopSeekHold();
    _seekHoldTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      _seekHoldSeconds = _seekHoldSeconds >= 60 ? 60 : (_seekHoldSeconds * 3).clamp(10, 60);
      _seekBy(direction * _seekHoldSeconds);
    });
  }

  /// 当前焦点是否落在 HUD 可交互控件上。
  ///
  /// 若在 HUD 上，方向键应交还给 Flutter 的焦点导航（移动到别的按钮），
  /// 而不是被用于调整音量/进度。
  bool _focusInHud() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    final hudContext = _hudContext;
    if (hudContext == null) return false;

    var found = false;
    primary.context?.visitAncestorElements((ancestor) {
      if (identical(ancestor, hudContext)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  BuildContext? _hudContext;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!TvMode.isTvActive) return KeyEventResult.ignored;

    // 只处理按下事件，抬起时清理长按状态
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _stopSeekHold();
        _seekAccumulated = null;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // 返回键：全屏时先退出全屏
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      widget.onBack();
      return KeyEventResult.handled;
    }

    // 播放/暂停：OK 键与媒体播放键
    if (key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      widget.onTogglePlay();
      return KeyEventResult.handled;
    }

    final isArrow = key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (!isArrow) return KeyEventResult.ignored;

    // 焦点在 HUD 控件上时，方向键用于在按钮间移动焦点，不调整音量/进度。
    // 返回 ignored 让事件继续冒泡到全局 Shortcuts 的 DirectionalFocusIntent。
    if (_focusInHud()) return KeyEventResult.ignored;

    // 非全屏（分栏）模式下，方向键留给页面列表滚动与焦点导航，
    // 否则剧集列表、侧栏将无法用遥控器操作。
    if (!widget.isFull) return KeyEventResult.ignored;

    // 音量：上下键
    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.muted) widget.onToggleMute();
      _adjustVolume(0.1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.muted) widget.onToggleMute();
      _adjustVolume(-0.1);
      return KeyEventResult.handled;
    }

    // 快进/快退：左右键
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(10);
      _startSeekHold(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-10);
      _startSeekHold(-1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // 非 TV 模式：不做任何按键接管，但 HUD 仍需正常渲染
    // （HUD 由本组件托管，因此这里必须一并输出）。
    if (!TvMode.isTvActive) {
      if (widget.hudOverlay == null) return widget.child;
      return Stack(
        fit: StackFit.expand,
        children: [widget.child, widget.hudOverlay!],
      );
    }

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // HUD 单独包一层 Builder 以便记录其 Element 上下文，
          // 用于判断当前焦点是否落在 HUD 区域内。
          if (widget.hudOverlay != null)
            Builder(
              builder: (ctx) {
                _hudContext = ctx;
                return widget.hudOverlay!;
              },
            ),
        ],
      ),
    );
  }
}
