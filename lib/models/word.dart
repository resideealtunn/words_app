import 'dart:convert';

class Word {
  final int? id;
  final int packageId;
  final String englishWord;
  final String turkishMeaning;
  final String? partOfSpeech;
  final String? description;
  final String? imagePath;
  final String? exampleSentence;
  final String? exampleSentenceTr;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> otherForms;
  final DateTime createdAt;
  final bool isLearned;
  final bool studyLater;

  Word({
    this.id,
    required this.packageId,
    required this.englishWord,
    required this.turkishMeaning,
    this.partOfSpeech,
    this.description,
    this.imagePath,
    this.exampleSentence,
    this.exampleSentenceTr,
    this.synonyms = const [],
    this.antonyms = const [],
    this.otherForms = const [],
    required this.createdAt,
    this.isLearned = false,
    this.studyLater = false,
  });

  Word copyWith({
    int? id,
    int? packageId,
    String? englishWord,
    String? turkishMeaning,
    String? partOfSpeech,
    String? description,
    String? imagePath,
    String? exampleSentence,
    String? exampleSentenceTr,
    List<String>? synonyms,
    List<String>? antonyms,
    List<String>? otherForms,
    DateTime? createdAt,
    bool? isLearned,
    bool? studyLater,
  }) {
    return Word(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      englishWord: englishWord ?? this.englishWord,
      turkishMeaning: turkishMeaning ?? this.turkishMeaning,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      exampleSentenceTr: exampleSentenceTr ?? this.exampleSentenceTr,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      otherForms: otherForms ?? this.otherForms,
      createdAt: createdAt ?? this.createdAt,
      isLearned: isLearned ?? this.isLearned,
      studyLater: studyLater ?? this.studyLater,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageId': packageId,
      'englishWord': englishWord,
      'turkishMeaning': turkishMeaning,
      'partOfSpeech': partOfSpeech,
      'description': description,
      'imagePath': imagePath,
      'exampleSentence': exampleSentence,
      'exampleSentenceTr': exampleSentenceTr,
      'synonyms': encodeStringList(synonyms),
      'antonyms': encodeStringList(antonyms),
      'otherForms': encodeStringList(otherForms),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isLearned': isLearned ? 1 : 0,
      'studyLater': studyLater ? 1 : 0,
    };
  }

  /// Portable backup / nested JSON (lists stay as arrays).
  Map<String, dynamic> toBackupMap() {
    return {
      'englishWord': englishWord,
      'turkishMeaning': turkishMeaning,
      'partOfSpeech': partOfSpeech,
      'description': description,
      'exampleSentence': exampleSentence,
      'exampleSentenceTr': exampleSentenceTr,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'otherForms': otherForms,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLearned': isLearned,
      'studyLater': studyLater,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      packageId: map['packageId'] as int,
      englishWord: map['englishWord'] as String,
      turkishMeaning: map['turkishMeaning'] as String,
      partOfSpeech: map['partOfSpeech'] as String?,
      description: map['description'] as String?,
      imagePath: map['imagePath'] as String?,
      exampleSentence: map['exampleSentence'] as String?,
      exampleSentenceTr: map['exampleSentenceTr'] as String?,
      synonyms: decodeStringList(map['synonyms']),
      antonyms: decodeStringList(map['antonyms']),
      otherForms: decodeStringList(map['otherForms']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isLearned: map['isLearned'] == 1 || map['isLearned'] == true,
      studyLater: map['studyLater'] == 1 || map['studyLater'] == true,
    );
  }

  static String encodeStringList(List<String> items) => jsonEncode(items);

  static List<String> decodeStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // Fallback: comma-separated
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }
}
