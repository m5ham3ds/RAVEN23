import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Distinguishes channel-oriented M3U playlists from HLS media playlists.
enum M3uPlaylistKind { channelList, hlsMediaPlaylist, invalid }

class M3uChannelEntry {
  const M3uChannelEntry({
    required this.id,
    required this.name,
    required this.url,
    this.tvgId,
    this.logo,
    this.groupTitle,
    this.headers = const <String, String>{},
  });

  final String id;
  final String name;
  final String url;
  final String? tvgId;
  final String? logo;
  final String? groupTitle;
  final Map<String, String> headers;
}

class M3uParseResult {
  const M3uParseResult({
    required this.kind,
    required this.channels,
    this.error,
    this.epgUrls = const <String>[],
  });

  final M3uPlaylistKind kind;
  final List<M3uChannelEntry> channels;
  final String? error;
  final List<String> epgUrls;

  bool get isChannelList => kind == M3uPlaylistKind.channelList;
}

/// Parses IPTV channel playlists without confusing them with HLS stream files.
///
/// The parser is intentionally strict about stream destinations: only absolute
/// or base-resolved HTTP(S) URLs without embedded credentials are accepted.
/// Header support is restricted to a small browser-compatible allow-list.
class M3uPlaylistParser {
  const M3uPlaylistParser({
    this.maxChannels = 10000,
    this.maxLineLength = 16384,
  });

  final int maxChannels;
  final int maxLineLength;

  static const Map<String, String> _allowedHeaders = <String, String>{
    'http-user-agent': 'User-Agent',
    'user-agent': 'User-Agent',
    'http-referrer': 'Referer',
    'referer': 'Referer',
    'http-origin': 'Origin',
    'origin': 'Origin',
    'http-accept': 'Accept',
    'accept': 'Accept',
  };

