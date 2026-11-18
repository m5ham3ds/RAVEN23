import '../../models/live_tv.dart';
import '../../models/xmltv_epg.dart';
import '../daddylive_service.dart';
import 'live_tv_category_mapper.dart';
import 'm3u_playlist_parser.dart';
import 'm3u_playlist_repository.dart';
import 'xmltv_epg_mapper.dart';
import 'xmltv_epg_repository.dart';

/// LiveTvService adapter for remote and imported local IPTV playlists.
class M3uLiveTvService implements LiveTvService {
  M3uLiveTvService({
    M3uPlaylistRepository? repository,
    M3uPlaylistParser parser = const M3uPlaylistParser(),
    XmlTvEpgRepository? epgRepository,
  }) : _repository = repository ?? M3uPlaylistRepository(),
       _parser = parser,
       _epgRepository = epgRepository ?? XmlTvEpgRepository();

  final M3uPlaylistRepository _repository;
  final M3uPlaylistParser _parser;
  final XmlTvEpgRepository _epgRepository;
  bool _closed = false;

  Future<M3uPlaylistDefinition> addRemotePlaylist({
    required String url,
    String? name,
  }) => _repository.addRemote(url: url, name: name);

  Future<M3uPlaylistDefinition> addLocalPlaylist({
    required String filename,
    required List<int> bytes,
    String? name,
  }) => _repository.addLocal(filename: filename, bytes: bytes, name: name);

  Future<List<M3uPlaylistDefinition>> playlists() => _repository.playlists();

  Future<void> removePlaylist(String id) => _repository.remove(id);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    _ensureOpen();
    final definitions = await _repository.playlists();
    if (definitions.isEmpty) return _emptyCatalog;

    final channels = <Channel>[];
    final epgUrls = <String>{};
    final categories = <String>{};
    var successful = 0;
    Object? lastError;
    for (final definition in definitions) {
      try {
        final content = await _repository.loadContent(
          definition,
          refresh: refresh,
        );
        final parsed = _parser.parse(
          content.text,
          baseUri: content.baseUri,
          playlistNamespace: definition.id,
        );
        if (!parsed.isChannelList) {
          throw FormatException(parsed.error ?? 'Invalid IPTV playlist.');
        }
        successful++;
        epgUrls.addAll(parsed.epgUrls);
        for (final entry in parsed.channels) {
          if (channels.length >= 25000) break;
          final group = mapLiveTvGroup(entry.groupTitle);
          if (group != null) categories.add(group);
          channels.add(
            Channel(
              id: 'm3u:${definition.id}:${entry.id}',
              name: entry.name,
              watchUrl: entry.url,
              playerUrl: entry.url,
              categories: group == null ? const <String>[] : <String>[group],
              logo: entry.logo,
              tvgId: entry.tvgId,
            ),
          );
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (successful == 0 && lastError != null) {
      throw DaddyLiveException(
        'One or more IPTV playlists could not be loaded.',
      );
    }
    final guides = <XmlTvGuide>[];
    final selectedEpgUrls = epgUrls.take(4).toList(growable: false);
    // Load at most two independent feeds concurrently to avoid a slow source
    // blocking all guide data without creating an unbounded mobile memory burst.
    for (var offset = 0; offset < selectedEpgUrls.length; offset += 2) {
      final batch = selectedEpgUrls.skip(offset).take(2);
      final loadedBatch = await Future.wait(
        batch.map((url) async {
          try {
            return await _epgRepository.load(
              url,
              namespace: 'iptv_m3u',
              refresh: refresh,
            );
          } on Object {
            // EPG is optional. A broken or blocked guide must not take channels
            // or playback offline.
            return null;
          }
        }),
      );
      for (final loaded in loadedBatch.whereType<XmlTvLoadResult>()) {
        // Stale data is retained by the repository for diagnostics/recovery,
        // but is never presented as a current or next programme.
        if (!loaded.isStale) guides.add(loaded.guide);
      }
    }
    final enrichedChannels = XmlTvEpgMapper.enrichChannels(channels, guides);
    final epg = XmlTvEpgMapper.toLegacyGuide(enrichedChannels, guides);
    return DaddyLiveCatalog(
      channels: List<Channel>.unmodifiable(enrichedChannels),
      epg: epg,
      categories: categories.toList()..sort(),
    );
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    _ensureOpen();
    final parts = channelId.split(':');
    if (parts.length != 3 || parts.first != 'm3u') {
      throw const DaddyLiveException('The IPTV channel identity is invalid.');
    }
    final definition = (await _repository.playlists())
        .where((item) => item.id == parts[1])
        .firstOrNull;
    if (definition == null) {
      throw const DaddyLiveException(
        'The IPTV playlist is no longer installed.',
      );
    }
    final content = await _repository.loadContent(definition);
    final parsed = _parser.parse(
      content.text,
      baseUri: content.baseUri,
      playlistNamespace: definition.id,
    );
    if (!parsed.isChannelList) {
      throw const DaddyLiveException(
        'The IPTV playlist is not a valid channel list.',
      );
    }
    final entry = parsed.channels
        .where((item) => item.id == parts[2])
        .firstOrNull;
    if (entry == null) {
      throw const DaddyLiveException('The IPTV channel is no longer listed.');
    }
    final uri = Uri.tryParse(entry.url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const DaddyLiveException('The IPTV stream URL is invalid.');
    }
    final mediaType = uri.path.toLowerCase().endsWith('.mpd') ? 'dash' : 'hls';
    return DaddyLiveStream(
      url: uri.toString(),
      headers: entry.headers,
      embedUrl: '',
      mediaType: mediaType,
      title: entry.name,
    );
  }

  void _ensureOpen() {
    if (_closed) throw StateError('M3U Live TV service is closed.');
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _repository.close();
    _epgRepository.close();
  }

  static const DaddyLiveCatalog _emptyCatalog = DaddyLiveCatalog(
    channels: <Channel>[],
    epg: DaddyLiveEpg(timezone: 'UTC', days: <DaddyLiveEpgDay>[]),
    categories: <String>[],
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
