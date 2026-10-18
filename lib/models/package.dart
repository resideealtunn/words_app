class Package {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final int wordCount;
  final int learnedCount;

  Package({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.lastOpenedAt,
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
      'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
      'wordCount': wordCount,
    };
  }

  factory Package.fromMap(Map<String, dynamic> map) {
    final lastOpenedRaw = map['lastOpenedAt'];
    return Package(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastOpenedAt: lastOpenedRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(lastOpenedRaw)
          : null,
      wordCount: (map['wordCount'] as int?) ?? 0,
      learnedCount: (map['learnedCount'] as int?) ?? 0,
    );
  }

  Package copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    bool clearLastOpenedAt = false,
    int? wordCount,
    int? learnedCount,
  }) {
    return Package(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt:
          clearLastOpenedAt ? null : (lastOpenedAt ?? this.lastOpenedAt),
      wordCount: wordCount ?? this.wordCount,
      learnedCount: learnedCount ?? this.learnedCount,
    );
  }
}

/// How packages are ordered on the packages list.
enum PackageSort {
  dayOrder,
  nameAsc,
  nameDesc,
  createdNewest,
  createdOldest,
  lastOpened,
  progressHigh,
  progressLow,
  wordCountHigh,
  wordCountLow,
}

extension PackageSortLabel on PackageSort {
  String get label {
    switch (this) {
      case PackageSort.dayOrder:
        return 'Day order (1 → 60)';
      case PackageSort.nameAsc:
        return 'Name A → Z';
      case PackageSort.nameDesc:
        return 'Name Z → A';
      case PackageSort.createdNewest:
        return 'Newest created';
      case PackageSort.createdOldest:
        return 'Oldest created';
      case PackageSort.lastOpened:
        return 'Recently opened';
      case PackageSort.progressHigh:
        return 'Progress high → low';
      case PackageSort.progressLow:
        return 'Progress low → high';
      case PackageSort.wordCountHigh:
        return 'Most words';
      case PackageSort.wordCountLow:
        return 'Fewest words';
    }
  }

  static PackageSort fromStorage(String? value) {
    return PackageSort.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PackageSort.dayOrder,
    );
  }
}

/// Natural order: "Day 1", "Day 2", ... then other names A–Z.
int comparePackagesByDay(Package a, Package b) {
  final dayA = packageDayNumber(a.name);
  final dayB = packageDayNumber(b.name);
  if (dayA != null && dayB != null) return dayA.compareTo(dayB);
  if (dayA != null) return -1;
  if (dayB != null) return 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int comparePackages(Package a, Package b, PackageSort sort) {
  switch (sort) {
    case PackageSort.dayOrder:
      return comparePackagesByDay(a, b);
    case PackageSort.nameAsc:
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case PackageSort.nameDesc:
      return b.name.toLowerCase().compareTo(a.name.toLowerCase());
    case PackageSort.createdNewest:
      return b.createdAt.compareTo(a.createdAt);
    case PackageSort.createdOldest:
      return a.createdAt.compareTo(b.createdAt);
    case PackageSort.lastOpened:
      final aTime = a.lastOpenedAt;
      final bTime = b.lastOpenedAt;
      if (aTime == null && bTime == null) return comparePackagesByDay(a, b);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final byOpened = bTime.compareTo(aTime);
      return byOpened != 0 ? byOpened : comparePackagesByDay(a, b);
    case PackageSort.progressHigh:
      final byProgress = b.completionPercent.compareTo(a.completionPercent);
      return byProgress != 0 ? byProgress : comparePackagesByDay(a, b);
    case PackageSort.progressLow:
      final byProgress = a.completionPercent.compareTo(b.completionPercent);
      return byProgress != 0 ? byProgress : comparePackagesByDay(a, b);
    case PackageSort.wordCountHigh:
      final byCount = b.wordCount.compareTo(a.wordCount);
      return byCount != 0 ? byCount : comparePackagesByDay(a, b);
    case PackageSort.wordCountLow:
      final byCount = a.wordCount.compareTo(b.wordCount);
      return byCount != 0 ? byCount : comparePackagesByDay(a, b);
  }
}

List<Package> filterAndSortPackages(
  List<Package> packages, {
  required String query,
  required PackageSort sort,
}) {
  final q = query.trim().toLowerCase();
  final filtered = q.isEmpty
      ? List<Package>.from(packages)
      : packages
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
  filtered.sort((a, b) => comparePackages(a, b, sort));
  return filtered;
}

int? packageDayNumber(String name) {
  final match =
      RegExp(r'^day\s+(\d+)$', caseSensitive: false).firstMatch(name.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
