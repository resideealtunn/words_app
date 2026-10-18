import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/word.dart';
import '../pages/practice_page.dart';
import '../widgets/word_detail_sheet.dart';

class StudyLaterPage extends StatefulWidget {
  const StudyLaterPage({super.key});

  @override
  State<StudyLaterPage> createState() => _StudyLaterPageState();
}

class _StudyLaterPageState extends State<StudyLaterPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Word> _words = [];
  final Map<int, String> _packageNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final words = await _db.getStudyLaterWords();
      final packages = await _db.getAllPackages();
      final names = <int, String>{
        for (final p in packages)
          if (p.id != null) p.id!: p.name,
      };
      if (!mounted) return;
      setState(() {
        _words = words;
        _packageNames
          ..clear()
          ..addAll(names);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading study list: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  Future<void> _openDetail(Word word) async {
    await showDialog(
      context: context,
      builder: (context) => WordDetailSheet(
        word: word,
        packageName: _packageNames[word.packageId],
        onToggleStudyLater: () async {
          Navigator.of(context).pop();
          await _db.setStudyLater(word.id!, false);
          await _load();
        },
        onMarkLearned: () async {
          Navigator.of(context).pop();
          await _db.markLearnedFromStudyList(word.id!);
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('"${word.englishWord}" marked as learned'),
              backgroundColor: const Color(0xFF8DC71D),
            ),
          );
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Study later'),
        actions: [
          if (_words.isNotEmpty)
            IconButton(
              tooltip: 'Practice as cards',
              icon: const Icon(Icons.style),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(
                      initialWords: List<Word>.from(_words),
                      studyLaterOnly: true,
                      title: 'Study later',
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8DC71D)),
            )
          : _words.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border,
                            size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No words marked for later',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open a word and tap “Study later” to collect it here.',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _words.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final word = _words[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _openDetail(word),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF8DC71D).withValues(alpha: 0.2),
                          child: const Icon(Icons.bookmark,
                              color: Color(0xFF8DC71D)),
                        ),
                        title: Text(
                          word.englishWord,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            word.turkishMeaning,
                            if (_packageNames[word.packageId] != null)
                              _packageNames[word.packageId]!,
                            if (word.partOfSpeech != null &&
                                word.partOfSpeech!.isNotEmpty)
                              word.partOfSpeech!,
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Mark learned',
                          icon: const Icon(Icons.check_circle_outline,
                              color: Color(0xFF8DC71D)),
                          onPressed: () async {
                            await _db.markLearnedFromStudyList(word.id!);
                            await _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
