import 'package:flutter/material.dart';
import 'dart:io';
import '../models/package.dart';
import '../models/word.dart';
import '../database/database_helper.dart';

enum LanguageMode { englishToTurkish, turkishToEnglish }

class PracticePage extends StatefulWidget {
  final Package package;

  const PracticePage({super.key, required this.package});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> with TickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  List<Word> _allWords = [];
  List<Word> _practiceWords = [];
  bool _isLoading = true;
  LanguageMode _languageMode = LanguageMode.englishToTurkish;
  int _currentIndex = 0;
  bool _isFlipped = false;
  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadWords();
  }

  @override
  void dispose() {
    _flipController.dispose();
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
        _practiceWords = List.from(words)..shuffle();
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

  void _changeLanguageMode(LanguageMode mode) {
    setState(() {
      _languageMode = mode;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _flipCard() {
    if (_practiceWords.isEmpty) return;
    
    setState(() {
      _isFlipped = !_isFlipped;
    });
    
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
      _currentIndex = (_currentIndex - 1 + _practiceWords.length) % _practiceWords.length;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _shuffleWords() {
    setState(() {
      _practiceWords.shuffle();
      _currentIndex = 0;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  String _getLanguageModeText(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.englishToTurkish:
        return 'EN → TR';
      case LanguageMode.turkishToEnglish:
        return 'TR → EN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Practice - ${widget.package.name}',
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
            onSelected: _changeLanguageMode,
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
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8DC71D),
              ),
            )
          : _practiceWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No words to practice',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add some words to this package first',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Progress and Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Mode: ${_getLanguageModeText(_languageMode)}',
                            style: const TextStyle(
                              color: Color(0xFF8DC71D),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} / ${_practiceWords.length}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Word Card
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GestureDetector(
                            onTap: _flipCard,
                            child: AnimatedBuilder(
                              animation: _flipAnimation,
                              builder: (context, child) {
                                final isBackVisible = _flipAnimation.value >= 0.5;
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(_flipAnimation.value * 3.14159),
                                  child: isBackVisible
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()..rotateY(3.14159),
                                          child: _buildBackCard(),
                                        )
                                      : _buildFrontCard(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Navigation Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: _previousCard,
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF8DC71D)),
                            iconSize: 32,
                          ),
                          ElevatedButton.icon(
                            onPressed: _flipCard,
                            icon: Icon(_isFlipped ? Icons.visibility_off : Icons.visibility),
                            label: Text(_isFlipped ? 'Hide Answer' : 'Show Answer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8DC71D),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: _nextCard,
                            icon: const Icon(Icons.arrow_forward, color: Color(0xFF8DC71D)),
                            iconSize: 32,
                          ),
                        ],
                      ),
                    ),

                    // Shuffle Button
                    Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton.icon(
                        onPressed: _shuffleWords,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle Words'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8DC71D),
                          side: const BorderSide(color: Color(0xFF8DC71D)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFrontCard() {
    final word = _practiceWords[_currentIndex];
    final displayText = _languageMode == LanguageMode.englishToTurkish
        ? word.englishWord
        : word.turkishMeaning;

    return Container(
      width: double.infinity,
      height: 500,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8DC71D).withOpacity(0.1),
            Colors.grey[900]!,
            Colors.grey[800]!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8DC71D), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8DC71D).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8DC71D).withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8DC71D).withOpacity(0.08),
              ),
            ),
          ),
          
          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated tap icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8DC71D).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF8DC71D).withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.touch_app,
                      size: 32,
                      color: const Color(0xFF8DC71D),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    'Tap to reveal answer',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Word in a beautiful container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF8DC71D).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      displayText,
                      style: const TextStyle(
                        color: Color(0xFF8DC71D),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Language mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8DC71D).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getLanguageModeText(_languageMode),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _buildBackCard() {
    final word = _practiceWords[_currentIndex];
    final questionText = _languageMode == LanguageMode.englishToTurkish
        ? word.englishWord
        : word.turkishMeaning;
    final answerText = _languageMode == LanguageMode.englishToTurkish
        ? word.turkishMeaning
        : word.englishWord;

    return Container(
      width: double.infinity,
      height: 500, // Increased height to fit all content
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8DC71D), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8DC71D).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8DC71D).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                questionText,
                style: const TextStyle(
                  color: Color(0xFF8DC71D),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            
            // Answer Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8DC71D).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Answer:',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answerText,
                    style: const TextStyle(
                      color: Color(0xFF8DC71D),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Content Grid - Image and Details side by side
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Image (if exists)
                  if (word.imagePath != null) ...[
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () => _showImageDialog(word.imagePath!),
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF8DC71D).withOpacity(0.5), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8DC71D).withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(word.imagePath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                                // Tap to enlarge overlay
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // Right side - Text Details
                  Expanded(
                    flex: word.imagePath != null ? 1 : 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        if (word.description != null) ...[
                          _buildCompactDetailRow('Description:', word.description!),
                          const SizedBox(height: 12),
                        ],
                        
                        // Example Sentence
                        if (word.exampleSentence != null) ...[
                          _buildCompactDetailRow('Example:', word.exampleSentence!),
                        ],
                        
                        // If no description or example, show a placeholder
                        if (word.description == null && word.exampleSentence == null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
                            ),
                            child: Text(
                              'No additional details available for this word.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Image
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8DC71D).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tap to close hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap outside to close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 