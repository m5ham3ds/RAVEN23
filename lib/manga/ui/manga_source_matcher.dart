/// Normalized similarity score for ranking AniList titles against concrete
/// Mihon search results. This is only a suggestion-ranking hint; automatic
/// binding uses [mangaTitleMatches] and requires a strict whole-title match.
double mangaTitleMatchScore(List<String> queries, String sourceTitle) {
  final target = normalizeMangaTitle(sourceTitle);
  if (target.isEmpty) return 0;
  var best = 0.0;
  for (final query in queries) {
    final candidate = normalizeMangaTitle(query);
    if (candidate.isEmpty) continue;
    if (candidate == target) return 1;
    if (candidate.contains(target) || target.contains(candidate)) {
      if (best < .88) best = .88;
      continue;
    }
    final a = candidate.split(' ').where((part) => part.length > 1).toSet();
    final b = target.split(' ').where((part) => part.length > 1).toSet();
    if (a.isEmpty || b.isEmpty) continue;
    final intersection = a.intersection(b).length;
    final dice = (2 * intersection) / (a.length + b.length);
    if (dice > best) best = dice;
  }
  return best;
}

String normalizeMangaTitle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'&amp;|&#0*38;'), 'and')
    .replaceAll(
      RegExp(r'[^a-z0-9\u0600-\u06ff\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af]+'),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Decorations that sources commonly append to a title without changing its
/// identity. The acceptance check remains whole-title equality after removal;
/// it never accepts a substring or a token-overlap guess.
final RegExp _mangaTitleDecorations = RegExp(
  r'\b(?:'
  r'(?:19|20)\d{2}'
  r'|s\d{1,2}(?:e\d{1,3})?'
  r'|season\s*\d+|part\s*\d+|episode\s*\d+'
  r'|watch|online|full\s*movie|free'
  r'|dual\s*audio|multi\s*audio'
  r'|\d{3,4}p|4k|hd|cam|hdrip|webrip|bluray'
  r')\b',
  caseSensitive: false,
);

String normalizeMangaIdentityTitle(String value) =>
    normalizeMangaTitle(value.replaceAll(_mangaTitleDecorations, ' '));

/// Strict source binding rule. Similarity scores may rank manual suggestions,
/// but automatic binding is allowed only when at least one AniList title or
/// alias equals the normalized source title exactly.
bool mangaTitleMatches(List<String> queries, String sourceTitle) {
  final source = normalizeMangaIdentityTitle(sourceTitle);
  if (source.isEmpty) return false;
  for (final query in queries) {
    final candidate = normalizeMangaIdentityTitle(query);
    if (candidate.isNotEmpty && candidate == source) return true;
  }
  return false;
}

/// Builds the ordered search aliases supplied by AniList. Search is performed
/// with every distinct alias (romaji, English, native, then synonyms), because
/// Mihon extensions often catalogue the same work under different scripts.
List<String> buildMangaTitleQueries({
  String? romaji,
  String? english,
  String? native,
  Iterable<String> synonyms = const <String>[],
}) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in <String?>[romaji, english, native, ...synonyms]) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) continue;
    final normalized = normalizeMangaIdentityTitle(value);
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(value);
  }
  return result;
}

String _westernizeMangaDigits(String value) =>
    value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      final digit = code >= 0x06F0 ? code - 0x06F0 : code - 0x0660;
      return '$digit';
    });

/// Parse a stable chapter number from Mihon's number field or visible title.
/// Some extensions return the number as a string and others only include it
/// in names such as "Chapter 12.5" or "12화". Unknown/special chapters return
/// null and retain their original relative position after numbered chapters.
double? parseMangaChapterNumber(Object? rawNumber, Object? rawTitle) {
  double? parse(Object? raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return value.isFinite && value >= 0 ? value : null;
    }
    if (raw is! String) return null;
    final value = _westernizeMangaDigits(raw.trim()).replaceAll(',', '.');
    if (value.isEmpty) return null;
    final match = RegExp(r'^#?(-?\d+(?:\.\d+)?)$').firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!);
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  final direct = parse(rawNumber);
  if (direct != null) return direct;
  final title = rawTitle == null
      ? null
      : _westernizeMangaDigits(rawTitle.toString().trim());
  if (title == null || title.isEmpty) return null;
  final labelled = RegExp(
    r'(?:chapter|chap\.?|ch\.?|episode|ep\.?|vol\.?|volume|الفصل|حلقة)\s*#?(-?\d+(?:[.,]\d+)?)',
    caseSensitive: false,
  ).firstMatch(title);
  final match = labelled ?? RegExp(r'#?(-?\d+(?:[.,]\d+)?)').firstMatch(title);
  if (match == null) return null;
  final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
}
