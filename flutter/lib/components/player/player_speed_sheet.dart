import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import 'player_speed.dart';

/// 播放倍速选择底栏弹窗
class PlayerSpeedSheet extends StatelessWidget {
  static const List<double> speeds = PlayerSpeed.rates;
  final double currentSpeed;
  final ValueChanged<double> onSelectSpeed;

  const PlayerSpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelectSpeed,
  });

  static void show(BuildContext context, double currentSpeed, ValueChanged<double> onSelectSpeed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => PlayerSpeedSheet(
        currentSpeed: currentSpeed,
        onSelectSpeed: onSelectSpeed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.size.height > 0 && media.size.height < 500;
    final maxHeight = media.size.height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: landscape ? AppTheme.spaceSm : AppTheme.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: landscape ? 4 : 8),
                child: const Text(
                  '播放倍速',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppTheme.border),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: speeds.map((speed) {
                      final active = (currentSpeed - speed).abs() < 0.01;
                      return ListTile(
                        dense: landscape,
                        visualDensity: landscape ? VisualDensity.compact : VisualDensity.standard,
                        title: Center(
                          child: Text(
                            PlayerSpeed.label(speed),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                              color: active ? AppTheme.accent : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        onTap: () {
                          onSelectSpeed(speed);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
