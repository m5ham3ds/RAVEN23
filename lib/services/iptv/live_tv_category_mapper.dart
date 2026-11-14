/// Converts common IPTV/Spyhell group labels to the app's stable Live TV
/// categories while preserving provider-specific labels that are not known.
String? mapLiveTvGroup(String? supplied) {
  final raw = (supplied ?? '').trim();
  if (raw.isEmpty) return null;
  final value = raw.toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');
  if (RegExp(
    r'\b(sport|sports|football|soccer|cricket|basketball)\b',
  ).hasMatch(value)) {
    return 'Sports';
  }
  if (RegExp(r'\b(news|breaking|headline)\b').hasMatch(value)) return 'News';
  if (RegExp(
    r'\b(documentary|documentaries|history|nature)\b',
  ).hasMatch(value)) {
    return 'Documentary';
  }
  if (RegExp(r'\b(movie|movies|film|cinema)\b').hasMatch(value)) {
    return 'Movies';
  }
  if (RegExp(r'\b(series|drama|serial)\b').hasMatch(value)) return 'Series';
  if (RegExp(r'\b(animation|animated|anime|cartoon)\b').hasMatch(value)) {
    return 'Animation';
  }
  if (RegExp(r'\b(kids|children|childrens|junior)\b').hasMatch(value)) {
    return 'Kids';
  }
  if (RegExp(r'\b(music|radio|concert)\b').hasMatch(value)) return 'Music';
  if (RegExp(r'\b(travel|tourism|explore)\b').hasMatch(value)) return 'Travel';
  if (RegExp(r'\b(comedy|humor|humour)\b').hasMatch(value)) return 'Comedy';
  if (RegExp(r'\b(cooking|food|culinary)\b').hasMatch(value)) return 'Cooking';
  if (RegExp(r'\b(education|educational|learning|science)\b').hasMatch(value)) {
    return 'Education';
  }
  if (RegExp(r'\b(world|global|international|worldwide)\b').hasMatch(value)) {
    return 'World';
  }
  if (RegExp(r'\b(entertainment|variety|lifestyle)\b').hasMatch(value)) {
    return 'Entertainment';
  }
  // Keep a useful provider label; do not collapse unknown groups into a fake
  // universal category such as "All".
  return raw.length > 48 ? raw.substring(0, 48).trim() : raw;
}
