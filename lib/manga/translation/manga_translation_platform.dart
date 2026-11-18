import 'package:flutter/services.dart';

import 'manga_translation_models.dart';

/// The narrow Android bridge for on-device manga OCR and offline text models.
class MangaTranslationPlatform {
  const MangaTranslationPlatform();

  static const MethodChannel _channel = MethodChannel(
    'raven23/manga_translation',
  );

  Future<Set<String>> supportedOcrLanguages() async {
    final values = await _channel.invokeListMethod<String>(
      'supportedOcrLanguages',
    );
    return values?.toSet() ?? <String>{};
  }

  Future<Set<String>> supportedOfflineLanguages() async {
    final values = await _channel.invokeListMethod<String>(
      'supportedOfflineLanguages',
    );
    return values?.toSet() ?? <String>{};
  }

  Future<MangaTranslationModelStatus> modelStatus({
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('modelStatus', {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'engine': engine.name,
    });
    if (raw == null) throw const FormatException('OCR model status is empty.');
    return MangaTranslationModelStatus(
      ocrReady: raw['ocrReady'] == true,
      sourceModelReady: raw['sourceModelReady'] == true,
      targetModelReady: raw['targetModelReady'] == true,
    );
  }

  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) async {
    await _channel.invokeMethod<void>('downloadModels', {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'engine': engine.name,
    });
  }

  Future<MangaOcrPageData> recognize({
    required String filePath,
    required String sourceLanguage,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('recognize', {
      'filePath': filePath,
      'sourceLanguage': sourceLanguage,
    });
    if (raw == null || raw['regions'] is! List) {
      throw const FormatException('OCR returned an invalid page result.');
    }
    final regions = <MangaTextRegion>[];
    for (final item in raw['regions'] as List) {
      if (item is! Map) continue;
      final text = item['text'];
      final left = item['left'];
      final top = item['top'];
      final right = item['right'];
      final bottom = item['bottom'];
      if (text is! String ||
          left is! num ||
          top is! num ||
          right is! num ||
          bottom is! num) {
        continue;
      }
      final bounds = Rect.fromLTRB(
        left.toDouble().clamp(0, 1).toDouble(),
        top.toDouble().clamp(0, 1).toDouble(),
        right.toDouble().clamp(0, 1).toDouble(),
        bottom.toDouble().clamp(0, 1).toDouble(),
      );
      if (bounds.width > 0 && bounds.height > 0 && text.trim().isNotEmpty) {
        regions.add(MangaTextRegion(text: text, bounds: bounds));
      }
    }
    return MangaOcrPageData(
      width: (raw['imageWidth'] as num?)?.toInt() ?? 0,
      height: (raw['imageHeight'] as num?)?.toInt() ?? 0,
      regions: regions,
    );
  }

  Future<List<String>> translateOffline({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final result = await _channel.invokeListMethod<String>('translateTexts', {
      'texts': texts,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    });
    if (result == null || result.length != texts.length) {
      throw const FormatException(
        'Offline translation returned an invalid result.',
      );
    }
    return result;
  }
}

class MangaOcrPageData {
  const MangaOcrPageData({
    required this.width,
    required this.height,
    required this.regions,
  });
  final int width;
  final int height;
  final List<MangaTextRegion> regions;
}
