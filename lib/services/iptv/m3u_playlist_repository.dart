import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../video_providers/unified/source_host_policy.dart';
import 'm3u_playlist_parser.dart';

class M3uPlaylistDefinition {
  const M3uPlaylistDefinition({
    required this.id,
    required this.name,
    this.url,
    this.localPath,
  });

  final String id;
  final String name;
  final String? url;
  final String? localPath;

  bool get isLocal => localPath != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (url != null) 'url': url,
    if (localPath != null) 'localPath': localPath,
  };

  factory M3uPlaylistDefinition.fromJson(Map<String, dynamic> json) {
    return M3uPlaylistDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'IPTV playlist',
      url: json['url']?.toString(),
      localPath: json['localPath']?.toString(),
    );
  }
}

class M3uPlaylistContent {
  const M3uPlaylistContent({required this.text, this.baseUri});

  final String text;
  final Uri? baseUri;
}

typedef M3uSupportDirectoryProvider = Future<Directory> Function();

/// Persists user-selected IPTV playlists and a bounded, validator-aware cache.
/// Local files are copied into app-private storage; the original device path is
/// never retained or accessed after import.
class M3uPlaylistRepository {
  M3uPlaylistRepository({
    SharedPreferences? preferences,
    http.Client? client,
    SourceHostPolicy hostPolicy = const SourceHostPolicy(),
    M3uSupportDirectoryProvider? directoryProvider,
  }) : _preferences = preferences,
       _client = client ?? http.Client(),
       _hostPolicy = hostPolicy,
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _playlistsKey = 'iptv_m3u_playlists_v1';
  static const int maxPlaylistCount = 8;
  static const int maxPlaylistBytes = 4 * 1024 * 1024;
  static const Duration cacheTtl = Duration(minutes: 20);
  static const Duration staleCacheLimit = Duration(days: 7);
  static const int _maxRedirects = 4;

