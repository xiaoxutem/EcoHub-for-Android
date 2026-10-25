import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/utils/play_navigation.dart';

void main() {
  test('isLocalFilmId only accepts positive mid', () {
    expect(PlayNavigation.isLocalFilmId('12'), isTrue);
    expect(PlayNavigation.isLocalFilmId('0'), isFalse);
    expect(PlayNavigation.isLocalFilmId(''), isFalse);
    expect(PlayNavigation.isLocalFilmId('src:99'), isFalse);
  });

  test('livePlayHistoryId and splitLivePlayId round-trip', () {
    expect(PlayNavigation.livePlayHistoryId('src', '99'), 'src:99');
    expect(PlayNavigation.livePlayHistoryId('src', '0'), '');
    final split = PlayNavigation.splitLivePlayId('src:99');
    expect(split?.sourceId, 'src');
    expect(split?.sid, '99');
    expect(PlayNavigation.splitLivePlayId('12'), isNull);
  });
}
