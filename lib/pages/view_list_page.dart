import 'package:flutter/material.dart';
import 'dart:io';
import '../models/package.dart';
import '../models/word.dart';
import '../database/database_helper.dart';

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
  bool _isLoading = true;
  SortType _currentSort = SortType.alphabetical;
  LanguageMode _languageMode = LanguageMode.englishToTurkish;
  String _searchQuery = '';

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
      setState(() {
        _allWords = words;
        _filteredWords = _sortWords(words);
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

  void _filterWords(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredWords = _sortWords(_allWords);
      } else {
        final lowercaseQuery = query.toLowerCase();
        final filtered = _allWords.where((word) {
          return word.englishWord.toLowerCase().contains(lowercaseQuery) ||
                 word.turkishMeaning.toLowerCase().contains(lowercaseQuery);
        }).toList();
        _filteredWords = _sortWords(filtered);
      }
    });
  }

  void _changeSort(SortType sortType) {
    setState(() {
      _currentSort = sortType;
      _filteredWords = _sortWords(_filteredWords);
    });
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

  void _showWordDetailCard(Word word) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8DC71D),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8DC71D).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info,
                      color: Color(0xFF8DC71D),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Word Details',
                      style: TextStyle(
                        color: Color(0xFF8DC71D),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF8DC71D),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // English Word
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8DC71D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF8DC71D).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'English',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              word.englishWord,
                              style: const TextStyle(
                                color: Color(0xFF8DC71D),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Turkish Meaning
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.translate,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Turkish',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              word.turkishMeaning,
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Description if exists
                      if (word.description != null && word.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                word.description!,
                                style: TextStyle(
                                  color: Colors.blue[300],
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Example Sentence if exists
                      if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.format_quote,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Example Sentence',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '"${word.exampleSentence!}"',
                                style: TextStyle(
                                  color: Colors.purple[300],
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Image if exists
                      if (word.imagePath != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(11),
                                    topRight: Radius.circular(11),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.image,
                                      color: Colors.grey[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Image',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(11),
                                  bottomRight: Radius.circular(11),
                                ),
                                child: GestureDetector(
                                  onTap: () => _showFullScreenImage(word.imagePath!),
                                  child: Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: Image.file(
                                      File(word.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Date Added
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Added: ${_formatDate(word.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              child: InteractiveViewer(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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