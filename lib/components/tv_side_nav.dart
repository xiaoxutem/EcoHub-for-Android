import 'package:flutter/material.dart';

import '../common/app_theme.dart';
import '../utils/tv_mode.dart';
import 'focus_wrap.dart';

/// TV 端侧边导航栏。
///
/// TV 上底部导航条离用户太远（1080p 屏 + 2~3 米观看距离），
/// 且遥控器需要明确的方向键目标，因此改为左侧竖排导航 —— 这是 Android TV 的标准布局。
class TvSideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool hasAppUpdate;

  const TvSideNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.hasAppUpdate = false,
  });

  static const List<({IconData icon, IconData activeIcon, String label})> _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '推荐'),
    (
      icon: Icons.local_fire_department_outlined,
      activeIcon: Icons.local_fire_department_rounded,
      label: '更新'
    ),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TvMode.scale(96),
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        border: Border(right: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: TvMode.scale(24)),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: TvMode.scale(8)),
                child: _NavItem(
                  icon: _items[i].icon,
                  activeIcon: _items[i].activeIcon,
                  label: _items[i].label,
                  selected: currentIndex == i,
                  badge: i == 2 && hasAppUpdate,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.textMuted;
    return FocusTap(
      onTap: onTap,
      focusRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: TvMode.scale(80),
        padding: EdgeInsets.symmetric(vertical: TvMode.scale(10)),
        margin: EdgeInsets.symmetric(horizontal: TvMode.scale(8)),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, size: TvMode.scale(24), color: color),
                if (badge)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: TvMode.scale(8),
                      height: TvMode.scale(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: TvMode.scale(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: TvMode.font(12),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
