import '../models/offline_download.dart';

String movieOfflineDownloadId(int movieId) => 'movie_$movieId';

String episodeOfflineDownloadId(
  int seriesId,
  int? seasonNumber,
  int? episodeNumber,
) =>
    'tv_${seriesId}_s${seasonNumber ?? 0}_e${episodeNumber ?? 0}';

OfflineDownload? findCompletedOfflineDownload(
  Iterable<OfflineDownload> downloads,
  String id,
) {
  for (final item in downloads) {
    if (item.id == id && item.isComplete) return item;
  }
  return null;
}

OfflineDownload? findCompletedEpisodeDownload(
  Iterable<OfflineDownload> downloads, {
  required int seriesId,
  required int seasonNumber,
  required int episodeNumber,
}) {
  for (final item in downloads) {
    if (item.isComplete &&
        item.mediaType == 'episode' &&
        item.contentId == seriesId &&
        item.seasonNumber == seasonNumber &&
        item.episodeNumber == episodeNumber) {
      return item;
    }
  }
  return null;
}

OfflineDownload? latestCompletedEpisodeDownload(
  Iterable<OfflineDownload> downloads, {
  required int seriesId,
}) {
  final matches = downloads.where(
    (item) =>
        item.isComplete &&
        item.mediaType == 'episode' &&
        item.contentId == seriesId,
  ).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return matches.isEmpty ? null : matches.first;
}
