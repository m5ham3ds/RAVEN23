import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../controllers/live_tv_database_controller.dart';
import '../../models/live_tv.dart';
import '../../video_providers/unified/quickjs/quickjs_provider_runtime.dart';
import '../../video_providers/unified/quickjs/quickjs_stream_mapper.dart';
import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/source_repository_manager.dart';
import '../../video_providers/unified/stream_option.dart';
import '../daddylive_service.dart';
import 'live_tv_category_mapper.dart';

/// A dedicated Live TV bridge for the curated Spyhell experiment-repository
/// adapters. Scripts are run only when the source is installed and enabled.
/// These providers are never sent through the movie/series resolver.
class SpyhellLiveTvService implements LiveTvService {
  SpyhellLiveTvService({
    SourceRepositoryManager? repositories,
    QuickJsProviderRuntime? runtime,
    LiveTVDatabaseController? database,
  }) : _repositories = repositories ?? SourceRepositoryManager(),
       _runtime = runtime ?? QuickJsProviderRuntime(),
       _database =
           database ?? LiveTVDatabaseController(namespace: databaseNamespace);

  static const String databaseNamespace = 'spyhell_live';
  static const String repositoryMarker = '/spyhell/zangetsu-experiment-repo/';
  static const Set<String> supportedSourceIds = <String>{
    'worldlivetv',
    'livetvindia',
    'sportslivetv',
    'movieslivetv',
    'newslivetv',
    'documentarylivetv',
    'entertainmentlivetv',
    'serieslivetv',
    'animationlivetv',
    'musictv',
    'kidstv',
    'comedytv',
    'travellivetv',
    'cookinglivetv',
    'educationlivetv',
  };

  final SourceRepositoryManager _repositories;
  final QuickJsProviderRuntime _runtime;
  final LiveTVDatabaseController _database;
  bool _closed = false;

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    _ensureOpen();
    final snapshot = await _repositories.sync(forceRefresh: refresh);
    final sources = snapshot.sources.where(_isEligible).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (sources.isEmpty) return _emptyCatalog;

    final channels = <Channel>[];
    final categories = <String>{};
    var successCount = 0;
    Object? lastError;
    for (final source in sources) {
      try {
        final raw = await _runtime.call(source, 'getHome', const <Object?>[
          <String, Object?>{'category': 'sub'},
        ], timeout: const Duration(seconds: 18));
        final rows = _readRows(raw);
        final sourceHash = _fingerprint(source.stableKey).substring(0, 16);
        final seenForSource = <String>{};
        var sourceCount = 0;
        for (final row in rows) {
          final isGroup = row['items'] is List;
          final group = isGroup
              ? _readText(row, const <String>['title', 'name', 'group'])
              : _readText(row, const <String>[
                  'group-title',
                  'group',
                  'category',
                ]);
          final items = isGroup
              ? (row['items'] as List).whereType<Map>().toList()
              : <Map>[row];
          for (final rawItem in items) {
            if (channels.length >= 25000) break;
            final item = Map<String, dynamic>.from(rawItem);
            final title = _readText(item, const <String>[
              'title',
              'name',
              'label',
            ]);
            final locator = _readText(item, const <String>[
              'url',
              'id',
              'link',
            ]);
            if (title.isEmpty || locator.isEmpty) continue;
            final category = mapLiveTvGroup(
              _readText(item, const <String>[
                    'group-title',
                    'group',
                  ]).ifNotEmpty ??
                  group,
            );
            if (category != null) categories.add(category);
            final channelHash = _fingerprint(
              '$locator|${title.toLowerCase()}|${category ?? ''}',
            ).substring(0, 24);
            if (!seenForSource.add(channelHash)) continue;
            channels.add(
              Channel(
                id: 'spyhell:$sourceHash:$channelHash',
                name: title,
                watchUrl: locator,
                playerUrl: locator,
                categories: category == null
                    ? const <String>[]
                    : <String>[category],
                logo: _readText(item, const <String>[
                  'logo',
                  'cover',
                  'poster',
                  'thumbnail',
                ]).ifNotEmpty,
              ),
            );
            sourceCount++;
          }
        }
        if (sourceCount > 0 || rows.isEmpty) successCount++;
      } catch (error) {
        lastError = error;
        // One community provider being offline must not hide the other
        // installed providers from the Live TV catalog.
      }
    }

