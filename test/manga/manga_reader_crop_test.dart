import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/ui/manga_reader_crop.dart';

void main() {
  group('findMangaContentRect', () {
    test('detects flat white borders on all four edges', () {
      const width = 10;
      const height = 10;
      final pixels = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          final margin = x < 2 || x >= 8 || y < 2 || y >= 8;
          final value = margin ? 255 : ((x + y).isEven ? 0 : 80);
          pixels[offset] = value;
          pixels[offset + 1] = value;
          pixels[offset + 2] = value;
          pixels[offset + 3] = 255;
        }
      }

      final bounds = findMangaContentRect(pixels, width, height);

      expect(bounds, isNotNull);
      expect(bounds!.left, closeTo(.2, .001));
      expect(bounds.top, closeTo(.2, .001));
      expect(bounds.right, closeTo(.8, .001));
      expect(bounds.bottom, closeTo(.8, .001));
    });

    test('leaves a page untouched when no flat margin is present', () {
      final pixels = Uint8List(8 * 8 * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        final value = (i ~/ 4 * 37) % 251;
        pixels[i] = value;
        pixels[i + 1] = (value + 71) % 255;
        pixels[i + 2] = (value + 139) % 255;
        pixels[i + 3] = 255;
      }

      expect(findMangaContentRect(pixels, 8, 8), isNull);
    });

    test('rejects invalid pixel buffers safely', () {
      expect(findMangaContentRect(Uint8List(4), 10, 10), isNull);
    });
  });
}
