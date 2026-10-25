import 'dart:async';

/// HUD 隐藏 / 打开超时 / seek 超时，对齐 OHOS `PlayerStallWatcher`
class PlayerStallWatcher {
  static const int hideDelayMs = 3000;
  static const int tipDurationMs = 1000;
  static const int openTimeoutMs = 30000;
  static const int seekTimeoutMs = 8000;
  static const int progressPersistMs = 3000;

  Timer? _hideTimer;
  Timer? _tipTimer;
  Timer? _openTimer;
  Timer? _seekTimer;

  void armHide(void Function() callback, {required bool canHide}) {
    clearHide();
    if (!canHide) return;
    _hideTimer = Timer(const Duration(milliseconds: hideDelayMs), callback);
  }

  void clearHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void armOpenWatch(void Function() callback, {required bool isOpening}) {
    clearOpenWatch();
    if (!isOpening) return;
    _openTimer = Timer(const Duration(milliseconds: openTimeoutMs), callback);
  }

  void clearOpenWatch() {
    _openTimer?.cancel();
    _openTimer = null;
  }

  void armSeekWatch(void Function() callback, {required bool isSeeking}) {
    clearSeekWatch();
    if (!isSeeking) return;
    _seekTimer = Timer(const Duration(milliseconds: seekTimeoutMs), callback);
  }

  void clearSeekWatch() {
    _seekTimer?.cancel();
    _seekTimer = null;
  }

  void showTip(void Function() onClear) {
    _tipTimer?.cancel();
    _tipTimer = Timer(const Duration(milliseconds: tipDurationMs), onClear);
  }

  void dispose() {
    clearHide();
    clearOpenWatch();
    clearSeekWatch();
    _tipTimer?.cancel();
    _tipTimer = null;
  }
}
