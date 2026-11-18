import '../../functions/video_utils.dart';
import 'source_manifest.dart';

/// Keeps VidKing's audio-language metadata independent from video quality.
///
/// Only explicit, allow-listed language names/codes are recognized. This is
/// intentionally not a general-purpose text classifier: labels such as
/// `Multi`, `English dub 1080p`, or an arbitrary provider name are not treated
/// as an audio language.
abstract final class VidkingAudioQualityNormalizer {
  static const Map<String, String> _languageNames = <String, String>{
    'ar': 'Arabic',
    'ara': 'Arabic',
    'arabic': 'Arabic',
    'bg': 'Bulgarian',
    'bul': 'Bulgarian',
    'bulgarian': 'Bulgarian',
    'zh': 'Chinese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'chinese': 'Chinese',
    'hr': 'Croatian',
    'hrv': 'Croatian',
    'croatian': 'Croatian',
    'cs': 'Czech',
    'ces': 'Czech',
    'cze': 'Czech',
    'czech': 'Czech',
    'da': 'Danish',
    'dan': 'Danish',
    'danish': 'Danish',
    'nl': 'Dutch',
    'nld': 'Dutch',
    'dut': 'Dutch',
    'dutch': 'Dutch',
    'en': 'English',
    'eng': 'English',
    'english': 'English',
    'et': 'Estonian',
    'est': 'Estonian',
    'estonian': 'Estonian',
    'fi': 'Finnish',
    'fin': 'Finnish',
    'finnish': 'Finnish',
    'fr': 'French',
    'fra': 'French',
    'fre': 'French',
    'french': 'French',
    'de': 'German',
    'deu': 'German',
    'ger': 'German',
    'german': 'German',
    'el': 'Greek',
    'ell': 'Greek',
    'gre': 'Greek',
    'greek': 'Greek',
    'he': 'Hebrew',
    'heb': 'Hebrew',
    'iw': 'Hebrew',
    'hebrew': 'Hebrew',
    'hi': 'Hindi',
    'hin': 'Hindi',
    'hindi': 'Hindi',
    'hu': 'Hungarian',
    'hun': 'Hungarian',
    'hungarian': 'Hungarian',
    'id': 'Indonesian',
    'ind': 'Indonesian',
    'in': 'Indonesian',
    'indonesian': 'Indonesian',
    'it': 'Italian',
    'ita': 'Italian',
    'italian': 'Italian',
    'ja': 'Japanese',
    'jpn': 'Japanese',
    'japanese': 'Japanese',
    'ko': 'Korean',
    'kor': 'Korean',
    'korean': 'Korean',
    'lv': 'Latvian',
    'lav': 'Latvian',
    'latvian': 'Latvian',
    'lt': 'Lithuanian',
    'lit': 'Lithuanian',
    'lithuanian': 'Lithuanian',
    'ms': 'Malay',
    'msa': 'Malay',
    'may': 'Malay',
    'malay': 'Malay',
    'no': 'Norwegian',
    'nb': 'Norwegian',
    'nn': 'Norwegian',
    'nor': 'Norwegian',
    'norwegian': 'Norwegian',
    'pl': 'Polish',
    'pol': 'Polish',
    'polish': 'Polish',
    'pt': 'Portuguese',
    'por': 'Portuguese',
    'portuguese': 'Portuguese',
    'ro': 'Romanian',
    'ron': 'Romanian',
    'rum': 'Romanian',
    'romanian': 'Romanian',
    'ru': 'Russian',
    'rus': 'Russian',
    'russian': 'Russian',
    'sr': 'Serbian',
    'srp': 'Serbian',
    'scc': 'Serbian',
    'serbian': 'Serbian',
    'sk': 'Slovak',
    'slk': 'Slovak',
    'slo': 'Slovak',
    'slovak': 'Slovak',
    'sl': 'Slovene',
    'slv': 'Slovene',
    'slovene': 'Slovene',
    'es': 'Spanish',
    'spa': 'Spanish',
    'spanish': 'Spanish',
    'castilian': 'Spanish',
    'sv': 'Swedish',
    'swe': 'Swedish',
    'swedish': 'Swedish',
    'th': 'Thai',
    'tha': 'Thai',
    'thai': 'Thai',
    'tr': 'Turkish',
    'tur': 'Turkish',
    'turkish': 'Turkish',
    'uk': 'Ukrainian',
    'ukr': 'Ukrainian',
    'ukrainian': 'Ukrainian',
  };

