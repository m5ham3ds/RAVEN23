import '../video_providers/common.dart';
import '../video_providers/names.dart';

/// The original API source, independent of its short-lived signed URL.
class OfflineDownloadSource {
  const OfflineDownloadSource({
    required this.apiBaseUrl,
    required this.providerId,
    required this.providerName,
    required this.server,
    required this.quality,
    this.resolverType = 'scraperApi',
  });

  final String apiBaseUrl;
  final String providerId;
  final String providerName;
  final String? server;
  final String quality;
  final String resolverType;

  static OfflineDownloadSource? forSelection({
    required VideoProvider? provider,
    required String apiBaseUrl,
    required Iterable<RegularVideoLinks> links,
    required String url,
  }) {
    final matches = links.where((link) => link.url == url).toList();
    if (matches.length != 1) return null;
    final link = matches.single;

    // VixSrc signs its own HLS playlist through an embed page, not the
    // Scraper API. Preserve the title identity for a source-specific renewal.
    if (provider?.type == VideoProviderType.directVixSrc &&
        provider?.apiId == 'vixsrc') {
      return OfflineDownloadSource(
        apiBaseUrl: 'https://vixsrc.to',
        providerId: 'vixsrc',
        providerName: provider!.displayName,
        server: link.server ?? provider.displayName,
        quality: link.quality ?? 'auto',
        resolverType: 'vixsrc',
      );
    }

    if (provider?.type != VideoProviderType.scraperApi ||
        provider?.apiId?.isNotEmpty != true ||
        apiBaseUrl.trim().isEmpty) {
      return null;
    }
    // Save the API quality and server, never a duplicate display label.
    return OfflineDownloadSource(
      apiBaseUrl: apiBaseUrl,
      providerId: provider!.apiId!,
      providerName: provider.displayName,
      server: link.server,
      quality: link.quality ?? 'unknown quality',
    );
  }

  Map<String, Object?> toMap() => {
        'version': 1,
        'apiBaseUrl': apiBaseUrl,
        'providerId': providerId,
        'providerName': providerName,
        'server': server ?? '',
        'quality': quality,
        'resolverType': resolverType,
      };
}

enum OfflineDownloadState {
  queued,
  stopped,
  downloading,
  completed,
  failed,
  removing,
  restarting,
  unknown;

  static OfflineDownloadState fromName(String? value) {
    return OfflineDownloadState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => OfflineDownloadState.unknown,
    );
  }
}

class OfflineDownload {
  const OfflineDownload({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.quality,
    required this.state,
    required this.progress,
    required this.bytesDownloaded,
    required this.contentLength,
    required this.createdAt,
    this.networkRateBytesPerSecond = 0,
    this.subtitle,
    this.posterUrl,
    this.error,
    this.contentId,
    this.seasonNumber,
    this.episodeNumber,
    this.offlineSubtitlePath,
    this.offlineSubtitleName,
    this.audioTrackName,
    this.expectedDurationMs,
    this.estimatedDownloadBytes,
    this.streamIdentity = const <String, Object?>{},
  });

  final String id;
  final String title;
  final String? subtitle;
  final String mediaType;
  final String quality;
  final OfflineDownloadState state;
  final double progress;
  final int bytesDownloaded;
  final int contentLength;
  final DateTime createdAt;
  final double networkRateBytesPerSecond;
  final String? posterUrl;
  final String? error;
  final int? contentId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? offlineSubtitlePath;
  final String? offlineSubtitleName;
  final String? audioTrackName;
  /// Expected media duration, in milliseconds, used to reject truncated exports.
  final int? expectedDurationMs;
  /// Signed backend estimate for the selected download quality, in bytes.
  final int? estimatedDownloadBytes;
  final Map<String, Object?> streamIdentity;

  bool get isComplete => state == OfflineDownloadState.completed;
  bool get isActive =>
      state == OfflineDownloadState.downloading ||
      state == OfflineDownloadState.queued ||
      state == OfflineDownloadState.restarting;

  bool get totalBytesIsEstimated => contentLength <= 0 && !isComplete;

  int get totalBytes {
    if (contentLength > 0) return contentLength;
    if (isComplete) return bytesDownloaded;
    if (bytesDownloaded > 0 && progress > 0) {
      return (bytesDownloaded * 100 / progress).round();
    }
    return -1;
  }

  OfflineDownload copyWith({double? networkRateBytesPerSecond}) {
    return OfflineDownload(
      id: id,
      title: title,
      mediaType: mediaType,
      quality: quality,
      state: state,
      progress: progress,
      bytesDownloaded: bytesDownloaded,
      contentLength: contentLength,
      createdAt: createdAt,
      networkRateBytesPerSecond:
          networkRateBytesPerSecond ?? this.networkRateBytesPerSecond,
      subtitle: subtitle,
      posterUrl: posterUrl,
      error: error,
      contentId: contentId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      offlineSubtitlePath: offlineSubtitlePath,
      offlineSubtitleName: offlineSubtitleName,
      audioTrackName: audioTrackName,
      expectedDurationMs: expectedDurationMs,
      estimatedDownloadBytes: estimatedDownloadBytes,
      streamIdentity: streamIdentity,
    );
  }

