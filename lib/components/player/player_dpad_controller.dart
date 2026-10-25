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
/// 与触摸手势互不冲突：只有 TV 模式且焦点位于视频区域时才接管按键。
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
  });

  @override
  State<PlayerDpadController> createState() => _PlayerDpadControllerState();
}

class _PlayerDpadControllerState extends State<PlayerDpadController> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PlayerDpad');
  bool _hasFocus = false;

  /// 长按左右键的连续快进/快退倍率与计时
  int _seekHoldMultiplier = 1;
  Timer? _seekHoldTimer;

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
    final has = _focusNode.hasFocus;
    if (has != _hasFocus) {
      setState(() => _hasFocus = has);
      if (!has) _stopSeekHold();
    }
  }

  void _stopSeekHold() {
    _seekHoldTimer?.cancel();
    _seekHoldTimer = null;
    if (_seekHoldMultiplier != 1) {
      _seekHoldMultiplier = 1;
    }
  }

  /// 单次跳转（秒）
  void _seekBy(int seconds) {
    final total = widget.totalDuration.inSeconds;
    final current = widget.currentPosition.inSeconds;
    final target = (current + seconds).clamp(0, total > 0 ? total : current);
    final dur = Duration(seconds: target);
    widget.onSeekTo(dur);
    final sign = seconds >= 0 ? '+' : '';
    widget.onPanStateChange(PlayerPanState(
      kind: seconds >= 0 ? PlayerTipKind.seekFwd : PlayerTipKind.seekBack,
      text: '$sign$seconds 秒',
      previewTime: dur,
    ));
  }

  void _adjustVolume(double delta) {
    final next = (widget.currentVolume + delta).clamp(0.0, 1.0);
    widget.onVolumeChange(next);
    widget.onPanStateChange(PlayerPanState(
      kind: PlayerTipKind.volume,
      text: '${(next * 100).round()}%',
    ));
  }

  void _startSeekHold(int direction) {
    _stopSeekHold();
    _seekHoldTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      // 长按加速：10s → 30s → 60s 逐级提升
      _seekHoldMultiplier = _seekHoldMultiplier >= 6 ? 1 : _seekHoldMultiplier * 3;
      _seekBy(direction * 10 * _seekHoldMultiplier);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!TvMode.isTv) return KeyEventResult.ignored;

    // 只处理按下事件，抬起时清理长按状态
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _stopSeekHold();
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
    if (!TvMode.isTv) return widget.child;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
