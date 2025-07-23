class Package {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;
  final int wordCount;

  Package({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.wordCount = 0,
  });

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
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      wordCount: map['wordCount'] ?? 0,
    );
  }
} 