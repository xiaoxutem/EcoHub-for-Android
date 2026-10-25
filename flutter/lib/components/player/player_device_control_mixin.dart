import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'player_window.dart';

/// 播放器设备控制 Mixin，管理亮度、音量与屏幕常亮唤醒锁
mixin PlayerDeviceControlMixin on ChangeNotifier {
  double _brightness = 0.5;
  double get brightness => _brightness;

  double _volume = 0.8;
  double get volume => _volume;

  bool _muted = false;
  bool get muted => _muted;

  Future<void> loadWindowLevels() async {
    final b = await PlayerWindow.getBrightness();
    final v = await PlayerWindow.getVolume();
    _brightness = b;
    _volume = v;
    notifyListeners();
  }

  void safeSetWakelock(bool enable) {
    try {
      (enable ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
    } catch (_) {}
  }

  void setBrightness(double v) {
    _brightness = v;
    PlayerWindow.setBrightness(v);
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v;
    if (!_muted) PlayerWindow.setVolume(v);
    notifyListeners();
  }

  void setMutedInternal(bool m) {
    _muted = m;
    notifyListeners();
  }

  void resetDeviceControl() {
    PlayerWindow.resetBrightness();
    safeSetWakelock(false);
  }
}
