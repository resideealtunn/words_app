import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/word_types.dart';
import '../database/database_helper.dart';
import '../models/package.dart';
import '../models/word.dart';
import '../pages/practice_page.dart' show PracticePage;
import '../widgets/part_of_speech_picker.dart';
import '../widgets/word_detail_sheet.dart';

enum SortType { alphabetical, newest, random }
enum LanguageMode { englishToTurkish, turkishToEnglish }

class ViewListPage extends StatefulWidget {
  final Package package;

  const ViewListPage({super.key, required this.package});

  @override
  State<ViewListPage> createState() => _ViewListPageState();
}

class _ViewListPageState extends State<ViewListPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  List<String> _availableTypes = [];
  bool _isLoading = true;
  SortType _currentSort = SortType.alphabetical;
  LanguageMode _languageMode = LanguageMode.englishToTurkish;
  String _searchQuery = '';
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final words = await _databaseHelper.getWordsByPackage(widget.package.id!);
      final types = <String>{};
      for (final w in words) {
        types.addAll(parseWordTypes(w.partOfSpeech));
      }
      setState(() {
        _allWords = words;
        _availableTypes = types.toList()..sort();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading words: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<Word> _sortWords(List<Word> words) {
    switch (_currentSort) {
      case SortType.alphabetical:
        return List<Word>.from(words)..sort((a, b) => a.englishWord.toLowerCase().compareTo(b.englishWord.toLowerCase()));
      case SortType.newest:
        return List<Word>.from(words)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortType.random:
        final shuffled = List<Word>.from(words);
        shuffled.shuffle();
        return shuffled;
    }
  }

  void _applyFilters() {
    var list = _allWords.where((word) {
      if (!wordMatchesTypeFilter(word.partOfSpeech, _typeFilter)) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return word.englishWord.toLowerCase().contains(q) ||
          word.turkishMeaning.toLowerCase().contains(q);
    }).toList();
    _filteredWords = _sortWords(list);
  }

  void _filterWords(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _changeSort(SortType sortType) {
    setState(() {
      _currentSort = sortType;
      _applyFilters();
    });
  }

  void _openPracticeForVisible() {
    if (_filteredWords.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          package: widget.package,
          initialWords: List<Word>.from(_filteredWords),
          title: _typeFilter == 'all'
              ? 'List practice'
              : (kWordTypeLabels[_typeFilter] ?? _typeFilter),
        ),
      ),
    );
  }

  String _getSortTypeText(SortType sortType) {
    switch (sortType) {
      case SortType.alphabetical:
        return 'A-Z';
      case SortType.newest:
        return 'Newest';
      case SortType.random:
        return 'Random';
    }
  }

  String _getLanguageModeText(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.englishToTurkish:
        return 'EN → TR';
      case LanguageMode.turkishToEnglish:
        return 'TR → EN';
    }
  }

  Future<void> _showWordDetailCard(Word word) async {
    await showDialog(
      context: context,
      builder: (context) => WordDetailSheet(
        word: word,
        packageName: widget.package.name,
        onToggleStudyLater: () async {
          final adding = !word.studyLater;
          Navigator.of(context).pop();
          await _databaseHelper.setStudyLater(word.id!, adding);
          await _loadWords();
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(adding ? 'Added to study later' : 'Removed from study later'),
              backgroundColor: const Color(0xFF8DC71D),
            ),
          );
        },
        onMarkLearned: () async {
          Navigator.of(context).pop();
          await _databaseHelper.markLearnedFromStudyList(word.id!);
          await _loadWords();
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('"${word.englishWord}" marked as learned'),
              backgroundColor: const Color(0xFF8DC71D),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${widget.package.name} - Words',
          style: const TextStyle(color: Color(0xFF8DC71D)),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8DC71D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Practice visible words',
            icon: const Icon(Icons.style, color: Color(0xFF8DC71D)),
            onPressed: _openPracticeForVisible,
          ),
          if (_availableTypes.isNotEmpty)
            PartOfSpeechFilterDropdown(
              value: _typeFilter,
              availableTypes: _availableTypes,
              dark: true,
              onChanged: (v) {
                setState(() {
                  _typeFilter = v ?? 'all';
                  _applyFilters();
                });
              },
            ),
          // Language Mode Button
          PopupMenuButton<LanguageMode>(
            icon: const Icon(Icons.language, color: Color(0xFF8DC71D)),
            onSelected: (mode) {
              setState(() {
                _languageMode = mode;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: LanguageMode.englishToTurkish,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: _languageMode == LanguageMode.englishToTurkish 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'English → Turkish',
                      style: TextStyle(
                        color: _languageMode == LanguageMode.englishToTurkish 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LanguageMode.turkishToEnglish,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: _languageMode == LanguageMode.turkishToEnglish 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Turkish → English',
                      style: TextStyle(
                        color: _languageMode == LanguageMode.turkishToEnglish 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Sort Button
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort, color: Color(0xFF8DC71D)),
            onSelected: _changeSort,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortType.alphabetical,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      color: _currentSort == SortType.alphabetical 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alphabetical (A-Z)',
                      style: TextStyle(
                        color: _currentSort == SortType.alphabetical 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.newest,
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: _currentSort == SortType.newest 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Newest First',
                      style: TextStyle(
                        color: _currentSort == SortType.newest 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.random,
                child: Row(
                  children: [
                    Icon(
                      Icons.shuffle,
                      color: _currentSort == SortType.random 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Random',
                      style: TextStyle(
                        color: _currentSort == SortType.random 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _searchController,
              style: const TextStyle(color: Color(0xFF8DC71D)),
              decoration: InputDecoration(
                labelText: 'Search words',
                labelStyle: const TextStyle(color: Color(0xFF8DC71D)),
                hintText: 'Search by English or Turkish...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8DC71D)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF8DC71D)),
                        onPressed: () {
                          _searchController.clear();
                          _filterWords('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8DC71D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8DC71D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8DC71D), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onChanged: _filterWords,
            ),
          ),

          // Sort and Language Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Sort: ${_getSortTypeText(_currentSort)}',
                  style: const TextStyle(
                    color: Color(0xFF8DC71D),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Mode: ${_getLanguageModeText(_languageMode)}',
                  style: const TextStyle(
                    color: Color(0xFF8DC71D),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredWords.length} words',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Words List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8DC71D),
                    ),
                  )
                : _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No words found'
                                  : 'No words match your search',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () => _showWordDetailCard(word),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[800]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Word display based on language mode
                                    Expanded(
                                      child: _languageMode == LanguageMode.englishToTurkish
                                          ? Text(
                                              '${word.englishWord} : ${word.turkishMeaning}',
                                              style: const TextStyle(
                                                color: Color(0xFF8DC71D),
                                                fontSize: 16,
                                                height: 1.4,
                                              ),
                                            )
                                          : Text(
                                              '${word.turkishMeaning} : ${word.englishWord}',
                                              style: const TextStyle(
                                                color: Color(0xFF8DC71D),
                                                fontSize: 16,
                                                height: 1.4,
                                              ),
                                            ),
                                    ),
                                    // Image if exists
                                    if (word.imagePath != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey[700]!,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.file(
                                            File(word.imagePath!),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (word.studyLater) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.bookmark,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                    ],
                                    // Tap indicator
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey[600],
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 