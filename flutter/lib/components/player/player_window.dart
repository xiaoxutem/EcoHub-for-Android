import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

/// 系统亮度 / 媒体音量，对齐 OHOS `PlayerWindow`
class PlayerWindow {
  static Future<double> getBrightness() async {
    try {
      return (await ScreenBrightness.instance.application).clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  static Future<void> resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  static Future<double> getVolume() async {
    try {
      return (await VolumeController.instance.getVolume()).clamp(0.0, 1.0);
    } catch (_) {
      return 0.8;
    }
  }

  static Future<void> setVolume(double value) async {
    try {
      VolumeController.instance.showSystemUI = false;
      await VolumeController.instance.setVolume(value.clamp(0.0, 1.0));
    } catch (_) {}
  }
}
