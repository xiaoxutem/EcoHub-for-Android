import 'dart:async';
import '../types/dlna_types.dart';
import 'dlna_client.dart';

/// 投屏会话管理：设备状态、轮询同步、播放控制
/// 对齐 OHOS `CastSession.ets` + `CastSessionPoll.ets`
class CastSession {
  static const int slowMs = 35000;
  static const int fastMs = 20000;
  static const int hudPollMs = 1000;
  static const int bgPollMs = 2000;
  static const int failThreshold = 3;
  static const int eosStopTicks = 2;

  final DlnaClient client = DlnaClient();
  DlnaDevice? device;
  double positionSec = 0;
  double durationSec = 0;
  int volume = 50;
  bool volumeSupported = false;
  String transportState = '';
  String phase = CastPhase.idle;
  double pendingStartSec = -1;
  bool relTimeUnavailable = false;
  bool needRelTimeToast = false;
  int startSeekTries = 0;
  bool startSeeking = false;
  int originMs = 0;
  int relNiStreak = 0;
  int stoppedStreak = 0;

  void Function(double positionSec)? onFailed;
  void Function()? onCompleted;
  void Function(double positionSec)? onDisconnected;
  void Function()? onState;

  int _pollToken = 0;
  bool _pollBusy = false;
  bool _terminal = false;
  int _failStreak = 0;
  int _launchAtMs = 0;
  int _timeoutMs = fastMs;
  int _eosStopStreak = 0;
  Timer? _pollTimer;
  bool _hudPolling = false;

  bool get active => device != null;
  String get usn => device?.usn ?? '';
  String get deviceName => device?.friendlyName ?? '';

  void attach(DlnaDevice dev) {
    device = dev;
    transportState = '';
    relTimeUnavailable = false;
    needRelTimeToast = false;
    relNiStreak = 0;
    stoppedStreak = 0;
    originMs = 0;
    startSeekTries = 0;
    startSeeking = false;
    _failStreak = 0;
    _eosStopStreak = 0;
    final isSlow = ['macast', 'kodi', 'mpv', 'xbmc']
        .any((s) => dev.friendlyName.toLowerCase().contains(s));
    _timeoutMs = isSlow ? slowMs : fastMs;
  }

  void beginLaunch(double startPosition, double startDuration) {
    if (startPosition >= 0) positionSec = startPosition;
    if (startDuration > 0) durationSec = startDuration;
    pendingStartSec = startPosition >= 2 ? startPosition : -1;
    startSeekTries = 0;
    startSeeking = false;
    originMs = 0;
    _terminal = false;
    _launchAtMs = DateTime.now().millisecondsSinceEpoch;
    setPhase(CastPhase.launching);
    _startPoll(_pollInterval());
    emitState();
  }

  void clearLocal() {
    _stopPoll();
    device = null;
    positionSec = 0;
    durationSec = 0;
    volume = 50;
    volumeSupported = false;
    transportState = '';
    pendingStartSec = -1;
    relTimeUnavailable = false;
    needRelTimeToast = false;
    originMs = 0;
    stoppedStreak = 0;
    relNiStreak = 0;
    startSeekTries = 0;
    startSeeking = false;
    _terminal = false;
    _failStreak = 0;
    _eosStopStreak = 0;
    setPhase(CastPhase.idle);
  }

  void setHudPolling(bool on) {
    _hudPolling = on;
    if (device != null) {
      _startPoll(_pollInterval());
    }
  }

  int _pollInterval() => _hudPolling ? hudPollMs : bgPollMs;

