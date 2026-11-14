import 'dart:convert';

import 'package:xml/xml.dart' as xml;

import '../../models/xmltv_epg.dart';

class XmlTvParseException implements Exception {
  const XmlTvParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bounded XMLTV parser. It never resolves DTDs or external entities.
class XmlTvEpgParser {
  const XmlTvEpgParser({
    this.maxBytes = 8 * 1024 * 1024,
    this.maxChannels = 10000,
    this.maxProgrammes = 100000,
    this.maxTextLength = 8192,
  });

  final int maxBytes;
  final int maxChannels;
  final int maxProgrammes;
  final int maxTextLength;

  XmlTvGuide parse(String source) {
    source = source.replaceFirst('\uFEFF', '');
    if (source.isEmpty || utf8.encode(source).length > maxBytes) {
      throw const XmlTvParseException('XMLTV feed is empty or exceeds 8 MiB.');
    }
    if (RegExp(r'<!ENTITY\b', caseSensitive: false).hasMatch(source)) {
      throw const XmlTvParseException(
        'XMLTV entity declarations are not allowed.',
      );
    }
    if (RegExp(r'<!DOCTYPE[^>]*\[', caseSensitive: false).hasMatch(source)) {
      throw const XmlTvParseException(
        'XMLTV internal DTD subsets are not allowed.',
      );
    }

    // XMLTV feeds commonly declare the public xmltv.dtd. Strip the declaration
    // so the parser cannot attempt external DTD/entity resolution.
    final safeSource = source.replaceAll(
      RegExp(r'<!DOCTYPE\s+[^>]*>', caseSensitive: false),
      '',
    );

    final xml.XmlDocument document;
    try {
      document = xml.XmlDocument.parse(safeSource);
    } on Object {
      throw const XmlTvParseException('XMLTV feed is not valid XML.');
    }
    final root = document.rootElement;
    if (root.name.local.toLowerCase() != 'tv') {
      throw const XmlTvParseException('XMLTV document root must be <tv>.');
    }

    final channelElements = _children(root, 'channel').toList(growable: false);
    final programmeElements = _children(
      root,
      'programme',
    ).toList(growable: false);
    if (channelElements.length > maxChannels) {
      throw const XmlTvParseException('XMLTV feed contains too many channels.');
    }
    if (programmeElements.length > maxProgrammes) {
      throw const XmlTvParseException(
        'XMLTV feed contains too many programmes.',
      );
    }

    final channels = <XmlTvChannel>[];
    final channelIds = <String>{};
    for (final element in channelElements) {
      final id = _attribute(element, 'id');
      if (id.isEmpty || !channelIds.add(id)) continue;
      final displayNames = _children(element, 'display-name')
          .map((item) => _boundedText(item.innerText))
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final iconElement = _children(element, 'icon').firstOrNull;
      final icon = _safeIcon(_attribute(iconElement, 'src'));
      channels.add(
        XmlTvChannel(id: id, displayName: displayNames.firstOrNull, icon: icon),
      );
    }
    if (channels.isEmpty) {
      throw const XmlTvParseException('XMLTV feed has no valid channels.');
    }

    final programmes = <XmlTvProgramme>[];
    final seen = <String>{};
    for (final element in programmeElements) {
      final channelId = _attribute(element, 'channel');
      if (channelId.isEmpty || !channelIds.contains(channelId)) continue;
      final start = _parseTimestamp(_attribute(element, 'start'));
      final stop = _parseTimestamp(_attribute(element, 'stop'));
      if (start == null || stop == null || !stop.isAfter(start)) continue;

      final titleElement = _children(element, 'title').firstOrNull;
      final title = _boundedText(titleElement?.innerText ?? '');
      if (title.isEmpty) continue;
      final subtitle = _firstText(element, 'sub-title');
      final description = _firstText(element, 'desc');
      final categories = _children(element, 'category')
          .map((item) => _boundedText(item.innerText))
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(12)
          .toList(growable: false);
      final episodeNumber = _firstText(element, 'episode-num');
      final language = _attribute(titleElement, 'lang').ifNotEmpty;
      final iconElement = _children(element, 'icon').firstOrNull;
      final icon = _safeIcon(_attribute(iconElement, 'src'));
      final identity = <String>[
        channelId,
        start.toIso8601String(),
        stop.toIso8601String(),
        title,
      ].join('|');
      if (!seen.add(identity)) continue;
      programmes.add(
        XmlTvProgramme(
          channelId: channelId,
          startUtc: start,
          stopUtc: stop,
          title: title,
          subtitle: subtitle,
          description: description,
          categories: categories,
          language: language,
          episodeNumber: episodeNumber,
          icon: icon,
        ),
      );
    }

    return XmlTvGuide(channels: channels, programmes: programmes);
  }

  Iterable<xml.XmlElement> _children(xml.XmlElement parent, String localName) =>
      parent.childElements.where(
        (element) => element.name.local.toLowerCase() == localName,
      );

  String _attribute(xml.XmlElement? element, String name) =>
      _boundedText(element?.getAttribute(name) ?? '');

  String? _firstText(xml.XmlElement parent, String childName) {
    final child = _children(parent, childName).firstOrNull;
    final text = _boundedText(child?.innerText ?? '');
    return text.ifNotEmpty;
  }

  String _boundedText(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .trim();
    if (cleaned.length <= maxTextLength) return cleaned;
    return cleaned.substring(0, maxTextLength);
  }

  String? _safeIcon(String value) {
    if (value.isEmpty || value.length > 2048) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  DateTime? _parseTimestamp(String value) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*(Z|[+-]\d{4})?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final parts = <int>[
      for (var i = 1; i <= 5; i++) int.parse(match.group(i)!),
      int.parse(match.group(6) ?? '0'),
    ];
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    final hour = parts[3];
    final minute = parts[4];
    final second = parts[5];
    if (year < 1900 ||
        year > 2200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    final wallClock = DateTime.utc(year, month, day, hour, minute, second);
    if (wallClock.year != year ||
        wallClock.month != month ||
        wallClock.day != day) {
      return null;
    }

    final zone = (match.group(7) ?? '').toUpperCase();
    if (zone.isEmpty || zone == 'Z') return wallClock;
    final sign = zone.startsWith('-') ? -1 : 1;
    final offsetHours = int.tryParse(zone.substring(1, 3));
    final offsetMinutes = int.tryParse(zone.substring(3, 5));
    if (offsetHours == null ||
        offsetMinutes == null ||
        offsetHours > 14 ||
        offsetMinutes > 59 ||
        (offsetHours == 14 && offsetMinutes != 0)) {
      return null;
    }
    final offset = Duration(minutes: sign * (offsetHours * 60 + offsetMinutes));
    // +0200 means local clock is two hours ahead of UTC.
    return wallClock.subtract(offset);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

extension _StringIfNotEmpty on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}
