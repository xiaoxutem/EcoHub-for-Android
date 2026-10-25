/// DLNA / UPnP 设备与投屏数据模型，对齐 OHOS `DlnaTypes.ets`
class DlnaDevice {
  final String usn;
  final String friendlyName;
  final String manufacturer;
  final String location;
  final String controlURL;
  final String renderingControlURL;
  final String host;

  const DlnaDevice({
    required this.usn,
    required this.friendlyName,
    this.manufacturer = '',
    required this.location,
    required this.controlURL,
    this.renderingControlURL = '',
    this.host = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DlnaDevice && runtimeType == other.runtimeType && usn == other.usn;

  @override
  int get hashCode => usn.hashCode;
}

/// 播放进度信息
class DlnaPositionInfo {
  final double positionSec;
  final double durationSec;
  final String relTime;
  final String trackDuration;

  const DlnaPositionInfo({
    this.positionSec = 0,
    this.durationSec = 0,
    this.relTime = '00:00:00',
    this.trackDuration = '00:00:00',
  });
}

enum DlnaScanState { idle, scanning, done, error }

class CastPhase {
  static const String idle = 'idle';
  static const String launching = 'launching';
  static const String playing = 'playing';
  static const String paused = 'paused';
  static const String completed = 'completed';
  static const String failed = 'failed';
  static const String disconnected = 'disconnected';
  static const String stopping = 'stopping';
}

/// SOAP 故障错误
class DlnaSoapError implements Exception {
  final String action;
  final int httpCode;
  final int errorCode;
  final String errorDescription;
  final String message;

  const DlnaSoapError({
    this.action = '',
    this.httpCode = 0,
    this.errorCode = 0,
    this.errorDescription = '',
    this.message = '',
  });

  bool fatalForLaunch() {
    if (action != 'SetAVTransportURI' && action != 'Play') return false;
    final c = errorCode;
    if (c == 714 || c == 716 || c == 401 || c == 402 || c == 701) return true;
    return c == 0 && httpCode >= 400;
  }

  @override
  String toString() =>
      errorDescription.isNotEmpty ? errorDescription : (message.isNotEmpty ? message : '投屏错误');
}

bool isRelTimeUnavailable(String? raw) {
  final t = (raw ?? '').trim().toUpperCase();
  if (t.isEmpty) return true;
  return t.startsWith('NOT_IMPLEMENTED');
}
