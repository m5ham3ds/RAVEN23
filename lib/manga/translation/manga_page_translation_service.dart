import 'dart:convert';

import 'package:dio/dio.dart';

import 'manga_translation_models.dart';
import 'manga_translation_platform.dart';

/// Page-level translation: image recognition is local; online services receive
/// OCR strings only. The offline path uses the Android ML Kit text translator.
class MangaPageTranslationService {
  MangaPageTranslationService({MangaTranslationPlatform? platform, Dio? dio})
    : _platform = platform ?? const MangaTranslationPlatform(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final MangaTranslationPlatform _platform;
  final Dio _dio;
  final Map<String, MangaPageTranslation> _cache =
      <String, MangaPageTranslation>{};
  int _generation = 0;

  Future<Set<String>> supportedOcrLanguages() =>
      _platform.supportedOcrLanguages();
  Future<Set<String>> supportedOfflineLanguages() =>
      _platform.supportedOfflineLanguages();

  Future<MangaTranslationModelStatus> modelStatus({
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) => _platform.modelStatus(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    engine: engine,
  );

  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) => _platform.downloadModels(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    engine: engine,
  );

  void cancelPending() => _generation++;

  Future<MangaPageTranslation> translatePage({
    required String pageUrl,
    required String filePath,
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) async {
    final key = '$pageUrl|$sourceLanguage|$targetLanguage|${engine.name}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final generation = _generation;
    final ocr = await _platform.recognize(
      filePath: filePath,
      sourceLanguage: sourceLanguage,
    );
    if (generation != _generation) throw StateError('Translation cancelled.');
    if (ocr.regions.isEmpty) {
      return MangaPageTranslation(
        imageWidth: ocr.width,
        imageHeight: ocr.height,
        regions: const <MangaTranslatedRegion>[],
      );
    }

    final originalTexts = ocr.regions
        .map((region) => region.text)
        .toList(growable: false);
    final translated = engine == MangaTranslationEngine.offline
        ? await _platform.translateOffline(
            texts: originalTexts,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          )
        : await _translateOnline(
            originalTexts,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
    if (generation != _generation) throw StateError('Translation cancelled.');
    if (translated.length != ocr.regions.length) {
      throw const FormatException(
        'The translation count does not match the OCR regions.',
      );
    }
    final page = MangaPageTranslation(
      imageWidth: ocr.width,
      imageHeight: ocr.height,
      regions: <MangaTranslatedRegion>[
        for (var index = 0; index < ocr.regions.length; index++)
          MangaTranslatedRegion(
            original: ocr.regions[index].text,
            translated: translated[index],
            bounds: ocr.regions[index].bounds,
          ),
      ],
    );
    if (generation == _generation) {
      _cache[key] = page;
      while (_cache.length > 24) {
        _cache.remove(_cache.keys.first);
      }
    }
    return page;
  }

  Future<List<String>> _translateOnline(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final results = <String>[];
    for (final text in texts) {
      final response = await _dio.get<String>(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: <String, String>{
          'client': 'dict-chrome-ex',
          'sl': sourceLanguage,
          'tl': targetLanguage,
          'dt': 't',
          'q': text,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data?.trim();
      if (body == null || body.isEmpty || body.startsWith('<')) {
        throw const FormatException(
          'The online translation service returned an invalid response.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! List) {
        throw const FormatException(
          'The online translation response has an unexpected format.',
        );
      }
      final translatedText = (decoded.first as List)
          .whereType<List>()
          .map((segment) => segment.isEmpty ? '' : '${segment.first ?? ''}')
          .join();
      if (translatedText.isEmpty) {
        throw const FormatException(
          'The online translation response was empty.',
        );
      }
      results.add(translatedText);
    }
    return results;
  }
}