  M3uParseResult parse(
    String content, {
    Uri? baseUri,
    String playlistNamespace = 'playlist',
  }) {
    if (utf8.encode(content).length > 4 * 1024 * 1024) {
      return const M3uParseResult(
        kind: M3uPlaylistKind.invalid,
        channels: <M3uChannelEntry>[],
        error: 'M3U playlist exceeds the 4 MiB safety limit.',
      );
    }

    final lines = const LineSplitter().convert(content);
    final first = lines
        .map((line) => line.replaceFirst('\uFEFF', '').trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (!RegExp(r'^#EXTM3U(?:\s|$)', caseSensitive: false).hasMatch(first)) {
      return const M3uParseResult(
        kind: M3uPlaylistKind.invalid,
        channels: <M3uChannelEntry>[],
        error: 'The file does not start with #EXTM3U.',
      );
    }

    // HLS media/master playlists also start with #EXTM3U. They are stream
    // resources, not channel catalogs, and must never become channel rows.
    if (lines.any(
      (line) => line.trimLeft().toUpperCase().startsWith('#EXT-X-'),
    )) {
      return const M3uParseResult(
        kind: M3uPlaylistKind.hlsMediaPlaylist,
        channels: <M3uChannelEntry>[],
        error: 'This is an HLS media playlist, not an IPTV channel list.',
      );
    }

    final epgUrls = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.replaceFirst('\uFEFF', '').trim();
      if (!line.toUpperCase().startsWith('#EXTM3U')) continue;
      final metadata = line.length > 7 ? line.substring(7) : '';
      final attributes = _parseAttributes(metadata);
      for (final key in <String>['url-tvg', 'x-tvg-url', 'tvg-url']) {
        final rawValue = attributes[key];
        if (rawValue == null || rawValue.trim().isEmpty) continue;
        for (final candidate in rawValue.split(RegExp(r'[,;]'))) {
          if (epgUrls.length >= 8) break;
          final uri = _resolveStreamUri(candidate, baseUri);
          if (uri != null && !epgUrls.contains(uri.toString())) {
            epgUrls.add(uri.toString());
          }
        }
      }
      break;
    }

    final channels = <M3uChannelEntry>[];
    final seen = <String>{};
    Map<String, String> attributes = <String, String>{};
    Map<String, String> headers = <String, String>{};
    String? title;
    String? pendingGroup;
    var sawExtInf = false;

    for (final rawLine in lines) {
      if (rawLine.length > maxLineLength) continue;
      final line = rawLine.trim();
      if (line.isEmpty || line.toUpperCase() == '#EXTM3U') continue;

      if (line.toUpperCase().startsWith('#EXTINF:')) {
        final payload = line.substring(line.indexOf(':') + 1);
        final comma = payload.indexOf(',');
        final metadata = comma < 0 ? payload : payload.substring(0, comma);
        final rawTitle = comma < 0 ? '' : payload.substring(comma + 1).trim();
        attributes = _parseAttributes(metadata);
        title =
            _cleanText(rawTitle).ifNotEmpty ??
            _cleanText(attributes['tvg-name'] ?? '').ifNotEmpty;
        pendingGroup = _cleanText(attributes['group-title'] ?? '').ifNotEmpty;
        headers = <String, String>{};
        sawExtInf = true;
        continue;
      }

      if (line.toUpperCase().startsWith('#EXTGRP:')) {
        final value = _cleanText(line.substring(line.indexOf(':') + 1));
        if (value.isNotEmpty) pendingGroup = value;
        continue;
      }

      if (line.toUpperCase().startsWith('#EXTVLCOPT:')) {
        final option = line.substring(line.indexOf(':') + 1);
        final separator = option.indexOf('=');
        if (separator > 0) {
          final key = option.substring(0, separator).trim().toLowerCase();
          final headerName = _allowedHeaders[key];
          final value = _cleanHeaderValue(option.substring(separator + 1));
          if (headerName != null && value != null) {
            headers[headerName] = value;
          }
        }
        continue;
      }

      if (line.startsWith('#')) continue;
      if (!sawExtInf) continue;

      final streamUri = _resolveStreamUri(line, baseUri);
      final channelName =
          _cleanText(title ?? '').ifNotEmpty ??
          _cleanText(attributes['tvg-name'] ?? '').ifNotEmpty ??
          'Channel ${channels.length + 1}';
      if (streamUri != null) {
        final tvgId = _cleanText(attributes['tvg-id'] ?? '').ifNotEmpty;
        final logo = _resolveLogo(attributes['tvg-logo'], baseUri);
        final identity =
            tvgId ??
            <String>[
              channelName.toLowerCase(),
              streamUri.toString(),
              (pendingGroup ?? '').toLowerCase(),
              logo ?? '',
            ].join('|');
        final channelHash = sha256
            .convert(utf8.encode('$playlistNamespace|$identity'))
            .toString()
            .substring(0, 24);
        if (seen.add(channelHash)) {
          channels.add(
            M3uChannelEntry(
              id: channelHash,
              name: channelName,
              url: streamUri.toString(),
              tvgId: tvgId,
              logo: logo,
              groupTitle: pendingGroup,
              headers: Map<String, String>.unmodifiable(headers),
            ),
          );
          if (channels.length >= maxChannels) break;
        }
      }

      attributes = <String, String>{};
      headers = <String, String>{};
      title = null;
      pendingGroup = null;
      sawExtInf = false;
    }

    if (channels.isEmpty) {
      return const M3uParseResult(
        kind: M3uPlaylistKind.invalid,
        channels: <M3uChannelEntry>[],
        error:
            'No valid #EXTINF channel entries with HTTP(S) stream URLs were found.',
      );
    }
    return M3uParseResult(
      kind: M3uPlaylistKind.channelList,
      channels: List<M3uChannelEntry>.unmodifiable(channels),
      epgUrls: List<String>.unmodifiable(epgUrls),
    );
  }

  Map<String, String> _parseAttributes(String value) {
    final result = <String, String>{};
    final pattern = RegExp(
      r'''([A-Za-z0-9_-]+)\s*=\s*(?:"((?:\\.|[^"])*)"|'((?:\\.|[^'])*)'|([^,\s]+))''',
    );
    for (final match in pattern.allMatches(value)) {
      final key = match.group(1)?.trim().toLowerCase() ?? '';
      final raw = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      if (key.isEmpty) continue;
      result[key] = raw
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'")
          .replaceAll(r'\\', String.fromCharCode(92))
          .trim();
    }
    return result;
  }

  Uri? _resolveStreamUri(String value, Uri? baseUri) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    Uri? uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.hasScheme && baseUri != null) {
      uri = baseUri.resolveUri(uri);
    }
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  String? _resolveLogo(String? value, Uri? baseUri) {
    final raw = _cleanText(value ?? '');
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final resolved = !uri.hasScheme && baseUri != null
        ? baseUri.resolveUri(uri)
        : uri;
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    return resolved.toString();
  }

  String? _cleanHeaderValue(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty ||
        cleaned.length > 4096 ||
        cleaned.contains('\r') ||
        cleaned.contains('\n')) {
      return null;
    }
    return cleaned;
  }

  String _cleanText(String value) =>
      value.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim();
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}
