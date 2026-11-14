import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:raven23/manga/mihon/keiyoushi_extension_repository.dart';
import 'package:raven23/manga/mihon/manga_repository_manager.dart';
import 'package:raven23/manga/mihon/mihon_runtime.dart';
import 'package:raven23/manga/mihon/mihon_source_browser_screen.dart';

import '../support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  testWidgets(
    'combines available extensions and installed sources in one directory',
    (tester) async {
      final installed = _extension(
        name: 'AsgardScans',
        packageName: 'eu.kanade.tachiyomi.extension.ar.asgardscans',
        language: 'ar',
      );
      final available = _extension(
        name: 'Korean Scans',
        packageName: 'eu.kanade.tachiyomi.extension.ko.koreanscans',
        language: 'ko',
      );
      final runtime = _FakeRuntime(<MihonSourceInfo>[
        MihonSourceInfo(
          id: 1001,
          name: 'AsgardScans',
          lang: 'ar',
          packageName: installed.packageName,
          baseUrl: 'https://asgard.example',
          version: '1.6.3',
        ),
        MihonSourceInfo(
          id: 1002,
          name: 'Legacy Source',
          lang: 'en',
          packageName: 'com.legacy.extension',
          baseUrl: 'https://legacy.example',
          version: '0.9.0',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MihonSourceBrowserScreen(
            repository: _FakeRepository(<MangaExtensionEntry>[
              installed,
              available,
            ]),
            repositoryManager: _FakeRepositoryManager(),
            runtime: runtime,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Installed Manga Sources'), findsOneWidget);
      expect(find.text('AsgardScans'), findsOneWidget);
      expect(find.text('AR · 1.6.3'), findsOneWidget);
      expect(find.text('Korean Scans'), findsOneWidget);
      expect(find.text('KO · 1.6.3'), findsOneWidget);
      // A package that disappeared from the repository index must remain
      // visible and manageable through the same unified directory.
      expect(find.text('Legacy Source'), findsOneWidget);

      // Installed sources are pinned before available catalog entries.
      final asgardTop = tester.getTopLeft(find.text('AsgardScans')).dy;
      final legacyTop = tester.getTopLeft(find.text('Legacy Source')).dy;
      final koreanTop = tester.getTopLeft(find.text('Korean Scans')).dy;
      expect(asgardTop, lessThan(legacyTop));
      expect(legacyTop, lessThan(koreanTop));

      // Installed entries use the single forward action shown in the design
      // reference. Available entries expose website and secure-install actions.
      expect(find.byIcon(PhosphorIcons.caretRight()), findsNWidgets(2));
      expect(find.byIcon(PhosphorIcons.globeHemisphereWest()), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.downloadSimple()), findsOneWidget);

      await tester.longPress(find.text('Legacy Source'));
      await tester.pumpAndSettle();
      expect(find.text('com.legacy.extension · 0.9.0'), findsOneWidget);
      expect(find.text('Uninstall'), findsOneWidget);
    },
  );

  testWidgets('reveals the next source batch while scrolling', (tester) async {
    // The directory sorts names alphabetically. Zero-pad numeric fixture
    // names so Source 15 is a deterministic marker for the final page rather
    // than sorting into the first batch between Source 14 and Source 2.
    final extensions = <MangaExtensionEntry>[
      for (var index = 1; index <= 15; index++)
        _extension(
          name: 'Source ${index.toString().padLeft(2, '0')}',
          packageName: 'eu.kanade.tachiyomi.extension.en.source$index',
          language: 'en',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MihonSourceBrowserScreen(
          repository: _FakeRepository(extensions),
          repositoryManager: _FakeRepositoryManager(),
          runtime: _FakeRuntime(const <MihonSourceInfo>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Source 15'), findsNothing);
    expect(find.text('10 / 15'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    // The first scroll reveals rows 11–15. Continue to the end of the newly
    // revealed batch to bring the final row into the viewport. The padded
    // fixture names ensure alphabetical order matches the page boundaries.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(find.text('Source 15'), findsOneWidget);
  });
}

MangaExtensionEntry _extension({
  required String name,
  required String packageName,
  required String language,
}) => MangaExtensionEntry(
  name: name,
  packageName: packageName,
  version: '1.6.3',
  versionCode: 10603,
  apkUrl: 'https://cdn.example/$packageName.apk',
  sources: <MangaExtensionSource>[
    MangaExtensionSource(
      name: name,
      language: language,
      homeUrl: 'https://$language.example',
    ),
  ],
  isNsfw: false,
  signingKey: List<String>.filled(64, 'a').join(),
);

class _FakeRepository extends KeiyoushiExtensionRepository {
  _FakeRepository(this.entries);

  final List<MangaExtensionEntry> entries;

  @override
  Future<List<MangaExtensionEntry>> fetchExtensions({
    String repositoryUrl = KeiyoushiExtensionRepository.indexUrl,
  }) async => entries;
}

class _FakeRepositoryManager extends MangaRepositoryManager {
  @override
  Future<List<String>> repositoryUrls() async => const <String>[
    'https://repo.example/index.pb',
  ];
}

class _FakeRuntime extends MihonRuntimeService {
  _FakeRuntime(this.sources);

  final List<MihonSourceInfo> sources;

  @override
  bool get supportsNativeExtensions => true;

  @override
  Future<List<MihonSourceInfo>> listSources({bool reload = false}) async =>
      sources;
}
