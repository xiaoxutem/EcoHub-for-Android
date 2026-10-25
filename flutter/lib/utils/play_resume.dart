import 'history_manager.dart';

/// 从观看历史解析续播位置（片尾 3s 内视为已看完，从头播）
class PlayResume {
  final String sourceId;
  final int episodeIndex;
  final double currentTime;
  final double duration;

  const PlayResume({
    this.sourceId = '',
    this.episodeIndex = 0,
    this.currentTime = 0,
    this.duration = 0,
  });

  static Future<PlayResume> fromHistory(String filmId) async {
    if (filmId.isEmpty) return const PlayResume();
    try {
      final prev = await HistoryManager.find(filmId);
      if (prev == null) return const PlayResume();
      final ended = prev.duration > 0 && prev.currentTime >= prev.duration - 3;
      return PlayResume(
        sourceId: prev.sourceId,
        episodeIndex: prev.episodeIndex,
        currentTime: ended ? 0 : prev.currentTime,
        duration: prev.duration,
      );
    } catch (_) {
      return const PlayResume();
    }
  }
}
