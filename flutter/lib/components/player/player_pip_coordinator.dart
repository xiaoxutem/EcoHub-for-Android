import 'package:flutter/material.dart';
import '../../services/pip_manager.dart';
import '../../utils/app_settings_manager.dart';

/// 画中画 (PiP) 调度控制器，负责自动小窗、手动切小窗、能力检测与系统控制栏动作分发
class PlayerPipCoordinator {
  final VoidCallback onStateChanged;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  bool isPipActive = false;
  bool pipSupported = false;

  PlayerPipCoordinator({
    required this.onStateChanged,
    this.onPlay,
    this.onPause,
    this.onPrev,
    this.onNext,
  });

  void init() {
    _checkSupport();
    PipManager.instance.addListener(_handlePipChanged);
    PipManager.instance.addActionListener(_handlePipAction);
  }

  void dispose() {
    PipManager.instance.removeListener(_handlePipChanged);
    PipManager.instance.removeActionListener(_handlePipAction);
    PipManager.instance.setAutoPip(enabled: false);
  }

  Future<void> _checkSupport() async {
    pipSupported = await PipManager.instance.isPipSupported();
    onStateChanged();
  }

  void _handlePipChanged(bool active) {
    isPipActive = active;
    onStateChanged();
  }

  void _handlePipAction(String action) {
    switch (action) {
      case 'play':
        onPlay?.call();
        break;
      case 'pause':
        onPause?.call();
        break;
      case 'prev':
        onPrev?.call();
        break;
      case 'next':
        onNext?.call();
        break;
    }
  }

  void syncAutoPip({
    required bool isCasting,
    required String videoUrl,
    required String errorText,
    required bool isPlaying,
    required bool isCompleted,
    required bool hasPrev,
    required bool hasNext,
    required Size? videoSize,
  }) {
    final canAuto = pipSupported &&
        AppSettingsManager.instance.pipAutoStart &&
        !isCasting &&
        videoUrl.isNotEmpty &&
        errorText.isEmpty &&
        isPlaying &&
        (!isCompleted || hasNext);

    final w = (videoSize != null && videoSize.width > 0) ? videoSize.width.toInt() : 16;
    final h = (videoSize != null && videoSize.height > 0) ? videoSize.height.toInt() : 9;
    PipManager.instance.setAutoPip(enabled: canAuto, numerator: w, denominator: h);
    if (pipSupported) {
      PipManager.instance.updatePipActions(
        isPlaying: isPlaying,
        hasPrev: hasPrev,
        hasNext: hasNext,
      );
    }
  }

  void updateAspectRatio(Size? videoSize) {
    if (videoSize != null && videoSize.width > 0 && videoSize.height > 0) {
      PipManager.instance.updateAspectRatio(
        numerator: videoSize.width.toInt(),
        denominator: videoSize.height.toInt(),
      );
    }
  }

  void enterPip({
    required Size? videoSize,
    required bool isCasting,
    required bool isFull,
    required VoidCallback onExitFullscreen,
    required void Function(String message) showToast,
  }) {
    if (isCasting) {
      showToast('当前正在投屏，无法开启画中画');
      return;
    }
    if (!pipSupported) {
      showToast('当前设备不支持画中画');
      return;
    }
    if (isFull) {
      onExitFullscreen();
    }
    final w = (videoSize != null && videoSize.width > 0) ? videoSize.width.toInt() : 16;
    final h = (videoSize != null && videoSize.height > 0) ? videoSize.height.toInt() : 9;
    PipManager.instance.enterPip(numerator: w, denominator: h);
  }
}