  final SharedPreferences? _preferences;
  final http.Client _client;
  final SourceHostPolicy _hostPolicy;
  final M3uSupportDirectoryProvider _directoryProvider;
  SharedPreferences? _resolvedPreferences;
  bool _closed = false;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<Directory> _directory() async {
    final root = await _directoryProvider();
    final directory = Directory('${root.path}/iptv_playlists');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<M3uPlaylistDefinition>> playlists() async {
    final raw = (await _prefs).getString(_playlistsKey);
    if (raw == null || raw.isEmpty) return const <M3uPlaylistDefinition>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <M3uPlaylistDefinition>[];
      return decoded
          .whereType<Map>()
          .map(
            (value) => M3uPlaylistDefinition.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .where(
            (item) =>
                item.id.isNotEmpty &&
                (item.url != null || item.localPath != null),
          )
          .take(maxPlaylistCount)
          .toList(growable: false);
    } on FormatException {
      return const <M3uPlaylistDefinition>[];
    }
  }

  Future<void> _savePlaylists(List<M3uPlaylistDefinition> items) async {
    await (await _prefs).setString(
      _playlistsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<M3uPlaylistDefinition> addRemote({
    required String url,
    String? name,
  }) async {
    _ensureOpen();
    final uri = await _hostPolicy.validate(url.trim());
    final normalized = uri.toString();
    final id = sha256
        .convert(utf8.encode('remote|$normalized'))
        .toString()
        .substring(0, 24);
    final items = List<M3uPlaylistDefinition>.of(await playlists());
    final existing = items.indexWhere((item) => item.id == id);
    final definition = M3uPlaylistDefinition(
      id: id,
      name: _safeName(name, _nameFromUrl(uri)),
      url: normalized,
    );
    if (existing >= 0) {
      items[existing] = definition;
    } else {
      if (items.length >= maxPlaylistCount) {
        throw const FormatException(
          'A maximum of 8 IPTV playlists can be added.',
        );
      }
      items.add(definition);
    }
    await _savePlaylists(items);
    return definition;
  }

  Future<M3uPlaylistDefinition> addLocal({
    required String filename,
    required List<int> bytes,
    String? name,
  }) async {
    _ensureOpen();
    if (bytes.isEmpty || bytes.length > maxPlaylistBytes) {
      throw const FormatException(
        'The local playlist must be between 1 byte and 4 MiB.',
      );
    }
    final text = utf8.decode(bytes);
    final parsed = const M3uPlaylistParser().parse(text);
    if (!parsed.isChannelList) {
      throw FormatException(parsed.error ?? 'Invalid IPTV channel playlist.');
    }
    final sanitizedFilename = filename
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'\.+'), '.');
    final safeFilename = sanitizedFilename.substring(
      0,
      sanitizedFilename.length.clamp(0, 80).toInt(),
    );
    final id = sha256
        .convert(utf8.encode('local|$safeFilename|${sha256.convert(bytes)}'))
        .toString()
        .substring(0, 24);
    final directory = await _directory();
    final file = File('${directory.path}/$id.local.m3u');
    await _writeAtomically(file, bytes);

    final items = List<M3uPlaylistDefinition>.of(await playlists());
    final existing = items.indexWhere((item) => item.id == id);
    final definition = M3uPlaylistDefinition(
      id: id,
      name: _safeName(name, _displayName(filename)),
      localPath: file.path,
    );
    if (existing >= 0) {
      items[existing] = definition;
    } else {
      if (items.length >= maxPlaylistCount) {
        await file.delete();
        throw const FormatException(
          'A maximum of 8 IPTV playlists can be added.',
        );
      }
      items.add(definition);
    }
    await _savePlaylists(items);
    return definition;
  }

  Future<void> remove(String playlistId) async {
    final items = List<M3uPlaylistDefinition>.of(await playlists());
    final removed = items.where((item) => item.id == playlistId).toList();
    items.removeWhere((item) => item.id == playlistId);
    await _savePlaylists(items);
    final directory = await _directory();
    for (final suffix in <String>['local.m3u', 'cache.m3u', 'meta.json']) {
      final file = File('${directory.path}/$playlistId.$suffix');
      if (await file.exists()) await file.delete();
    }
    for (final item in removed) {
      final path = item.localPath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<M3uPlaylistContent> loadContent(
    M3uPlaylistDefinition playlist, {
    bool refresh = false,
  }) async {
    _ensureOpen();
    if (playlist.localPath != null) {
      final file = File(playlist.localPath!);
      if (!await file.exists()) {
        throw const FileSystemException('Imported local M3U file is missing.');
      }
      final length = await file.length();
      if (length <= 0 || length > maxPlaylistBytes) {
        throw const FormatException('Local playlist exceeds the size limit.');
      }
      return M3uPlaylistContent(text: await file.readAsString());
    }

    final rawUrl = playlist.url;
    if (rawUrl == null) {
      throw const FormatException('Playlist has no source URL.');
    }
    final directory = await _directory();
    final cacheFile = File('${directory.path}/${playlist.id}.cache.m3u');
    final metaFile = File('${directory.path}/${playlist.id}.meta.json');
    final metadata = await _readMetadata(metaFile);
    final cacheExists = await cacheFile.exists();

    if (cacheExists && !refresh) {
      final updated = DateTime.tryParse(
        metadata['updatedAt']?.toString() ?? '',
      );
      if (updated != null && DateTime.now().difference(updated) < cacheTtl) {
        return M3uPlaylistContent(
          text: await cacheFile.readAsString(),
          baseUri: Uri.tryParse(metadata['finalUrl']?.toString() ?? rawUrl),
        );
      }
    }

    try {
      return await _fetchRemote(
        rawUrl,
        cacheFile: cacheFile,
        metaFile: metaFile,
        metadata: metadata,
        cacheExists: cacheExists,
      );
    } catch (_) {
      if (cacheExists) {
        final updated = DateTime.tryParse(
          metadata['updatedAt']?.toString() ?? '',
        );
        if (updated != null &&
            DateTime.now().difference(updated) <= staleCacheLimit) {
          return M3uPlaylistContent(
            text: await cacheFile.readAsString(),
            baseUri: Uri.tryParse(metadata['finalUrl']?.toString() ?? rawUrl),
          );
        }
      }
      rethrow;
    }
  }

  Future<M3uPlaylistContent> _fetchRemote(
    String rawUrl, {
    required File cacheFile,
    required File metaFile,
    required Map<String, dynamic> metadata,
    required bool cacheExists,
  }) async {
    Uri current = await _hostPolicy.validate(rawUrl);
    final originalHost = current.host.toLowerCase();
    var redirects = 0;
    while (true) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'Accept':
              'application/x-mpegURL, application/vnd.apple.mpegurl, audio/x-mpegurl, text/plain, */*',
          'User-Agent': 'RAVEN23-IPTV/1.0',
        });
      if (current.host.toLowerCase() == originalHost && cacheExists) {
        final etag = metadata['etag']?.toString();
        final modified = metadata['lastModified']?.toString();
        if (etag != null && etag.isNotEmpty) {
          request.headers['If-None-Match'] = etag;
        }
        if (modified != null && modified.isNotEmpty) {
          request.headers['If-Modified-Since'] = modified;
        }
      }

      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (<int>[301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null ||
            location.isEmpty ||
            redirects >= _maxRedirects) {
          throw const FormatException('Playlist redirect chain is invalid.');
        }
        current = await _hostPolicy.validate(
          current.resolve(location).toString(),
        );
        redirects++;
        continue;
      }

      if (response.statusCode == 304 && cacheExists) {
        await response.stream.drain<void>();
        final updated = <String, dynamic>{
          ...metadata,
          'updatedAt': DateTime.now().toIso8601String(),
          'finalUrl': current.toString(),
        };
        await _writeAtomically(metaFile, utf8.encode(jsonEncode(updated)));
        return M3uPlaylistContent(
          text: await cacheFile.readAsString(),
          baseUri: current,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('Playlist server returned ${response.statusCode}.');
      }
      if (response.contentLength != null &&
          response.contentLength! > maxPlaylistBytes) {
        await response.stream.drain<void>();
        throw const FormatException('Remote playlist exceeds the 4 MiB limit.');
      }

      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        received += chunk.length;
        if (received > maxPlaylistBytes) {
          throw const FormatException(
            'Remote playlist exceeds the 4 MiB limit.',
          );
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      final text = utf8.decode(bytes);
      final parsed = const M3uPlaylistParser().parse(text, baseUri: current);
      if (!parsed.isChannelList) {
        throw FormatException(parsed.error ?? 'Invalid IPTV channel playlist.');
      }
      await _writeAtomically(cacheFile, bytes);
      final updated = <String, dynamic>{
        'etag': response.headers['etag'],
        'lastModified': response.headers['last-modified'],
        'updatedAt': DateTime.now().toIso8601String(),
        'finalUrl': current.toString(),
      };
      await _writeAtomically(metaFile, utf8.encode(jsonEncode(updated)));
      return M3uPlaylistContent(text: text, baseUri: current);
    }
  }

  Future<Map<String, dynamic>> _readMetadata(File file) async {
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeAtomically(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  String _safeName(String? supplied, String fallback) {
    final value = (supplied ?? '')
        .replaceAll(RegExp(r'[\u0000-\u001F]'), '')
        .trim();
    final safeValue = value.isEmpty ? fallback : value;
    return safeValue.substring(0, safeValue.length.clamp(0, 80).toInt());
  }

  String _nameFromUrl(Uri uri) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return _displayName(segment).ifNotEmpty ?? 'IPTV playlist';
  }

  String _displayName(String value) {
    final basename = value.split(RegExp(r'[/\\]')).last;
    return basename
        .replaceAll(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '')
        .trim();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('M3U playlist repository is closed.');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}
