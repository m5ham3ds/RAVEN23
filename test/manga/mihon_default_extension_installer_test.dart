import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/mihon/keiyoushi_extension_repository.dart';
import 'package:raven23/manga/mihon/mihon_default_extension_installer.dart';

void main() {
  group('Mihon default extension selection', () {
    test('resolves only the ten requested entries from the pinned signer', () {
      final entries = <MangaExtensionEntry>[
        for (final name in MihonDefaultExtensionInstaller.requestedNames)
          _extension(name),
        _extension('Unrequested source'),
        _extension(
          'Untrusted source',
          signingKey: List<String>.filled(64, 'b').join(),
        ),
      ];

      final selected = MihonDefaultExtensionInstaller.selectDefaultExtensions(
        entries,
      );

      expect(
        selected.keys.toList(),
        MihonDefaultExtensionInstaller.requestedNames,
      );
      expect(selected.length, 10);
      expect(selected.containsKey('Unrequested source'), isFalse);
      expect(selected.containsKey('AsgardScans'), isTrue);
    });

    test('prefers Arabic package when duplicate source names exist', () {
      final english = _extension(
        'AsgardScans',
        packageName: 'eu.kanade.tachiyomi.extension.en.asgardscans',
        language: 'en',
        versionCode: 99999,
      );
      final arabic = _extension(
        'Tachiyomi: AsgardScans',
        packageName: 'eu.kanade.tachiyomi.extension.ar.asgardscans',
        language: 'ar',
        versionCode: 10603,
      );

      final selected = MihonDefaultExtensionInstaller.selectDefaultExtensions(
        <MangaExtensionEntry>[english, arabic],
      );

      expect(selected['AsgardScans']?.packageName, arabic.packageName);
    });

    test('normalizes aliases and punctuation without fuzzy matching', () {
      expect(
        MihonDefaultExtensionInstaller.normalizeName('Tachiyomi: Manga Starz'),
        'mangastarz',
      );
      expect(MihonDefaultExtensionInstaller.normalizeName('X-COMIC'), 'xcomic');
      expect(
        MihonDefaultExtensionInstaller.normalizeName('Manga Star'),
        isNot(MihonDefaultExtensionInstaller.normalizeName('Manga Starz')),
      );
    });
  });
}

MangaExtensionEntry _extension(
  String name, {
  String? packageName,
  String language = 'ar',
  int versionCode = 10603,
  String? signingKey,
}) {
  final slug = MihonDefaultExtensionInstaller.normalizeName(name);
  return MangaExtensionEntry(
    name: name,
    packageName: packageName ?? 'eu.kanade.tachiyomi.extension.$language.$slug',
    version: '1.6.3',
    versionCode: versionCode,
    apkUrl: 'https://cdn.example/$slug.apk',
    sources: <MangaExtensionSource>[
      MangaExtensionSource(
        name: name,
        language: language,
        homeUrl: 'https://$slug.example',
      ),
    ],
    isNsfw: false,
    signingKey:
        signingKey ??
        MihonDefaultExtensionInstaller.trustedKeiyoushiFingerprint,
  );
}
