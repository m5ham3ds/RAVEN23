import '../models/external_subtitles.dart';

/// Orders candidates for one explicitly selected subtitle language.
///
/// This is deliberately a lexicographic evidence selector, not a weighted
/// score: no unbenchmarked numeric weights or confidence thresholds are
/// invented. Provider name is never a ranking signal.
class SubtitleSelectionEngine {
  SubtitleSelectionEngine._();

  static List<ExternalSubtitle> rankForLanguage({
    required Iterable<ExternalSubtitle> candidates,
    required String languageCode,
    String? expectedRelease,
  }) {
    final target = normalizeLanguageCode(languageCode);
    if (target.isEmpty) return const <ExternalSubtitle>[];

    final eligible = candidates
        .where(
          (candidate) =>
              normalizeLanguageCode(candidate.language) == target &&
              candidate.isExactIdentity != false,
        )
        .toList(growable: true);

    eligible.sort((a, b) => _compare(
      a,
      b,
      expectedRelease: expectedRelease,
    ));
    return List<ExternalSubtitle>.unmodifiable(eligible);
  }

  static String normalizeLanguageCode(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    final first = raw.split(RegExp(r'[-_\s·\[]')).first;
    return switch (first) {
      'ara' || 'arabic' => 'ar',
      'eng' || 'english' => 'en',
      _ => first,
    };
  }

  static int _compare(
    ExternalSubtitle a,
    ExternalSubtitle b, {
    required String? expectedRelease,
  }) {
    final releaseA = _matchesReleaseSignals(a.release, expectedRelease);
    final releaseB = _matchesReleaseSignals(b.release, expectedRelease);
    final releaseOrder = _descendingBool(releaseA, releaseB);
    if (releaseOrder != 0) return releaseOrder;

    final identityOrder = _descendingBool(
      a.isExactIdentity == true,
      b.isExactIdentity == true,
    );
    if (identityOrder != 0) return identityOrder;

    final trustedOrder = _descendingBool(
      a.isTrustedUploader == true,
      b.isTrustedUploader == true,
    );
    if (trustedOrder != 0) return trustedOrder;

    final ratioA = _positiveRatingRatio(a);
    final ratioB = _positiveRatingRatio(b);
    if (ratioA != null || ratioB != null) {
      if (ratioA == null) return 1;
      if (ratioB == null) return -1;
      final ratingOrder = ratioB.compareTo(ratioA);
      if (ratingOrder != 0) return ratingOrder;
    }

    final providerRatingOrder = _descendingNullableDouble(
      a.providerRating,
      b.providerRating,
    );
    if (providerRatingOrder != 0) return providerRatingOrder;

    final votesOrder = _descendingNullableInt(
      a.providerVotes,
      b.providerVotes,
    );
    if (votesOrder != 0) return votesOrder;

    final downloadsOrder = _descendingNullableInt(
      a.downloadCount,
      b.downloadCount,
    );
    if (downloadsOrder != 0) return downloadsOrder;

    final dateA = DateTime.tryParse(a.createdAt ?? '');
    final dateB = DateTime.tryParse(b.createdAt ?? '');
    if (dateA != null || dateB != null) {
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final dateOrder = dateB.compareTo(dateA);
      if (dateOrder != 0) return dateOrder;
    }

    return a.id.compareTo(b.id);
  }

  static bool _matchesReleaseSignals(String? candidate, String? expected) {
    final expectedTokens = _releaseTokens(expected);
    if (expectedTokens.isEmpty) return false;
    final candidateTokens = _releaseTokens(candidate);
    return expectedTokens.every(candidateTokens.contains);
  }

  static Set<String> _releaseTokens(String? value) {
    final normalized = (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'web[\s._-]*dl'), 'webdl')
        .replaceAll(RegExp(r'web[\s._-]*rip'), 'webrip');
    final tokens = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    const releaseSignals = <String>{
      '360p',
      '480p',
      '540p',
      '576p',
      '720p',
      '1080p',
      '1440p',
      '2160p',
      'webdl',
      'webrip',
      'bluray',
      'bdrip',
      'hdtv',
      'dvdrip',
      'x264',
      'x265',
      'h264',
      'h265',
      'hevc',
      'av1',
      'hdr',
      'hdr10',
      'dv',
    };
    return tokens.where(releaseSignals.contains).toSet();
  }

  static double? _positiveRatingRatio(ExternalSubtitle item) {
    final good = item.ratingGood;
    final bad = item.ratingBad;
    if (good == null || bad == null || good + bad <= 0) return null;
    return good / (good + bad);
  }

  static int _descendingBool(bool a, bool b) =>
      a == b ? 0 : (a ? -1 : 1);

  static int _descendingNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static int _descendingNullableDouble(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}
