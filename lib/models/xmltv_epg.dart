/// Provider-neutral XMLTV guide models.
///
/// All programme timestamps are normalized to UTC. XMLTV timestamps without
/// an explicit UTC offset are interpreted as UTC; callers must not guess a
/// device or station timezone from the machine's current offset.
class XmlTvChannel {
  const XmlTvChannel({required this.id, this.displayName, this.icon});

  final String id;
  final String? displayName;
  final String? icon;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (displayName != null) 'displayName': displayName,
    if (icon != null) 'icon': icon,
  };

  factory XmlTvChannel.fromJson(Map<String, dynamic> json) => XmlTvChannel(
    id: json['id']?.toString() ?? '',
    displayName: json['displayName']?.toString(),
    icon: json['icon']?.toString(),
  );
}

class XmlTvProgramme {
  const XmlTvProgramme({
    required this.channelId,
    required this.startUtc,
    required this.stopUtc,
    required this.title,
    this.subtitle,
    this.description,
    this.categories = const <String>[],
    this.language,
    this.episodeNumber,
    this.icon,
  });

  final String channelId;
  final DateTime startUtc;
  final DateTime stopUtc;
  final String title;
  final String? subtitle;
  final String? description;
  final List<String> categories;
  final String? language;
  final String? episodeNumber;
  final String? icon;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'channelId': channelId,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'stopUtc': stopUtc.toUtc().toIso8601String(),
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (description != null) 'description': description,
    'categories': categories,
    if (language != null) 'language': language,
    if (episodeNumber != null) 'episodeNumber': episodeNumber,
    if (icon != null) 'icon': icon,
  };

  factory XmlTvProgramme.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startUtc']?.toString() ?? '');
    final stop = DateTime.tryParse(json['stopUtc']?.toString() ?? '');
    if (start == null || stop == null || !stop.isAfter(start)) {
      throw const FormatException('Cached XMLTV programme has invalid times.');
    }
    return XmlTvProgramme(
      channelId: json['channelId']?.toString() ?? '',
      startUtc: start.toUtc(),
      stopUtc: stop.toUtc(),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      language: json['language']?.toString(),
      episodeNumber: json['episodeNumber']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}

class XmlTvNowNext {
  const XmlTvNowNext({this.now, this.next});

  final XmlTvProgramme? now;
  final XmlTvProgramme? next;
}

class XmlTvGuide {
  XmlTvGuide({
    required List<XmlTvChannel> channels,
    required List<XmlTvProgramme> programmes,
    DateTime? parsedAt,
  }) : channels = List<XmlTvChannel>.unmodifiable(channels),
       programmes = List<XmlTvProgramme>.unmodifiable(
         programmes.toList()..sort((a, b) {
           final channelOrder = a.channelId.compareTo(b.channelId);
           return channelOrder != 0
               ? channelOrder
               : a.startUtc.compareTo(b.startUtc);
         }),
       ),
       parsedAt = (parsedAt ?? DateTime.now()).toUtc();

  final List<XmlTvChannel> channels;
  final List<XmlTvProgramme> programmes;
  final DateTime parsedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'channels': channels.map((item) => item.toJson()).toList(),
    'programmes': programmes.map((item) => item.toJson()).toList(),
    'parsedAt': parsedAt.toIso8601String(),
  };

  factory XmlTvGuide.fromJson(Map<String, dynamic> json) {
    final channels = (json['channels'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => XmlTvChannel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final programmes =
        (json['programmes'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  XmlTvProgramme.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
    return XmlTvGuide(
      channels: channels,
      programmes: programmes,
      parsedAt: DateTime.tryParse(json['parsedAt']?.toString() ?? ''),
    );
  }

  /// Computes Now/Next from UTC intervals, not document ordering. When
  /// programmes overlap, the most recently started active programme wins.
  XmlTvNowNext nowNext(String channelId, {DateTime? at}) {
    final instant = (at ?? DateTime.now()).toUtc();
    XmlTvProgramme? now;
    XmlTvProgramme? next;
    for (final programme in programmes) {
      if (programme.channelId != channelId) continue;
      if (!programme.startUtc.isAfter(instant) &&
          programme.stopUtc.isAfter(instant)) {
        if (now == null || programme.startUtc.isAfter(now.startUtc)) {
          now = programme;
        }
      } else if (programme.startUtc.isAfter(instant) &&
          (next == null || programme.startUtc.isBefore(next.startUtc))) {
        next = programme;
      }
    }
    return XmlTvNowNext(now: now, next: next);
  }
}

class XmlTvLoadResult {
  const XmlTvLoadResult({
    required this.guide,
    required this.fetchedAt,
    required this.sourceUri,
    this.isStale = false,
  });

  final XmlTvGuide guide;
  final DateTime fetchedAt;
  final Uri sourceUri;
  final bool isStale;
}