  factory OfflineDownload.fromMap(Map<Object?, Object?> map) {
    T? value<T>(String key) {
      final raw = map[key];
      return raw is T ? raw : null;
    }

    final rawProgress = value<num>('progress')?.toDouble() ?? 0;
    final rawIdentity = value<Map>('streamIdentity');
    final streamIdentity = rawIdentity == null
        ? const <String, Object?>{}
        : <String, Object?>{
            for (final entry in rawIdentity.entries)
              entry.key.toString(): entry.value,
          };
    return OfflineDownload(
      id: value<String>('id') ?? '',
      title: value<String>('title') ?? 'Untitled',
      subtitle: value<String>('subtitle'),
      mediaType: value<String>('mediaType') ?? 'video',
      quality: value<String>('quality') ?? 'Auto',
      state: OfflineDownloadState.fromName(value<String>('state')),
      progress: rawProgress.isFinite ? rawProgress.clamp(0, 100) : 0,
      bytesDownloaded: value<num>('bytesDownloaded')?.toInt() ?? 0,
      contentLength: value<num>('contentLength')?.toInt() ?? -1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        value<num>('createdAt')?.toInt() ?? 0,
      ),
      networkRateBytesPerSecond:
          value<num>('networkRateBytesPerSecond')?.toDouble() ?? 0,
      posterUrl: value<String>('posterUrl'),
      error: value<String>('error'),
      contentId: value<num>('contentId')?.toInt(),
      seasonNumber: value<num>('seasonNumber')?.toInt(),
      episodeNumber: value<num>('episodeNumber')?.toInt(),
      offlineSubtitlePath: value<String>('offlineSubtitlePath'),
      offlineSubtitleName: value<String>('offlineSubtitleName'),
      audioTrackName: value<String>('audioTrackName'),
      expectedDurationMs: value<num>('expectedDurationMs')?.toInt(),
      estimatedDownloadBytes: value<num>('estimatedDownloadBytes')?.toInt(),
      streamIdentity: streamIdentity,
    );
  }
}

/// A native stream track, including its identity for an exact download override.
class OfflineAudioTrack {
  const OfflineAudioTrack({required this.name, required this.selection});

  final String name;
  final Map<String, Object?> selection;

  factory OfflineAudioTrack.fromMap(Map<Object?, Object?> map) =>
      OfflineAudioTrack(
        name: map['name'] as String? ?? 'Audio',
        selection: Map<String, Object?>.from(map['selection'] as Map),
      );
}

class OfflineDownloadRequest {
  const OfflineDownloadRequest({
    required this.id,
    required this.url,
    required this.format,
    required this.title,
    required this.mediaType,
    required this.quality,
    this.subtitle,
    this.posterUrl,
    this.maxVideoHeight,
    this.headers = const {},
    this.contentId,
    this.seasonNumber,
    this.episodeNumber,
    this.subtitleTrackUrl,
    this.subtitleTrackName,
    this.subtitleTrackHeaders = const {},
    this.audioTrack,
    this.audioLanguages = const <String>['en'],
    this.expectedDurationMs,
    this.estimatedDownloadBytes,
    this.subtitleTrackContent,
    this.source,
    this.exportTitle,
    this.streamIdentity = const <String, Object?>{},
  });

  final String id;
  final String url;
  final String format;
  final String title;
  final String? subtitle;
  final String mediaType;
  final String quality;
  final String? posterUrl;
  final int? maxVideoHeight;
  final Map<String, String> headers;
  final int? contentId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? subtitleTrackUrl;
  final String? subtitleTrackName;
  final Map<String, String> subtitleTrackHeaders;
  final OfflineAudioTrack? audioTrack;
  /// Language priority for automatic track selection (Japanese then English for anime).
  final List<String> audioLanguages;
  final int? expectedDurationMs;
  /// Signed backend estimate for the selected download quality, in bytes.
  final int? estimatedDownloadBytes;
  /// A normalized WebVTT subtitle selected from an external subtitle catalogue.
  final String? subtitleTrackContent;
  final OfflineDownloadSource? source;
  /// File name stem used when exporting this movie or episode to Documents/RAVEN23.
  final String? exportTitle;
  /// Stable provenance for the exact selected stream; this is metadata only
  /// and is not used as an automatic URL-renewal resolver.
  final Map<String, Object?> streamIdentity;

  Map<String, Object?> toMap() => {
        'id': id,
        'url': url,
        'format': format,
        'title': title,
        'subtitle': subtitle,
        'mediaType': mediaType,
        'quality': quality,
        'posterUrl': posterUrl,
        'maxVideoHeight': maxVideoHeight,
        'headers': headers,
        'audioTrack': audioTrack?.selection,
        'audioTrackName': audioTrack?.name,
        'audioLanguages': audioLanguages,
        'expectedDurationMs': expectedDurationMs,
        'estimatedDownloadBytes': estimatedDownloadBytes,
        'subtitleTrackContent': subtitleTrackContent,
        'source': source?.toMap(),
        'streamIdentity': streamIdentity,
        'contentId': contentId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'subtitleTrackUrl': subtitleTrackUrl,
        'subtitleTrackName': subtitleTrackName,
        'subtitleTrackHeaders': subtitleTrackHeaders,
        'exportTitle': exportTitle,
      };
}
