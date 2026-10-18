class Package {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;
  final int wordCount;
  final int learnedCount;

  Package({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.wordCount = 0,
    this.learnedCount = 0,
  });

  double get completionPercent {
    if (wordCount <= 0) return 0;
    return (learnedCount / wordCount) * 100;
  }

  bool get isComplete => wordCount > 0 && learnedCount >= wordCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'wordCount': wordCount,
    };
  }

  factory Package.fromMap(Map<String, dynamic> map) {
    return Package(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      wordCount: (map['wordCount'] as int?) ?? 0,
      learnedCount: (map['learnedCount'] as int?) ?? 0,
    );
  }

  Package copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    int? wordCount,
    int? learnedCount,
  }) {
    return Package(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      wordCount: wordCount ?? this.wordCount,
      learnedCount: learnedCount ?? this.learnedCount,
    );
  }
}

/// Natural order: "Day 1", "Day 2", ... then other names A–Z.
int comparePackagesByDay(Package a, Package b) {
  final dayA = _dayNumber(a.name);
  final dayB = _dayNumber(b.name);
  if (dayA != null && dayB != null) return dayA.compareTo(dayB);
  if (dayA != null) return -1;
  if (dayB != null) return 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int? _dayNumber(String name) {
  final match = RegExp(r'^day\s+(\d+)$', caseSensitive: false).firstMatch(name.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
