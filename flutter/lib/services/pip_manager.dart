import 'dart:async';
import 'package:flutter/services.dart';

/// 画中画管理服务，对齐 OHOS `PlayerPip.ets`
class PipManager {
  static const MethodChannel _channel = MethodChannel('com.ecohub.ecohub/pip');

  static final PipManager instance = PipManager._();
  PipManager._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  bool _isPipActive = false;
  bool get isPipActive => _isPipActive;

  final List<void Function(bool active)> _listeners = [];
  final List<void Function(String action)> _actionListeners = [];

  void addListener(void Function(bool active) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(bool active) listener) {
    _listeners.remove(listener);
  }

  void addActionListener(void Function(String action) listener) {
    _actionListeners.add(listener);
  }

  void removeActionListener(void Function(String action) listener) {
    _actionListeners.remove(listener);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final active = call.arguments as bool? ?? false;
      if (_isPipActive != active) {
        _isPipActive = active;
        for (final l in List.of(_listeners)) {
          try {
            l(active);
          } catch (_) {}
        }
      }
    } else if (call.method == 'onPipAction') {
      final action = call.arguments as String? ?? '';
      if (action.isNotEmpty) {
        for (final l in List.of(_actionListeners)) {
          try {
            l(action);
          } catch (_) {}
        }
      }
    }
  }

  Future<bool> isPipSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enterPip({int numerator = 16, int denominator = 9}) async {
    try {
      final res = await _channel.invokeMethod<bool>('enterPip', {
        'numerator': numerator,
        'denominator': denominator,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoPip({required bool enabled, int numerator = 16, int denominator = 9}) async {
    try {
      await _channel.invokeMethod('setAutoPip', {
        'enabled': enabled,
        'numerator': numerator,
        'denominator': denominator,
      });
    } catch (_) {}
  }

  Future<void> updatePipActions({
    required bool isPlaying,
    required bool hasPrev,
    required bool hasNext,
  }) async {
    try {
      await _channel.invokeMethod('updatePipActions', {
        'isPlaying': isPlaying,
        'hasPrev': hasPrev,
        'hasNext': hasNext,
      });
    } catch (_) {}
  }

  Future<void> updateAspectRatio({
    required int numerator,
    required int denominator,
  }) async {
    try {
      await _channel.invokeMethod('updateAspectRatio', {
        'numerator': numerator,
        'denominator': denominator,
      });
    } catch (_) {}
  }
}
