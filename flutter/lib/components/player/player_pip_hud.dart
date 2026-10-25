import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/format_util.dart';
import '../focus_wrap.dart';

/// 画中画激活时主页面占位 HUD，对齐 OHOS `PlayerPipHud.ets`
class PlayerPipHud extends StatelessWidget {
  final String poster;
  final bool showBack;
  final double topInset;
  final double leftInset;
  final double rightInset;
  final VoidCallback? onBack;
  final VoidCallback? onRestore;

  const PlayerPipHud({
    super.key,
    this.poster = '',
    this.showBack = false,
    this.topInset = 0,
    this.leftInset = 0,
    this.rightInset = 0,
    this.onBack,
    this.onRestore,
  });

  double _edge(double base, double inset) => base > inset ? base : inset;

  @override
  Widget build(BuildContext context) {
    return FocusTap(
      onTap: onRestore,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 模糊封面背景
          if (poster.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                poster,
                headers: FormatUtil.imageHeaders(poster),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),

          // 2. 中间提示与恢复控制卡片
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '正在画中画播放中',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.fullscreen_exit_rounded, size: 16),
                label: const Text('恢复原位播放', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: onRestore,
              ),
            ],
          ),

          // 3. 顶栏返回按钮
          if (showBack)
            Positioned(
              left: _edge(6, leftInset),
              top: _edge(6, topInset),
              child: FocusTap(
                behavior: HitTestBehavior.opaque,
                focusRadius: BorderRadius.circular(18),
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0x33000000),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
