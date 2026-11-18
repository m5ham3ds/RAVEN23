import 'dart:ui';

enum MangaTranslationEngine { online, offline }

class MangaTextRegion {
  const MangaTextRegion({required this.text, required this.bounds});

  final String text;
  final Rect bounds;
}

class MangaTranslatedRegion {
  const MangaTranslatedRegion({
    required this.original,
    required this.translated,
    required this.bounds,
  });

  final String original;
  final String translated;
  final Rect bounds;
}

class MangaPageTranslation {
  MangaPageTranslation({
    required this.imageWidth,
    required this.imageHeight,
    required Iterable<MangaTranslatedRegion> regions,
  }) : regions = List<MangaTranslatedRegion>.unmodifiable(regions) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('Image dimensions must be positive.');
    }
  }

  final int imageWidth;
  final int imageHeight;
  final List<MangaTranslatedRegion> regions;
}

class MangaTranslationModelStatus {
  const MangaTranslationModelStatus({
    required this.ocrReady,
    required this.sourceModelReady,
    required this.targetModelReady,
  });

  final bool ocrReady;
  final bool sourceModelReady;
  final bool targetModelReady;

  bool readyFor(MangaTranslationEngine engine) =>
      ocrReady &&
      (engine == MangaTranslationEngine.online ||
          (sourceModelReady && targetModelReady));
}

const mangaOcrLanguages = <String, String>{
  'ja': 'Japanese',
  'zh': 'Chinese',
  'ko': 'Korean',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'pt': 'Portuguese',
  'it': 'Italian',
  'hi': 'Hindi',
};

const mangaTranslationLanguages = <String, String>{
  'ar': 'Arabic',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'tr': 'Turkish',
  'id': 'Indonesian',
  'hi': 'Hindi',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese',
};
