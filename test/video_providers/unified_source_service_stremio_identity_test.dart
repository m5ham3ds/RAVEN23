import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/media_identity_resolver.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_repository_manager.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/stremio_addon_provider.dart';
import 'package:raven23/video_providers/unified/unified_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'resolves IMDb only when the stream resource for this type advertises it',
    () async {
      Uri? requestedUri;
      var lookupCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });

      final source = SourceManifest(
        id: 'resource-profile-addon',
        name: 'Resource Profile Addon',
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'idPrefixes': <String>['root:'],
            'streamResourceProfiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'types': <String>['movie'],
                'prefixMode': 'explicit',
                'idPrefixes': <String>['tt'],
              },
              <String, dynamic>{
                'types': <String>['series'],
                'prefixMode': 'explicit',
                'idPrefixes': <String>['kitsu:'],
              },
            ],
          },
        ),
      );
      final repositorySnapshot = SourceRepositorySyncResult(
        repositories: const <SourceRepositoryManifest>[],
        sources: <SourceManifest>[source],
        errors: const <String, String>{},
      );
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(
          engines: <SourceEngine>[
            StremioSourceEngine(
              provider: StremioAddonProvider(
                dio: dio,
                hostPolicy: const SourceHostPolicy(resolveDns: false),
              ),
            ),
          ],
        ),
        identityResolver: MediaIdentityResolver(
          lookup: (type, tmdbId) async {
            lookupCount++;
            expect(type, UnifiedMediaType.movie);
            expect(tmdbId, 42);
            return 'tt1234567';
          },
        ),
      );

      await service.search(
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          tmdbId: 42,
        ),
        repositorySnapshot: repositorySnapshot,
      );

      expect(lookupCount, 1);
      expect(requestedUri!.pathSegments.last, 'tt1234567.json');
      dio.close(force: true);
    },
  );

  test(
    'does not resolve IMDb when a resource profile accepts any supplied ID',
    () async {
      var lookupCount = 0;
      Uri? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      final source = SourceManifest(
        id: 'any-id-addon',
        name: 'Any ID Addon',
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'streamResourceProfiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'types': <String>['series'],
                'prefixMode': 'any',
              },
            ],
          },
        ),
      );
      final snapshot = SourceRepositorySyncResult(
        repositories: const <SourceRepositoryManifest>[],
        sources: <SourceManifest>[source],
        errors: const <String, String>{},
      );
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(
          engines: <SourceEngine>[
            StremioSourceEngine(
              provider: StremioAddonProvider(
                dio: dio,
                hostPolicy: const SourceHostPolicy(resolveDns: false),
              ),
            ),
          ],
        ),
        identityResolver: MediaIdentityResolver(
          lookup: (_, __) async {
            lookupCount++;
            return 'tt7654321';
          },
        ),
      );

      await service.search(
        media: const MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Anime',
          seasonNumber: 1,
          episodeNumber: 1,
          externalIds: <String, String>{'kitsu': '12345'},
        ),
        repositorySnapshot: snapshot,
      );

      expect(lookupCount, 0);
      expect(requestedUri!.pathSegments.last, 'kitsu:12345:1:1.json');
      dio.close(force: true);
    },
  );

  test(
    'does not perform IMDb lookup when a type-specific profile only accepts Kitsu',
    () async {
      var lookupCount = 0;
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      final source = SourceManifest(
        id: 'kitsu-only-addon',
        name: 'Kitsu Only Addon',
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'streamResourceProfiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'types': <String>['series'],
                'prefixMode': 'explicit',
                'idPrefixes': <String>['kitsu:'],
              },
            ],
          },
        ),
      );
      final snapshot = SourceRepositorySyncResult(
        repositories: const <SourceRepositoryManifest>[],
        sources: <SourceManifest>[source],
        errors: const <String, String>{},
      );
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(
          engines: <SourceEngine>[
            StremioSourceEngine(
              provider: StremioAddonProvider(
                dio: dio,
                hostPolicy: const SourceHostPolicy(resolveDns: false),
              ),
            ),
          ],
        ),
        identityResolver: MediaIdentityResolver(
          lookup: (_, __) async {
            lookupCount++;
            return 'tt7654321';
          },
        ),
      );

      await service.search(
        media: const MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Anime',
          seasonNumber: 1,
          episodeNumber: 1,
          externalIds: <String, String>{'kitsu': '12345'},
        ),
        repositorySnapshot: snapshot,
      );

      expect(lookupCount, 0);
      expect(requestCount, 1);
      dio.close(force: true);
    },
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Future<Map<String, dynamic>> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