  static const Map<String, String> _qualityAliases = <String, String>{
    '360': '360p',
    '360p': '360p',
    '480': '480p',
    '480p': '480p',
    'sd': '480p',
    '540': '540p',
    '540p': '540p',
    '576': '576p',
    '576p': '576p',
    '720': '720p',
    '720p': '720p',
    'hd': '720p',
    '1080': '1080p',
    '1080p': '1080p',
    'fhd': '1080p',
    'fullhd': '1080p',
    '1440': '1440p',
    '1440p': '1440p',
    '2k': '1440p',
    'qhd': '1440p',
    '2160': '2160p',
    '2160p': '2160p',
    '4k': '2160p',
    '4khdr': '2160p',
    'uhd': '2160p',
    'uhdhdr': '2160p',
    '4320': '4320p',
    '4320p': '4320p',
    '8k': '4320p',
    'auto': 'Auto',
  };

  /// Returns a canonical English display name only for known language values.
  static String? normalizeAudioLanguage(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return null;

    final withoutQualifier = value
        .replaceFirst(RegExp(r'\s*[\(\[].*[\)\]]\s*$'), '')
        .trim();
    final exact = _languageNames[withoutQualifier];
    if (exact != null) return exact;

    // Accept standard locale tags such as en-US or ar_SA, but only when the
    // first subtag is one of the explicitly supported language identifiers.
    final languageSubtag = withoutQualifier.split(RegExp(r'[-_]')).first;
    return _languageNames[languageSubtag];
  }

  /// Returns a canonical resolution token. Unknown values are ignored rather
  /// than being allowed to filter every valid stream by accident.
  static String? normalizeQualityFilter(Object? raw) {
    if (raw == null) return null;
    final compact = raw.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (compact.isEmpty) return null;
    return _qualityAliases[compact];
  }

  static int? qualityFilterHeight(Object? raw) {
    final normalized = normalizeQualityFilter(raw);
    if (normalized == null || normalized == 'Auto') return null;
    return VideoUtils.videoQualityHeight(normalized);
  }

  /// Unknown stream quality is retained; a filter must not discard a stream
  /// when its resolution cannot be established from the provider label.
  static bool matchesQualityFilter({
    required Object? filter,
    required String streamQuality,
  }) {
    final requiredHeight = qualityFilterHeight(filter);
    if (requiredHeight == null) return true;
    final actualHeight = VideoUtils.videoQualityHeight(streamQuality);
    return actualHeight == null || actualHeight == requiredHeight;
  }

  /// Migrates only known legacy language labels that were incorrectly stored
  /// in `qualityFilter`. All other unknown text is ignored as a quality filter
  /// and is never guessed to be an audio language.
  static SourceEngineDescriptor normalizeDescriptor(
    SourceEngineDescriptor descriptor,
  ) {
    if (descriptor.kind != SourceEngineKind.vidkingDirect) {
      return descriptor;
    }

    final explicitLanguage = normalizeAudioLanguage(descriptor.audioLanguage);
    final legacyQualityLanguage = normalizeAudioLanguage(
      descriptor.qualityFilter,
    );
    // `engine.language` is retained as a legacy request selector. Do not
    // duplicate it into `audioLanguage`: keeping its origin distinct lets the
    // VidKing adapter preserve the original wire value (for example `german`)
    // while `resolveAudioLanguage` still exposes the canonical `German`
    // default to stream metadata.
    return SourceEngineDescriptor(
      rawType: descriptor.rawType,
      kind: descriptor.kind,
      endpoint: descriptor.endpoint,
      priority: descriptor.priority,
      language: descriptor.language,
      audioLanguage: explicitLanguage ?? legacyQualityLanguage,
      qualityFilter: normalizeQualityFilter(descriptor.qualityFilter),
      movieUrl: descriptor.movieUrl,
      tvUrl: descriptor.tvUrl,
      config: descriptor.config,
    );
  }

  /// Preference order: user preference, explicit source configuration, then
  /// a recognized legacy source default. `SourceManifest.language` is
  /// intentionally not accepted here because it describes the repository
  /// entry, not necessarily the audio track in a returned stream.
  static String? resolveAudioLanguage({
    String? preferredAudioLanguage,
    required SourceEngineDescriptor engine,
  }) {
    final normalized = normalizeDescriptor(engine);
    return normalizeAudioLanguage(preferredAudioLanguage) ??
        normalizeAudioLanguage(normalized.audioLanguage) ??
        normalizeAudioLanguage(normalized.language);
  }
}
