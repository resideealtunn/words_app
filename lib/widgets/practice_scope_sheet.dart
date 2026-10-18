import 'package:flutter/material.dart';

import '../constants/word_types.dart';
import '../database/database_helper.dart';
import '../models/package.dart';
import '../pages/practice_page.dart';

/// Bottom sheet: practice all / by type / study-later for a package.
Future<void> showPracticeScopeSheet(
  BuildContext context, {
  required Package package,
}) async {
  final db = DatabaseHelper();
  final types = await db.getDistinctPartsOfSpeech(packageId: package.id);
  final normalized = <String>{};
  for (final t in types) {
    normalized.addAll(parseWordTypes(t));
  }
  final typeList = normalized.toList()..sort();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Practice — ${package.name}',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose which words to practice as cards',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Color(0xFF8DC71D)),
                title: const Text('All words in package'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticePage(
                        package: package,
                        title: 'Practice',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.amber),
                title: const Text('Study later only'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticePage(
                        package: package,
                        studyLaterOnly: true,
                        title: 'Study later',
                      ),
                    ),
                  );
                },
              ),
              if (typeList.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'By word type',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.35,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: typeList.length,
                    itemBuilder: (_, i) {
                      final type = typeList[i];
                      return ListTile(
                        leading: const Icon(Icons.category,
                            color: Color(0xFF8DC71D)),
                        title: Text(kWordTypeLabels[type] ?? type),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final words = await db.getWordsByPackage(package.id!);
                          final filtered = words
                              .where(
                                (w) =>
                                    wordMatchesTypeFilter(w.partOfSpeech, type),
                              )
                              .toList();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PracticePage(
                                package: package,
                                initialWords: filtered,
                                title: kWordTypeLabels[type] ?? type,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
