/// Canonical part-of-speech options shown as checkboxes when adding/editing.
const List<String> kStandardWordTypes = [
  'n',
  'v',
  'adj',
  'adv',
  'prep',
  'conj',
  'pron',
  'interj',
  'phrase',
  'other',
];

const Map<String, String> kWordTypeLabels = {
  'n': 'Noun (n)',
  'v': 'Verb (v)',
  'adj': 'Adjective (adj)',
  'adv': 'Adverb (adv)',
  'prep': 'Preposition',
  'conj': 'Conjunction',
  'pron': 'Pronoun',
  'interj': 'Interjection',
  'phrase': 'Phrase',
  'other': 'Other',
};

/// Parse stored partOfSpeech into normalized type tokens.
Set<String> parseWordTypes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return {};
  final lower = raw.toLowerCase();
  final found = <String>{};

  for (final type in kStandardWordTypes) {
    if (type == 'other') continue;
    final pattern = RegExp('\\b${RegExp.escape(type)}\\b');
    if (pattern.hasMatch(lower) || lower.contains('($type)')) {
      found.add(type);
    }
  }

  if (found.isEmpty) {
    // Keep custom label (e.g. unknown tags) as its own bucket.
    found.add(raw.trim());
  }
  return found;
}

String encodeWordTypes(Iterable<String> types) {
  final cleaned = types
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return cleaned.join(', ');
}

/// Merge standard types with types already used in the user's data.
List<String> mergeAvailableTypes(Iterable<String> fromData) {
  final extras = <String>{};
  for (final raw in fromData) {
    for (final token in parseWordTypes(raw)) {
      if (!kStandardWordTypes.contains(token)) {
        extras.add(token);
      }
    }
  }
  return [...kStandardWordTypes, ...extras.toList()..sort()];
}

bool wordMatchesTypeFilter(String? partOfSpeech, String? filter) {
  if (filter == null || filter.isEmpty || filter == 'all') return true;
  return parseWordTypes(partOfSpeech).contains(filter) ||
      (partOfSpeech?.toLowerCase().contains(filter.toLowerCase()) ?? false);
}
