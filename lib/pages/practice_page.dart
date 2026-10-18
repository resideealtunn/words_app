import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/word_types.dart';
import '../database/database_helper.dart';
import '../models/package.dart';
import '../models/word.dart';
import '../widgets/part_of_speech_picker.dart';

enum LanguageMode { englishToTurkish, turkishToEnglish }

/// Practice flashcards for a package, a custom list, or study-later words.
class PracticePage extends StatefulWidget {
  final Package? package;
  final List<Word>? initialWords;
  final String title;
  final bool studyLaterOnly;

  const PracticePage({
    super.key,
    this.package,
    this.initialWords,
    this.title = 'Practice',
    this.studyLaterOnly = false,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();

  List<Word> _sourceWords = [];
  List<Word> _practiceWords = [];
  List<String> _availableTypes = [];
  String _typeFilter = 'all';
  bool _isLoading = true;
  LanguageMode _languageMode = LanguageMode.englishToTurkish;
  int _currentIndex = 0;
  bool _isFlipped = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    );
    _loadWords();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      List<Word> words;
      if (widget.initialWords != null) {
        words = List<Word>.from(widget.initialWords!);
      } else if (widget.studyLaterOnly) {
        words = await _db.getStudyLaterWords();
        if (widget.package?.id != null) {
          words = words
              .where((w) => w.packageId == widget.package!.id)
              .toList();
        }
      } else {
        words = await _db.getWordsByPackage(widget.package!.id!);
      }

      final types = <String>{};
      for (final w in words) {
        types.addAll(parseWordTypes(w.partOfSpeech));
      }

      if (!mounted) return;
      setState(() {
        _sourceWords = words;
        _availableTypes = types.toList()..sort();
        _applyFilter(shuffle: true);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading words: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  void _applyFilter({bool shuffle = false}) {
    var filtered = _sourceWords
        .where((w) => wordMatchesTypeFilter(w.partOfSpeech, _typeFilter))
        .toList();
    if (shuffle) filtered.shuffle();
    _practiceWords = filtered;
    _currentIndex = 0;
    _isFlipped = false;
    _flipController.reset();
  }

  void _setTypeFilter(String? value) {
    setState(() {
      _typeFilter = value ?? 'all';
      _applyFilter(shuffle: true);
    });
  }

  void _flipCard() {
    if (_practiceWords.isEmpty) return;
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _nextCard() {
    if (_practiceWords.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _practiceWords.length;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _previousCard() {
    if (_practiceWords.isEmpty) return;
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _practiceWords.length) % _practiceWords.length;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _shuffleWords() {
    setState(() => _applyFilter(shuffle: true));
  }

  void _replaceWord(Word updated) {
    setState(() {
      final i = _practiceWords.indexWhere((w) => w.id == updated.id);
      if (i >= 0) _practiceWords[i] = updated;
      final j = _sourceWords.indexWhere((w) => w.id == updated.id);
      if (j >= 0) _sourceWords[j] = updated;
    });
  }

  Future<void> _toggleStudyLater(Word word) async {
    if (word.id == null) return;
    final next = !word.studyLater;
    await _db.setStudyLater(word.id!, next);
    _replaceWord(word.copyWith(studyLater: next));
  }

  Future<void> _toggleLearned(Word word) async {
    if (word.id == null) return;
    final next = !word.isLearned;
    await _db.setWordLearned(word.id!, next);
    _replaceWord(word.copyWith(isLearned: next, studyLater: next ? false : word.studyLater));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.package != null
        ? '${widget.title} — ${widget.package!.name}'
        : widget.title;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Color(0xFF8DC71D))),
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFF8DC71D),
        actions: [
          if (_availableTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PartOfSpeechFilterDropdown(
                value: _typeFilter,
                availableTypes: _availableTypes,
                onChanged: _setTypeFilter,
                dark: true,
              ),
            ),
          PopupMenuButton<LanguageMode>(
            icon: const Icon(Icons.language, color: Color(0xFF8DC71D)),
            onSelected: (mode) {
              setState(() {
                _languageMode = mode;
                _isFlipped = false;
                _flipController.reset();
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: LanguageMode.englishToTurkish,
                child: Text('English → Turkish'),
              ),
              PopupMenuItem(
                value: LanguageMode.turkishToEnglish,
                child: Text('Turkish → English'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8DC71D)),
            )
          : _practiceWords.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            _languageMode == LanguageMode.englishToTurkish
                                ? 'EN → TR'
                                : 'TR → EN',
                            style: const TextStyle(color: Color(0xFF8DC71D)),
                          ),
                          if (_typeFilter != 'all') ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                kWordTypeLabels[_typeFilter] ?? _typeFilter,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor:
                                  const Color(0xFF8DC71D).withValues(alpha: 0.2),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} / ${_practiceWords.length}',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: GestureDetector(
                          onTap: _flipCard,
                          child: AnimatedBuilder(
                            animation: _flipAnimation,
                            builder: (context, _) {
                              final showBack = _flipAnimation.value >= 0.5;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(_flipAnimation.value * 3.14159),
                                child: showBack
                                    ? Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateY(3.14159),
                                        child: _buildBackCard(
                                          _practiceWords[_currentIndex],
                                        ),
                                      )
                                    : _buildFrontCard(
                                        _practiceWords[_currentIndex],
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: _previousCard,
                            icon: const Icon(Icons.arrow_back,
                                color: Color(0xFF8DC71D), size: 32),
                          ),
                          ElevatedButton.icon(
                            onPressed: _flipCard,
                            icon: Icon(
                              _isFlipped
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            label: Text(_isFlipped ? 'Hide' : 'Reveal'),
                          ),
                          IconButton(
                            onPressed: _nextCard,
                            icon: const Icon(Icons.arrow_forward,
                                color: Color(0xFF8DC71D), size: 32),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton.icon(
                        onPressed: _shuffleWords,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8DC71D),
                          side: const BorderSide(color: Color(0xFF8DC71D)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            _typeFilter == 'all'
                ? 'No words to practice'
                : 'No words for this type',
            style: TextStyle(color: Colors.grey[500], fontSize: 18),
          ),
          if (_typeFilter != 'all') ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setTypeFilter('all'),
              child: const Text('Show all types'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8DC71D), width: 2),
      ),
      child: child,
    );
  }

  Widget _buildFrontCard(Word word) {
    final prompt = _languageMode == LanguageMode.englishToTurkish
        ? word.englishWord
        : word.turkishMeaning;

    return _cardShell(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (word.partOfSpeech != null &&
                      word.partOfSpeech!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Chip(
                        label: Text(word.partOfSpeech!),
                        backgroundColor:
                            const Color(0xFF8DC71D).withValues(alpha: 0.2),
                      ),
                    ),
                  Text(
                    prompt,
                    style: const TextStyle(
                      color: Color(0xFF8DC71D),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tap to reveal',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: word.studyLater ? 'Remove study later' : 'Study later',
              onPressed: () => _toggleStudyLater(word),
              icon: Icon(
                word.studyLater ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(Word word) {
    final answer = _languageMode == LanguageMode.englishToTurkish
        ? word.turkishMeaning
        : word.englishWord;
    final prompt = _languageMode == LanguageMode.englishToTurkish
        ? word.englishWord
        : word.turkishMeaning;

    return _cardShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      color: Color(0xFF8DC71D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleStudyLater(word),
                  icon: Icon(
                    word.studyLater ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Meaning', answer, large: true),
                  if (word.partOfSpeech != null &&
                      word.partOfSpeech!.isNotEmpty)
                    _section('Type', word.partOfSpeech!),
                  if (word.exampleSentence != null &&
                      word.exampleSentence!.isNotEmpty)
                    _section('Example', word.exampleSentence!),
                  if (word.exampleSentenceTr != null &&
                      word.exampleSentenceTr!.isNotEmpty)
                    _section('Example (TR)', word.exampleSentenceTr!),
                  if (word.synonyms.isNotEmpty)
                    _chips('Synonyms', word.synonyms),
                  if (word.antonyms.isNotEmpty)
                    _chips('Antonyms', word.antonyms),
                  if (word.otherForms.isNotEmpty)
                    _chips('Other forms', word.otherForms),
                  if (word.description != null &&
                      word.description!.isNotEmpty)
                    _section('Notes', word.description!),
                  if (word.imagePath != null &&
                      word.imagePath!.isNotEmpty &&
                      File(word.imagePath!).existsSync()) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(word.imagePath!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleLearned(word),
                      icon: Icon(
                        word.isLearned
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        word.isLearned ? 'Learned ✓' : 'Mark as learned',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, String value, {bool large = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF8DC71D).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[200],
                fontSize: large ? 20 : 14,
                fontWeight: large ? FontWeight.w600 : FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (e) => Chip(
                    label: Text(e, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        const Color(0xFF8DC71D).withValues(alpha: 0.15),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
