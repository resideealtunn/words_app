class Word {
  final int? id;
  final int packageId;
  final String englishWord;
  final String turkishMeaning;
  final String? description;
  final String? imagePath;
  final String? exampleSentence;
  final DateTime createdAt;
  final bool isLearned;

  Word({
    this.id,
    required this.packageId,
    required this.englishWord,
    required this.turkishMeaning,
    this.description,
    this.imagePath,
    this.exampleSentence,
    required this.createdAt,
    this.isLearned = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageId': packageId,
      'englishWord': englishWord,
      'turkishMeaning': turkishMeaning,
      'description': description,
      'imagePath': imagePath,
      'exampleSentence': exampleSentence,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isLearned': isLearned ? 1 : 0,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      packageId: map['packageId'],
      englishWord: map['englishWord'],
      turkishMeaning: map['turkishMeaning'],
      description: map['description'],
      imagePath: map['imagePath'],
      exampleSentence: map['exampleSentence'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isLearned: map['isLearned'] == 1,
    );
  }
} 