    if (successCount == 0 && lastError != null) {
      throw const DaddyLiveException(
        'Spyhell Live adapters are temporarily unavailable.',
      );
    }
    return DaddyLiveCatalog(
      channels: List<Channel>.unmodifiable(channels),
      epg: const DaddyLiveEpg(timezone: 'UTC', days: <DaddyLiveEpgDay>[]),
      categories: categories.toList()..sort(),
    );
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    _ensureOpen();
    final match = RegExp(
      r'^spyhell:([a-f0-9]{16}):([a-f0-9]{24})$',
    ).firstMatch(channelId);
    if (match == null) {
      throw const DaddyLiveException(
        'The Spyhell channel identity is invalid.',
      );
    }
    final channel = (await _database.getCachedChannels())
        .where((item) => item.id == channelId)
        .firstOrNull;
    if (channel == null) {
      throw const DaddyLiveException(
        'The Spyhell channel is no longer cached.',
      );
    }
    final locator = channel.watchUrl;
    if (locator == null || locator.isEmpty) {
      throw const DaddyLiveException(
        'The Spyhell channel has no playable locator.',
      );
    }

    final snapshot = await _repositories.sync();
    final source = snapshot.sources.where((item) {
      return _isEligible(item) &&
          _fingerprint(item.stableKey).startsWith(match.group(1)!);
    }).firstOrNull;
    if (source == null) {
      throw const DaddyLiveException(
        'Install the Spyhell Live provider again to resolve this channel.',
      );
    }

    final raw = await _runtime.call(source, 'getVideoSources', <Object?>[
      locator,
      false,
    ], timeout: const Duration(seconds: 35));
    final options =
        mapQuickJsVideoSources(source, raw, idPrefix: 'spyhell-live')
            .where(
              (item) =>
                  item.isPlayable && !item.isExpired && item.drmType == null,
            )
            .toList(growable: false);
    if (options.isEmpty) {
      throw const DaddyLiveException(
        'The Spyhell provider did not return a supported live stream.',
      );
    }

    final primary = options.first;
    return DaddyLiveStream(
      url: primary.url,
      headers: primary.headers,
      embedUrl: '',
      expiresAt: primary.expiresAt,
      mediaType: _mediaType(primary),
      title: channel.name,
      variants: options.skip(1).map(_variant).toList(growable: false),
    );
  }

  bool _isEligible(SourceManifest source) {
    final repository = Uri.tryParse(source.repositoryUrl ?? '');
    final path = repository?.path.toLowerCase() ?? '';
    return source.enabled &&
        source.status != 0 &&
        source.engine.kind == SourceEngineKind.javascript &&
        source.requiresLiveTvAdapter &&
        supportedSourceIds.contains(source.id.toLowerCase()) &&
        repository?.host.toLowerCase() == 'raw.githubusercontent.com' &&
        path.contains(repositoryMarker);
  }

  List<Map<String, dynamic>> _readRows(dynamic raw) {
    dynamic values = raw;
    if (raw is Map) {
      values =
          raw['rows'] ??
          raw['groups'] ??
          raw['items'] ??
          raw['channels'] ??
          raw['list'] ??
          raw['data'];
    }
    if (values is! List) return const <Map<String, dynamic>>[];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _readText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _fingerprint(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String _mediaType(UnifiedStreamOption option) =>
      option.container == StreamContainer.dash ? 'dash' : 'hls';

  LiveStreamVariant _variant(UnifiedStreamOption option) => LiveStreamVariant(
    url: option.url,
    headers: option.headers,
    mediaType: _mediaType(option),
    expiresAt: option.expiresAt,
    title: option.label ?? option.quality,
  );

  void _ensureOpen() {
    if (_closed) throw StateError('Spyhell Live TV service is closed.');
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _runtime.dispose();
  }

  static const DaddyLiveCatalog _emptyCatalog = DaddyLiveCatalog(
    channels: <Channel>[],
    epg: DaddyLiveEpg(timezone: 'UTC', days: <DaddyLiveEpgDay>[]),
    categories: <String>[],
  );
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
