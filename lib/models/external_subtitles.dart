/// One external subtitle track returned by Scraper API, OpenSubtitles,
/// or SubSource. [source] records which catalogue supplied the result so
/// failures can be diagnosed without mixing subtitle origins.
class ExternalSubtitle {
  final String id;
  final String url;
  final String flagUrl;
  final String format;
  final String encoding;
  final String display;
  final String language;
  final String media;
  final bool isHearingImpaired;

  /// Release the track was timed against, or empty when unknown.
  final String release;

  /// Search provider that supplied this track (OpenSubtitles, SubSource, or
  /// the configured RAVEN23 scraper). Kept visible so users can identify
  /// the origin and report a failing host accurately.
  final String source;

  /// Provider quality metadata retained for the evidence-based selector.
  final String? productionType;
  final String? translationType;
  /// True when the provider lookup was scoped to this exact media identity.
  /// Null means the provider did not expose enough evidence to assert it.
  final bool? isExactIdentity;
  final String? releaseType;
  final int? downloadCount;
  final int? newDownloadCount;
  final int? ratingGood;
  final int? ratingBad;
  final double? providerRating;
  final int? providerVotes;
  final double? frameRate;
  final String? uploaderName;
  final String? uploaderRank;
  final bool? isTrustedUploader;
  final bool? foreignParts;
  final String? createdAt;

  ExternalSubtitle({
    required this.id,
    required this.url,
    required this.flagUrl,
    required this.format,
    required this.encoding,
    required this.display,
    required this.language,
    required this.media,
    required this.isHearingImpaired,
    required this.release,
    this.source = 'Scraper API',
    this.productionType,
    this.translationType,
    this.isExactIdentity,
    this.releaseType,
    this.downloadCount,
    this.newDownloadCount,
    this.ratingGood,
    this.ratingBad,
    this.providerRating,
    this.providerVotes,
    this.frameRate,
    this.uploaderName,
    this.uploaderRank,
    this.isTrustedUploader,
    this.foreignParts,
    this.createdAt,
  });

  factory ExternalSubtitle.fromJson(Map<String, dynamic> json) {
    return ExternalSubtitle(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      flagUrl: json['flagUrl']?.toString() ?? '',
      format: json['format']?.toString() ?? 'srt',
      encoding: json['encoding']?.toString() ?? 'UTF-8',
      display: json['display']?.toString() ?? 'Unknown',
      language: json['language']?.toString() ?? 'en',
      media: json['media']?.toString() ?? '',
      isHearingImpaired: json['isHearingImpaired'] == true ||
          json['isHearingImpaired']?.toString() == '1',
      release: json['release']?.toString() ?? '',
      source: json['source']?.toString() ??
          json['provider']?.toString() ?? 'Scraper API',
      productionType: json['productionType']?.toString(),
      translationType: json['translationType']?.toString(),
      isExactIdentity: json['isExactIdentity'] == null
          ? null
          : (json['isExactIdentity'] == true ||
                json['isExactIdentity']?.toString() == '1' ||
                json['isExactIdentity']?.toString().toLowerCase() == 'true'),
      releaseType: json['releaseType']?.toString(),
      downloadCount: int.tryParse(json['downloadCount']?.toString() ?? ''),
      newDownloadCount:
          int.tryParse(json['newDownloadCount']?.toString() ?? ''),
      ratingGood: int.tryParse(json['ratingGood']?.toString() ?? ''),
      ratingBad: int.tryParse(json['ratingBad']?.toString() ?? ''),
      providerRating:
          double.tryParse(json['providerRating']?.toString() ?? ''),
      providerVotes: int.tryParse(json['providerVotes']?.toString() ?? ''),
      frameRate: double.tryParse(json['frameRate']?.toString() ?? ''),
      uploaderName: json['uploaderName']?.toString(),
      uploaderRank: json['uploaderRank']?.toString(),
      isTrustedUploader: json['isTrustedUploader'] == true ||
          json['isTrustedUploader']?.toString() == '1',
      foreignParts: json['foreignParts'] == true ||
          json['foreignParts']?.toString() == '1',
      createdAt: json['createdAt']?.toString(),
    );
  }

  String get displayName {
    String name = display;
    if (isHearingImpaired) {
      name += ' (HI)';
    }
    return '$name - $format';
  }
}

// Keep old models for backward compatibility if still used elsewhere
class SubtitleData {
  SubtitleData({required this.attr});

  SubtitleAttr? attr;

  SubtitleData.fromJson(Map<String, dynamic> json) {
    attr = SubtitleAttr.fromJson(json['attributes']);
  }
}

class SubtitleAttr {
  SubtitleAttr({required this.files});
  List<SubtitleFiles>? files;

  SubtitleAttr.fromJson(Map<String, dynamic> json) {
    if (json['files'] != null) {
      files = [];
      json['files'].forEach((v) {
        files!.add(SubtitleFiles.fromJson(v));
      });
    }
  }
}

class SubtitleFiles {
  SubtitleFiles({required this.fileId});
  int? fileId;

  SubtitleFiles.fromJson(Map<String, dynamic> json) {
    fileId = json['file_id'];
  }
}

class SubtitleDownload {
  SubtitleDownload({required this.link});
  String? link;

  SubtitleDownload.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('link')) {
      link = json['link'];
    }
  }
}
