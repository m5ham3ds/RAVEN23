import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/functions/offline_download_ids.dart';
import 'package:raven23/models/offline_download.dart';

OfflineDownload _episode({
  required String id,
  required int seriesId,
  required int season,
  required int episode,
  required int createdAt,
  String state = 'completed',
}) =>
    OfflineDownload.fromMap({
      'id': id,
      'mediaType': 'episode',
      'contentId': seriesId,
      'seasonNumber': season,
      'episodeNumber': episode,
      'state': state,
      'progress': state == 'completed' ? 100 : 45,
      'createdAt': createdAt,
    });

void main() {
  test('movie and episode IDs are stable and shared', () {
    expect(movieOfflineDownloadId(42), 'movie_42');
    expect(episodeOfflineDownloadId(7, 2, 5), 'tv_7_s2_e5');
    expect(episodeOfflineDownloadId(7, null, null), 'tv_7_s0_e0');
  });

  test('completed lookup matches the exact episode', () {
    final downloads = <OfflineDownload>[
      _episode(id: 'other-series', seriesId: 8, season: 2, episode: 5, createdAt: 300),
      _episode(id: 'wrong-episode', seriesId: 7, season: 2, episode: 4, createdAt: 400),
      _episode(id: 'target', seriesId: 7, season: 2, episode: 5, createdAt: 100),
      _episode(id: 'still-downloading', seriesId: 7, season: 2, episode: 5, createdAt: 500, state: 'downloading'),
    ];
    expect(
      findCompletedEpisodeDownload(
        downloads,
        seriesId: 7,
        seasonNumber: 2,
        episodeNumber: 5,
      )?.id,
      'target',
    );
  });

  test('offline-only series chooses its newest completed episode', () {
    final downloads = <OfflineDownload>[
      _episode(id: 'older', seriesId: 7, season: 1, episode: 2, createdAt: 100),
      _episode(id: 'newer', seriesId: 7, season: 2, episode: 1, createdAt: 200),
      _episode(id: 'other-series', seriesId: 8, season: 1, episode: 1, createdAt: 300),
    ];
    expect(latestCompletedEpisodeDownload(downloads, seriesId: 7)?.id, 'newer');
  });
}
