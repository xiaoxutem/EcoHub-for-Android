import 'package:flutter/material.dart';
import '../common/app_theme.dart';

/// 回到顶部浮动按钮
class ScrollFab extends StatelessWidget {
  final bool visible;
  final VoidCallback onClickFab;

  const ScrollFab({
    super.key,
    required this.visible,
    required this.onClickFab,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      offset: visible ? Offset.zero : const Offset(0, 1),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        scale: visible ? 1.0 : 0.72,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: AppTheme.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onClickFab,
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
