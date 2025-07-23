Rimport 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import '../models/package.dart';
import '../models/word.dart';
import '../database/database_helper.dart';

enum LanguageMode { englishToTurkish, turkishToEnglish }
enum QuizMode { random, sequential }

class TestYourselfPage extends StatefulWidget {
  final Package package;

  const TestYourselfPage({super.key, required this.package});

  @override
  State<TestYourselfPage> createState() => _TestYourselfPageState();
}

class _TestYourselfPageState extends State<TestYourselfPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  List<Word> _allWords = [];
  List<Word> _quizWords = [];
  List<Word> _options = [];
  bool _isLoading = true;
  LanguageMode _languageMode = LanguageMode.englishToTurkish;
  QuizMode _quizMode = QuizMode.random;
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _isAnswered = false;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  bool _showContinueButton = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final words = await _databaseHelper.getWordsByPackage(widget.package.id!);
      setState(() {
        _allWords = words;
        _quizWords = List.from(words);
        _totalQuestions = words.length;
        _isLoading = false;
      });
      _prepareNextQuestion();
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
      _resetQuestion();
    });
  }

  void _changeQuizMode(QuizMode mode) {
    setState(() {
      _quizMode = mode;
      _resetQuiz();
    });
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _showContinueButton = false;
      if (_quizMode == QuizMode.random) {
        _quizWords.shuffle();
      }
    });
    _prepareNextQuestion();
  }

  void _resetQuestion() {
    setState(() {
      _selectedAnswer = null;
      _isAnswered = false;
    });
    _prepareNextQuestion();
  }

  void _prepareNextQuestion() {
    if (_quizWords.isEmpty) return;

    final currentWord = _quizWords[_currentIndex];
    final correctAnswer = _languageMode == LanguageMode.englishToTurkish
        ? currentWord.turkishMeaning
        : currentWord.englishWord;

    // Create options list with correct answer
    _options = [];
    
    // Add correct answer
    _options.add(currentWord);
    
    // Add 4 random wrong answers
    final random = Random();
    final availableWords = List<Word>.from(_allWords)..remove(currentWord);
    availableWords.shuffle();
    
    for (int i = 0; i < 4 && i < availableWords.length; i++) {
      _options.add(availableWords[i]);
    }
    
    // Shuffle options
    _options.shuffle();
  }

  void _selectAnswer(int index) {
    if (_isAnswered) return;
    
    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
      
      final selectedWord = _options[index];
      final currentWord = _quizWords[_currentIndex];
      
      final correctAnswer = _languageMode == LanguageMode.englishToTurkish
          ? currentWord.turkishMeaning
          : currentWord.englishWord;
      
      final selectedAnswer = _languageMode == LanguageMode.englishToTurkish
          ? selectedWord.turkishMeaning
          : selectedWord.englishWord;
      
      if (selectedAnswer == correctAnswer) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _isAnswered = false;
      });
      _prepareNextQuestion();
    } else {
      setState(() {
        _showContinueButton = true;
      });
    }
  }

  void _continueQuiz() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _showContinueButton = false;
      if (_quizMode == QuizMode.random) {
        _quizWords.shuffle();
      }
    });
    _prepareNextQuestion();
  }

  String _getLanguageModeText(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.englishToTurkish:
        return 'EN → TR';
      case LanguageMode.turkishToEnglish:
        return 'TR → EN';
    }
  }

  String _getQuizModeText(QuizMode mode) {
    switch (mode) {
      case QuizMode.random:
        return 'Random';
      case QuizMode.sequential:
        return 'Sequential';
    }
  }

  Color _getOptionColor(int index) {
    if (!_isAnswered) return Colors.grey[800]!;
    
    final selectedWord = _options[index];
    final currentWord = _quizWords[_currentIndex];
    
    final correctAnswer = _languageMode == LanguageMode.englishToTurkish
        ? currentWord.turkishMeaning
        : currentWord.englishWord;
    
    final selectedAnswer = _languageMode == LanguageMode.englishToTurkish
        ? selectedWord.turkishMeaning
        : selectedWord.englishWord;
    
    if (selectedAnswer == correctAnswer) {
      return Colors.green[600]!;
    } else if (index == _selectedAnswer) {
      return Colors.red[600]!;
    } else {
      return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Test Yourself - ${widget.package.name}',
          style: const TextStyle(color: Color(0xFF8DC71D)),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8DC71D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Quiz Mode Button
          PopupMenuButton<QuizMode>(
            icon: const Icon(Icons.shuffle, color: Color(0xFF8DC71D)),
            onSelected: _changeQuizMode,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: QuizMode.random,
                child: Row(
                  children: [
                    Icon(
                      Icons.shuffle,
                      color: _quizMode == QuizMode.random 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Random Questions',
                      style: TextStyle(
                        color: _quizMode == QuizMode.random 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: QuizMode.sequential,
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: _quizMode == QuizMode.sequential 
                          ? const Color(0xFF8DC71D) 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sequential Questions',
                      style: TextStyle(
                        color: _quizMode == QuizMode.sequential 
                            ? const Color(0xFF8DC71D) 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          : _quizWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No words to test',
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'Mode: ${_getLanguageModeText(_languageMode)}',
                                style: const TextStyle(
                                  color: Color(0xFF8DC71D),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Type: ${_getQuizModeText(_quizMode)}',
                                style: const TextStyle(
                                  color: Color(0xFF8DC71D),
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_currentIndex + 1} / ${_quizWords.length}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Score: $_correctAnswers / $_totalQuestions',
                                style: const TextStyle(
                                  color: Color(0xFF8DC71D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${((_correctAnswers / _totalQuestions) * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Color(0xFF8DC71D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Question
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        color: Colors.grey[900],
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'Question ${_currentIndex + 1}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _languageMode == LanguageMode.englishToTurkish
                                    ? _quizWords[_currentIndex].englishWord
                                    : _quizWords[_currentIndex].turkishMeaning,
                                style: const TextStyle(
                                  color: Color(0xFF8DC71D),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'What is the correct answer?',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _options.length,
                        itemBuilder: (context, index) {
                          final option = _options[index];
                          final optionText = _languageMode == LanguageMode.englishToTurkish
                              ? option.turkishMeaning
                              : option.englishWord;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _selectAnswer(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _getOptionColor(index),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedAnswer == index
                                        ? const Color(0xFF8DC71D)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedAnswer == index
                                              ? const Color(0xFF8DC71D)
                                              : Colors.grey[600]!,
                                          width: 2,
                                        ),
                                        color: _selectedAnswer == index
                                            ? const Color(0xFF8DC71D)
                                            : Colors.transparent,
                                      ),
                                      child: _selectedAnswer == index
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.black,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Navigation Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_showContinueButton)
                            ElevatedButton.icon(
                              onPressed: _continueQuiz,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Start New Quiz'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8DC71D),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            )
                          else if (_isAnswered)
                            ElevatedButton.icon(
                              onPressed: _nextQuestion,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next Question'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8DC71D),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 