  void _startPoll(int intervalMs) {
    _stopPoll();
    if (device == null || device!.controlURL.isEmpty) return;
    _pollToken++;
    final token = _pollToken;
    _tickOnce(token);
    _pollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _tickOnce(token);
    });
  }

  void _stopPoll() {
    _pollToken++;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshVolume() async {
    final dev = device;
    if (dev == null || dev.renderingControlURL.isEmpty) {
      volumeSupported = false;
      return;
    }
    try {
      volume = await client.getVolume(dev);
      volumeSupported = true;
    } catch (_) {
      volumeSupported = false;
    }
  }

  Future<void> setVolume(int pct) async {
    final dev = device;
    if (dev == null || dev.renderingControlURL.isEmpty) return;
    await client.setVolume(dev, pct);
    volume = pct;
  }

  Future<void> play() async {
    final dev = device;
    if (dev == null) return;
    await client.play(dev);
    transportState = 'PLAYING';
    originMs = DateTime.now().millisecondsSinceEpoch - (positionSec > 0 ? (positionSec * 1000).round() : 0);
    setPhase(CastPhase.playing);
    emitState();
  }

  Future<void> pause() async {
    final dev = device;
    if (dev == null) return;
    await client.pause(dev);
    transportState = 'PAUSED_PLAYBACK';
    originMs = 0;
    setPhase(CastPhase.paused);
    emitState();
  }

  Future<void> seek(double sec) async {
    final dev = device;
    if (dev == null) return;
    final target = durationSec > 0 ? sec.clamp(0.0, durationSec) : sec.clamp(0.0, double.infinity);
    await client.seek(dev, target);
    pendingStartSec = -1;
    positionSec = target;
    originMs = DateTime.now().millisecondsSinceEpoch - (target * 1000).round();
    emitState();
  }

  Future<void> stopRemote() async {
    if (phase == CastPhase.stopping) return;
    setPhase(CastPhase.stopping);
    final dev = device;
    clearLocal();
    if (dev != null) {
      try {
        await client.stop(dev);
      } catch (_) {}
    }
  }

  Future<void> replaceUri(String url, String title, double startSec) async {
    final dev = device;
    if (dev == null || dev.controlURL.isEmpty) throw Exception('投屏设备已断开');
    _stopPoll();
    try {
      await client.stop(dev);
    } catch (_) {}
    positionSec = startSec;
    durationSec = 0;
    pendingStartSec = startSec >= 2 ? startSec : -1;
    relTimeUnavailable = false;
    needRelTimeToast = false;
    relNiStreak = 0;
    originMs = 0;
    startSeekTries = 0;
    startSeeking = false;
    stoppedStreak = 0;
    _terminal = false;
    _failStreak = 0;
    _eosStopStreak = 0;
    transportState = '';
    _launchAtMs = DateTime.now().millisecondsSinceEpoch;
    final isSlow = ['macast', 'kodi', 'mpv', 'xbmc']
        .any((s) => dev.friendlyName.toLowerCase().contains(s));
    _timeoutMs = isSlow ? slowMs : fastMs;
    setPhase(CastPhase.launching);
    emitState();
    await client.cast(dev, url, title: title, startSec: startSec);
    _startPoll(_pollInterval());
  }

  bool confirmed() => phase == CastPhase.playing || phase == CastPhase.paused;

  void setPhase(String next) {
    if (phase == next) return;
    phase = next;
    emitState();
  }

  void emitState() => onState?.call();

  Future<void> _tickOnce(int token) async {
    if (token != _pollToken || _pollBusy || _terminal) return;
    _pollBusy = true;
    try {
      await _pollTickBody(token);
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _pollTickBody(int token) async {
    if (token != _pollToken) return;
    final dev = device;
    if (dev == null || dev.controlURL.isEmpty) return;

    bool positionOk = false;
    bool transportOk = false;

    try {
      final info = await client.getPositionInfo(dev);
      if (token != _pollToken) return;
      positionOk = true;
      _applyPosition(info);
    } catch (_) {}

    try {
      final state = await client.getTransportInfo(dev);
      if (token != _pollToken) return;
      transportOk = true;
      transportState = state;
    } catch (_) {}

    if (token != _pollToken || device == null) return;

    if (positionOk || transportOk) {
      _failStreak = 0;
    } else {
      _failStreak++;
      if (confirmed() && _failStreak >= failThreshold) {
        _disconnectRemote('轮询连续失败');
        return;
      }
    }

    _judgeTick();

    if (device != null && confirmed()) {
      _applyPendingStart(dev);
    }
    emitState();
  }

  void _applyPosition(DlnaPositionInfo info) {
    if (isRelTimeUnavailable(info.relTime)) {
      relNiStreak++;
      if (relNiStreak >= 3 && !relTimeUnavailable) {
        relTimeUnavailable = true;
        needRelTimeToast = true;
      }
    } else {
      relNiStreak = 0;
    }

    if (info.durationSec > 0) {
      durationSec = info.durationSec;
    }

    final upper = transportState.toUpperCase();
    if (pendingStartSec >= 2) {
      if (info.positionSec > 0 && (info.positionSec - pendingStartSec).abs() <= 8) {
        pendingStartSec = -1;
        positionSec = info.positionSec;
        originMs = DateTime.now().millisecondsSinceEpoch - (info.positionSec * 1000).round();
      } else {
        positionSec = pendingStartSec;
      }
      return;
    }

    if (!relTimeUnavailable && info.positionSec > 0) {
      positionSec = info.positionSec;
      originMs = DateTime.now().millisecondsSinceEpoch - (info.positionSec * 1000).round();
      return;
    }

    if (confirmed() && upper == 'PLAYING') {
      if (originMs <= 0) {
        originMs = DateTime.now().millisecondsSinceEpoch - (positionSec > 0 ? (positionSec * 1000).round() : 0);
      }
      double est = (DateTime.now().millisecondsSinceEpoch - originMs) / 1000.0;
      if (durationSec > 1) {
        est = est.clamp(0.0, durationSec);
      }
      positionSec = est.clamp(0.0, double.infinity);
    }
  }

  void _judgeTick() {
    if (_terminal) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ts = transportState.toUpperCase();

    if (ts == 'ERROR') {
      _failLaunch('ERROR');
      return;
    }

    if (phase == CastPhase.launching) {
      final relOk = !relTimeUnavailable && pendingStartSec < 2 && positionSec > 0;
      final playLike = ts == 'PLAYING' || ts == 'PAUSED_PLAYBACK' || ts == 'TRANSITIONING';
      if (playLike || relOk) {
        setPhase(ts == 'PAUSED_PLAYBACK' ? CastPhase.paused : CastPhase.playing);
        stoppedStreak = 0;
        _failStreak = 0;
        _eosStopStreak = 0;
        return;
      }
      if (now - _launchAtMs > _timeoutMs) {
        _failLaunch('投屏响应超时');
        return;
      }
    } else if (confirmed()) {
      if (_isEosCandidate(ts)) {
        _eosStopStreak++;
        stoppedStreak = 0;
        if (_eosStopStreak >= eosStopTicks) {
          _handleEos();
          return;
        }
        return;
      }
      _eosStopStreak = 0;

      if (ts == 'STOPPED' || ts == 'NO_MEDIA_PRESENT') {
        stoppedStreak++;
        if (stoppedStreak >= 3) {
          _disconnectRemote('$ts x$stoppedStreak');
          return;
        }
        return;
      }
      stoppedStreak = 0;

      if (ts == 'PAUSED_PLAYBACK') {
        setPhase(CastPhase.paused);
      } else if (ts == 'PLAYING') {
        setPhase(CastPhase.playing);
      }
    }
  }

  bool _isEosCandidate(String upper) {
    if (!confirmed() || relTimeUnavailable) return false;
    if (durationSec <= 1 || positionSec < durationSec - 3) return false;
    return upper == 'STOPPED' || upper == 'NO_MEDIA_PRESENT';
  }

  void _applyPendingStart(DlnaDevice dev) {
    if (pendingStartSec < 2 || startSeeking || startSeekTries >= 8) {
      return;
    }
    final waited = DateTime.now().millisecondsSinceEpoch - _launchAtMs;
    if (durationSec <= 1 && waited < 2500) {
      return;
    }
    final target = durationSec > 1 ? pendingStartSec.clamp(0.0, durationSec - 1) : pendingStartSec;
    startSeeking = true;
    startSeekTries++;
    client.seek(dev, target).then((_) {
      startSeeking = false;
    }).catchError((_) {
      startSeeking = false;
      if (startSeekTries >= 8) {
        pendingStartSec = -1;
      }
    });
  }

  void _handleEos() {
    _terminal = true;
    _stopPoll();
    setPhase(CastPhase.completed);
    onCompleted?.call();
  }

  void _failLaunch(String reason) {
    _terminal = true;
    _stopPoll();
    final pos = positionSec;
    clearLocal();
    setPhase(CastPhase.failed);
    onFailed?.call(pos);
  }

  void _disconnectRemote(String reason) {
    _terminal = true;
    _stopPoll();
    final pos = positionSec;
    clearLocal();
    setPhase(CastPhase.disconnected);
    onDisconnected?.call(pos);
  }

  void dispose() {
    _stopPoll();
    client.dispose();
  }
}
