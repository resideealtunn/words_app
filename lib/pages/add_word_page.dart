import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/word_types.dart';
import '../database/database_helper.dart';
import '../models/package.dart';
import '../models/word.dart';
import '../widgets/locale_text_form_field.dart';
import '../widgets/part_of_speech_picker.dart';

class AddWordPage extends StatefulWidget {
  final Package package;

  const AddWordPage({super.key, required this.package});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage> {
  final _formKey = GlobalKey<FormState>();
  final _englishController = TextEditingController();
  final _turkishController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sentenceController = TextEditingController();
  final _sentenceTrController = TextEditingController();
  final _synonymsController = TextEditingController();
  final _antonymsController = TextEditingController();
  final _otherFormsController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImage;
  Set<String> _selectedTypes = {};
  List<String> _extraTypes = [];

  List<String> _parseList(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadExtraTypes();
  }

  Future<void> _loadExtraTypes() async {
    final raw = await _databaseHelper.getDistinctPartsOfSpeech();
    final extras = <String>{};
    for (final r in raw) {
      for (final t in parseWordTypes(r)) {
        if (!kStandardWordTypes.contains(t)) extras.add(t);
      }
    }
    if (!mounted) return;
    setState(() => _extraTypes = extras.toList()..sort());
  }

  @override
  void dispose() {
    _englishController.dispose();
    _turkishController.dispose();
    _descriptionController.dispose();
    _sentenceController.dispose();
    _sentenceTrController.dispose();
    _synonymsController.dispose();
    _antonymsController.dispose();
    _otherFormsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final word = Word(
        packageId: widget.package.id!,
        englishWord: _englishController.text.trim(),
        turkishMeaning: _turkishController.text.trim(),
        partOfSpeech: _selectedTypes.isEmpty
            ? null
            : encodeWordTypes(_selectedTypes),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        imagePath: _selectedImage?.path,
        exampleSentence: _sentenceController.text.trim().isEmpty 
            ? null 
            : _sentenceController.text.trim(),
        exampleSentenceTr: _sentenceTrController.text.trim().isEmpty
            ? null
            : _sentenceTrController.text.trim(),
        synonyms: _parseList(_synonymsController.text),
        antonyms: _parseList(_antonymsController.text),
        otherForms: _parseList(_otherFormsController.text),
        createdAt: DateTime.now(),
      );

      await _databaseHelper.insertWord(word);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Word added successfully!'),
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
            content: Text('Error adding word: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add Word'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            ),
        ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                                'Adding word to this package',
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
                const SizedBox(height: 24),
                
                // Required Fields Section
                Text(
                  'Required Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                
                // English Word
                LocaleTextFormField.english(
                  controller: _englishController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'English Word *',
                    hintText: 'Enter English word',
                    prefixIcon: const Icon(Icons.language, color: Color(0xFF8DC71D)),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an English word';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Turkish Meaning
                LocaleTextFormField.turkish(
                  controller: _turkishController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Turkish Meaning *',
                    hintText: 'Enter Turkish meaning',
                    prefixIcon: const Icon(Icons.translate, color: Color(0xFF8DC71D)),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter Turkish meaning';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PartOfSpeechPicker(
                      selected: _selectedTypes,
                      extraTypes: _extraTypes,
                      onChanged: (next) => setState(() => _selectedTypes = next),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Optional Fields Section
                Text(
                  'Optional Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These fields are optional but helpful for learning',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                LocaleTextFormField.english(
                  controller: _sentenceController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Example sentence',
                    prefixIcon: Icon(Icons.format_quote, color: Color(0xFF8DC71D)),
                  ),
                ),
                const SizedBox(height: 16),
                LocaleTextFormField.turkish(
                  controller: _sentenceTrController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Example sentence (TR)',
                    prefixIcon: Icon(Icons.translate, color: Color(0xFF8DC71D)),
                  ),
                ),
                const SizedBox(height: 16),
                LocaleTextFormField.english(
                  controller: _synonymsController,
                  decoration: const InputDecoration(
                    labelText: 'Synonyms',
                    hintText: 'comma separated',
                    prefixIcon: Icon(Icons.sync_alt, color: Color(0xFF8DC71D)),
                  ),
                ),
                const SizedBox(height: 16),
                LocaleTextFormField.english(
                  controller: _antonymsController,
                  decoration: const InputDecoration(
                    labelText: 'Antonyms',
                    hintText: 'comma separated',
                    prefixIcon: Icon(Icons.compare_arrows, color: Color(0xFF8DC71D)),
                  ),
                ),
                const SizedBox(height: 16),
                LocaleTextFormField.english(
                  controller: _otherFormsController,
                  decoration: const InputDecoration(
                    labelText: 'Other forms',
                    hintText: 'Tempting (adj), ...',
                    prefixIcon: Icon(Icons.account_tree, color: Color(0xFF8DC71D)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Image Selection
                Card(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.image, color: const Color(0xFF8DC71D)),
                            const SizedBox(width: 8),
                            Text(
                              'Word Image (Optional)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedImage != null) ...[
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Change Image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF8DC71D),
                                    side: const BorderSide(color: Color(0xFF8DC71D)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _removeImage,
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Remove'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description / notes (typically Turkish)
                LocaleTextFormField.turkish(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add a note about the word',
                    prefixIcon: const Icon(Icons.description, color: Color(0xFF8DC71D)),
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
                ),
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveWord,
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
                        : const Text(
                            'Save Word',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 