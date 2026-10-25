import 'dart:ui';
import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import '../../types/dlna_types.dart';
import '../../utils/format_util.dart';
import '../../services/cast_session.dart';

/// 投屏中覆盖层 HUD，对齐 OHOS `PlayerCastHud.ets`
class PlayerCastHud extends StatefulWidget {
  final String deviceName;
  final double positionSec;
  final double durationSec;
  final String phase;
  final String transportState;
  final CastSession? castSession;
  final VoidCallback? onStopCast;

  const PlayerCastHud({
    super.key,
    required this.deviceName,
    required this.positionSec,
    required this.durationSec,
    required this.phase,
    required this.transportState,
    this.castSession,
    this.onStopCast,
  });

  @override
  State<PlayerCastHud> createState() => _PlayerCastHudState();
}

class _PlayerCastHudState extends State<PlayerCastHud> {
  double _scrubPos = 0;
  bool _scrubbing = false;
  bool _transportBusy = false;

  @override
  void initState() {
    super.initState();
    _scrubPos = widget.positionSec;
    widget.castSession?.setHudPolling(true);
  }

  @override
  void didUpdateWidget(covariant PlayerCastHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scrubbing) {
      _scrubPos = widget.positionSec;
    }
  }

  @override
  void dispose() {
    widget.castSession?.setHudPolling(false);
    super.dispose();
  }

  double get _displayPos => _scrubbing ? _scrubPos : widget.positionSec;

  String _stateLabel() {
    final s = widget.transportState.toUpperCase();
    if (s == 'TRANSITIONING' &&
        (widget.phase == CastPhase.launching || widget.phase == CastPhase.playing)) {
      return '缓冲中';
    }
    if (widget.phase == CastPhase.launching) return '正在连接…';
    if (widget.phase == CastPhase.playing) return '播放中';
    if (widget.phase == CastPhase.paused) return '已暂停';
    return '正在投屏';
  }

  bool get _isPaused =>
      widget.phase == CastPhase.paused || widget.transportState.toUpperCase() == 'PAUSED_PLAYBACK';

  bool get _canToggle =>
      !_transportBusy && (widget.phase == CastPhase.playing || widget.phase == CastPhase.paused);

  Future<void> _togglePause() async {
    final s = widget.castSession;
    if (!_canToggle || s == null) return;
    final pause = !_isPaused;
    setState(() => _transportBusy = true);
    try {
      if (pause) {
        await s.pause();
      } else {
        await s.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pause ? '设备不支持暂停' : '设备不支持继续播放')),
        );
      }
    } finally {
      if (mounted) setState(() => _transportBusy = false);
    }
  }

  Future<void> _seekTo(double sec) async {
    final s = widget.castSession;
    if (s == null) return;
    final maxD = widget.durationSec > 0 ? widget.durationSec : sec;
    final target = sec.clamp(0.0, maxD);
    try {
      await s.seek(target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备不支持进度拖动')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxDur = widget.durationSec > 0 ? widget.durationSec : 1.0;
    final curPos = _displayPos.clamp(0.0, maxDur);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '投屏至 ${widget.deviceName.isNotEmpty ? widget.deviceName : "电视"}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _stateLabel(),
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    FormatUtil.duration(_displayPos),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: AppTheme.accent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: curPos,
                        min: 0,
                        max: maxDur,
                        onChanged: (v) {
                          setState(() {
                            _scrubbing = true;
                            _scrubPos = v;
                          });
                        },
                        onChangeEnd: (v) {
                          setState(() => _scrubbing = false);
                          _seekTo(v);
                        },
                      ),
                    ),
                  ),
                  Text(
                    FormatUtil.duration(widget.durationSec),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 26,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _canToggle ? _togglePause : null,
                  ),
                  if (widget.onStopCast != null) ...[
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 22,
                      icon: const Icon(Icons.power_settings_new_rounded, color: AppTheme.danger),
                      tooltip: '退出投屏',
                      onPressed: widget.onStopCast,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
