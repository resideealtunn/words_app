import 'package:flutter/material.dart';
import '../models/package.dart';
import '../models/word.dart';
import '../database/database_helper.dart';

class AddWordGroupPage extends StatefulWidget {
  final Package package;

  const AddWordGroupPage({super.key, required this.package});

  @override
  State<AddWordGroupPage> createState() => _AddWordGroupPageState();
}

class _AddWordGroupPageState extends State<AddWordGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = false;
  List<Map<String, String>> _parsedWords = [];
  bool _hasParsedWords = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseWords() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final parsedWords = <Map<String, String>>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Check for different formats
      if (trimmedLine.contains(':')) {
        // Format: english: turkish
        final parts = trimmedLine.split(':');
        if (parts.length >= 2) {
          final english = parts[0].trim();
          final turkish = parts[1].trim();
          if (english.isNotEmpty && turkish.isNotEmpty) {
            parsedWords.add({
              'english': english,
              'turkish': turkish,
            });
          }
        }
      } else if (trimmedLine.contains(' - ')) {
        // Format: english - turkish
        final parts = trimmedLine.split(' - ');
        if (parts.length >= 2) {
          final english = parts[0].trim();
          final turkish = parts[1].trim();
          if (english.isNotEmpty && turkish.isNotEmpty) {
            parsedWords.add({
              'english': english,
              'turkish': turkish,
            });
          }
        }
      } else if (trimmedLine.contains('\t')) {
        // Format: english\tturkish (tab separated)
        final parts = trimmedLine.split('\t');
        if (parts.length >= 2) {
          final english = parts[0].trim();
          final turkish = parts[1].trim();
          if (english.isNotEmpty && turkish.isNotEmpty) {
            parsedWords.add({
              'english': english,
              'turkish': turkish,
            });
          }
        }
      }
    }

    setState(() {
      _parsedWords = parsedWords;
      _hasParsedWords = parsedWords.isNotEmpty;
    });

    if (parsedWords.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parsedWords.length} words parsed successfully!'),
          backgroundColor: const Color(0xFF8DC71D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No valid words found. Please check the format.'),
          backgroundColor: Colors.orange[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _saveWords() async {
    if (_parsedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No words to save. Please parse words first.'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int savedCount = 0;
      for (final wordData in _parsedWords) {
        final word = Word(
          packageId: widget.package.id!,
          englishWord: wordData['english']!,
          turkishMeaning: wordData['turkish']!,
          createdAt: DateTime.now(),
        );

        await _databaseHelper.insertWord(word);
        savedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedCount words saved successfully!'),
            backgroundColor: const Color(0xFF8DC71D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving words: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearText() {
    setState(() {
      _textController.clear();
      _parsedWords.clear();
      _hasParsedWords = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add Word Group'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8DC71D),
              Colors.white,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Package Info Card
              Card(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFF8DC71D).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8DC71D), Color(0xFF7AB51A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.package.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.package.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Adding multiple words to this package',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Text Input
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: 'Word List',
                    hintText: 'Paste your word list here...',
                    prefixIcon: const Icon(Icons.text_fields, color: Color(0xFF8DC71D)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8DC71D), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: null,
                  expands: true,
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _parseWords,
                      icon: const Icon(Icons.search),
                      label: const Text('Parse Words'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8DC71D),
                        side: const BorderSide(color: Color(0xFF8DC71D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearText,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Parsed Words Preview
              if (_hasParsedWords) ...[
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: const Color(0xFF8DC71D)),
                              const SizedBox(width: 8),
                              Text(
                                'Parsed Words (${_parsedWords.length})',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8DC71D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _parsedWords.length,
                              itemBuilder: (context, index) {
                                final word = _parsedWords[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          word['english']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const Text(' → '),
                                      Expanded(
                                        child: Text(
                                          word['turkish']!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasParsedWords && !_isLoading ? _saveWords : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF8DC71D),
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          _hasParsedWords 
                              ? 'Save ${_parsedWords.length} Words'
                              : 'Save Words',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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