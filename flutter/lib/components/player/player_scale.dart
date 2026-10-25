import 'package:flutter/material.dart';

enum PlayerScaleMode { fit, cover, stretch }

/// 画面缩放循环，对齐 OHOS `PlayerScale`（Chip 循环，不是 Sheet）
class PlayerScale {
  static const PlayerScaleMode defaultMode = PlayerScaleMode.fit;

  static String label(PlayerScaleMode mode) {
    switch (mode) {
      case PlayerScaleMode.cover:
        return '填充';
      case PlayerScaleMode.stretch:
        return '拉伸';
      case PlayerScaleMode.fit:
        return '适应';
    }
  }

  static PlayerScaleMode next(PlayerScaleMode mode) {
    switch (mode) {
      case PlayerScaleMode.fit:
        return PlayerScaleMode.cover;
      case PlayerScaleMode.cover:
        return PlayerScaleMode.stretch;
      case PlayerScaleMode.stretch:
        return PlayerScaleMode.fit;
    }
  }

  static BoxFit boxFit(PlayerScaleMode mode) {
    switch (mode) {
      case PlayerScaleMode.cover:
        return BoxFit.cover;
      case PlayerScaleMode.stretch:
        return BoxFit.fill;
      case PlayerScaleMode.fit:
        return BoxFit.contain;
    }
  }
}
