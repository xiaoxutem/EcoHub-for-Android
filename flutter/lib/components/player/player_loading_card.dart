import 'dart:async';
import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import '../focus_wrap.dart';

/// 播放加载缓冲卡片（200ms 防闪烁防抖、350ms 最短展示、6s 慢网提醒），对齐 OHOS `PlayerLoadingCard`
class PlayerLoadingCard extends StatefulWidget {
  final bool visible;
  final bool isOpening;
  final bool allowRetry;
  /// 换集 / 重试等新加载会话。变化时清掉「网络较慢」并重开 6s 计时。
  final int resetToken;
  final VoidCallback? onRetry;

  const PlayerLoadingCard({
    super.key,
    required this.visible,
    this.isOpening = false,
    this.allowRetry = true,
    this.resetToken = 0,
    this.onRetry,
  });

  @override
  State<PlayerLoadingCard> createState() => _PlayerLoadingCardState();
}

class _PlayerLoadingCardState extends State<PlayerLoadingCard> {
  static const int debounceDelayMs = 200;
  static const int minDisplayMs = 350;
  static const int slowNetworkMs = 6000;

  bool _showCard = false;
  bool _slowNetwork = false;
  Timer? _showTimer;
  Timer? _hideTimer;
  Timer? _slowTimer;
  int _shownAt = 0;

  @override
  void initState() {
    super.initState();
    _syncGates();
  }

  @override
  void didUpdateWidget(covariant PlayerLoadingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _clearSlowTimer();
      if (_slowNetwork) {
        setState(() => _slowNetwork = false);
      } else {
        _slowNetwork = false;
      }
    }
    if (oldWidget.visible != widget.visible ||
        oldWidget.allowRetry != widget.allowRetry ||
        oldWidget.isOpening != widget.isOpening ||
        oldWidget.resetToken != widget.resetToken) {
      _syncGates();
    }
  }

  @override
  void dispose() {
    _clearAllTimers();
    super.dispose();
  }

  void _clearShowTimer() {
    _showTimer?.cancel();
    _showTimer = null;
  }

  void _clearHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _clearSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = null;
  }

  void _clearAllTimers() {
    _clearShowTimer();
    _clearHideTimer();
    _clearSlowTimer();
  }

  void _armSlowTimer() {
    if (_slowNetwork || _slowTimer != null) return;
    _slowTimer = Timer(const Duration(milliseconds: slowNetworkMs), () {
      _slowTimer = null;
      if (mounted && widget.visible && widget.allowRetry) {
        setState(() => _slowNetwork = true);
      }
    });
  }

  void _hideRetry() {
    _clearSlowTimer();
    if (_slowNetwork) {
      setState(() => _slowNetwork = false);
    }
  }

  void _handleRetry() {
    if (!_slowNetwork) return;
    _hideRetry();
    if (widget.visible && widget.allowRetry) {
      _armSlowTimer();
    }
    widget.onRetry?.call();
  }

  void _syncGates() {
    if (widget.visible && widget.allowRetry) {
      _armSlowTimer();
    } else {
      _hideRetry();
    }
    _syncCardVisibility();
  }

  void _syncCardVisibility() {
    if (widget.visible) {
      _clearHideTimer();
      if (_showCard) return;
      final delay = widget.isOpening ? 0 : debounceDelayMs;
      if (delay == 0) {
        _doShow();
        return;
      }
      _clearShowTimer();
      _showTimer = Timer(Duration(milliseconds: delay), () {
        _showTimer = null;
        if (mounted) _doShow();
      });
      return;
    }

    _clearShowTimer();
    if (!_showCard) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _shownAt;
    if (elapsed >= minDisplayMs) {
      setState(() => _showCard = false);
      return;
    }
    _clearHideTimer();
    _hideTimer = Timer(Duration(milliseconds: minDisplayMs - elapsed), () {
      _hideTimer = null;
      if (mounted) setState(() => _showCard = false);
    });
  }

  void _doShow() {
    setState(() {
      _showCard = true;
      _shownAt = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCard) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xC7000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                widget.isOpening ? '正在打开...' : '加载中...',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_slowNetwork) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '网络较慢',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(width: 8),
                  FocusTap(
                    focusRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: _handleRetry,
                    child: const Text(
                      '点击重试',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
