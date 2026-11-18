import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/mihon/keiyoushi_extension_repository.dart';
import 'package:raven23/manga/mihon/mihon_pb_index.dart';

List<int> _varint(int value) {
  var remaining = value;
  final out = <int>[];
  while (true) {
    final byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining == 0) {
      out.add(byte);
      return out;
    }
    out.add(byte | 0x80);
  }
}

List<int> _tag(int field, int wire) => _varint((field << 3) | wire);
List<int> _intField(int field, int value) => <int>[
  ..._tag(field, 0),
  ..._varint(value),
];
List<int> _bytesField(int field, List<int> value) => <int>[
  ..._tag(field, 2),
  ..._varint(value.length),
  ...value,
];
List<int> _stringField(int field, String value) =>
    _bytesField(field, utf8.encode(value));

void main() {
  group('PHASE55 Mihon protobuf index', () {
    test('decodes the compressed extension list and skips unrelated fields', () {
      final source = <int>[
        ..._intField(1, 42),
        ..._stringField(2, 'Example Manga Source'),
        ..._stringField(3, 'en'),
        ..._stringField(4, 'https://source.example'),
      ];
      final resources = <int>[
        ..._stringField(1, 'https://cdn.example/source.apk'),
        ..._stringField(2, 'https://cdn.example/icon.png'),
      ];
      final extension = <int>[
        ..._stringField(1, 'Example Extension'),
        ..._stringField(2, 'eu.kanade.tachiyomi.extension.en.example'),
        ..._bytesField(3, resources),
        ..._stringField(4, '1.6'), // extensionLib: not needed by the catalogue.
        ..._intField(5, 12),
        ..._stringField(6, '1.6.12'),
        ..._intField(7, 3), // CONTENT_WARNING_NSFW.
        ..._bytesField(8, source),
      ];
      final extensionList = _bytesField(1, extension);
      final store = <int>[
        ..._stringField(1, 'Keiyoushi'),
        // This field is not a trust anchor. Never interpret it as a signer key.
        ..._stringField(3, List<String>.filled(64, 'a').join()),
        ..._bytesField(101, extensionList),
      ];

      final decoded = decodeMihonPbRepositoryIndex(gzip.encode(store));

      expect(decoded.extensions, hasLength(1));
      final entry = MangaExtensionEntry.fromIndex(decoded.extensions.single);
      expect(entry.packageName, 'eu.kanade.tachiyomi.extension.en.example');
      expect(entry.apkUrl, 'https://cdn.example/source.apk');
      expect(entry.sources.single.name, 'Example Manga Source');
      expect(entry.isNsfw, isTrue);
      // A 64-hex string in an unknown protobuf field must never enable install.
      expect(entry.canInstall, isFalse);
    });

    test('rejects malformed and truncated protobuf data', () {
      expect(
        () => decodeMihonPbRepositoryIndex(<int>[0xAA, 0x06, 0x20]),
        throwsFormatException,
      );
      expect(decodeMihonPbRepositoryIndex(const <int>[]).extensions, isEmpty);
    });
  });
}
