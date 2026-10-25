/// 主站播放 / 现场播放分流
class PlayNavigation {
  static bool isLocalFilmId(String id) {
    final text = id.trim();
    if (text.isEmpty || text.contains(':')) return false;
    final value = int.tryParse(text);
    return value != null && value > 0;
  }

  static String livePlayHistoryId(String sourceId, String sourceMid) {
    final source = sourceId.trim();
    final sid = sourceMid.trim();
    if (source.isEmpty || sid.isEmpty || sid == '0') return '';
    return '$source:$sid';
  }

  static ({String sourceId, String sid})? splitLivePlayId(String id) {
    final text = id.trim();
    final sep = text.lastIndexOf(':');
    if (sep <= 0 || sep == text.length - 1) return null;
    return (sourceId: text.substring(0, sep), sid: text.substring(sep + 1));
  }
}
