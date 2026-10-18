import 'dart:io';

import 'package:flutter/material.dart';

import '../models/word.dart';

/// Rich word detail dialog used by list / study-later screens.
class WordDetailSheet extends StatelessWidget {
  final Word word;
  final String? packageName;
  final VoidCallback? onToggleStudyLater;
  final VoidCallback? onMarkLearned;
  final VoidCallback? onClose;

  const WordDetailSheet({
    super.key,
    required this.word,
    this.packageName,
    this.onToggleStudyLater,
    this.onMarkLearned,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8DC71D), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (packageName != null && packageName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          packageName!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    _block(
                      label: 'English',
                      value: word.englishWord,
                      icon: Icons.language,
                      accent: const Color(0xFF8DC71D),
                      trailing: word.partOfSpeech != null &&
                              word.partOfSpeech!.isNotEmpty
                          ? _chip(word.partOfSpeech!)
                          : null,
                      large: true,
                    ),
                    const SizedBox(height: 12),
                    _block(
                      label: 'Turkish',
                      value: word.turkishMeaning,
                      icon: Icons.translate,
                      accent: Colors.red[300]!,
                      large: true,
                    ),
                    if (word.exampleSentence != null &&
                        word.exampleSentence!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _block(
                        label: 'Example',
                        value: word.exampleSentence!,
                        icon: Icons.format_quote,
                        accent: Colors.orange[300]!,
                      ),
                    ],
                    if (word.exampleSentenceTr != null &&
                        word.exampleSentenceTr!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _block(
                        label: 'Example (TR)',
                        value: word.exampleSentenceTr!,
                        icon: Icons.translate,
                        accent: Colors.amber[200]!,
                      ),
                    ],
                    if (word.synonyms.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _listBlock(
                        label: 'Synonyms',
                        items: word.synonyms,
                        icon: Icons.sync_alt,
                        color: Colors.tealAccent,
                      ),
                    ],
                    if (word.antonyms.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _listBlock(
                        label: 'Antonyms',
                        items: word.antonyms,
                        icon: Icons.compare_arrows,
                        color: Colors.pinkAccent,
                      ),
                    ],
                    if (word.otherForms.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _listBlock(
                        label: 'Other forms',
                        items: word.otherForms,
                        icon: Icons.account_tree,
                        color: Colors.lightBlueAccent,
                      ),
                    ],
                    if (word.description != null &&
                        word.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _block(
                        label: 'Notes',
                        value: word.description!,
                        icon: Icons.notes,
                        accent: Colors.blue[300]!,
                      ),
                    ],
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
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (word.studyLater)
                          _chip('Study later', color: Colors.amber),
                        if (word.isLearned)
                          _chip('Learned', color: const Color(0xFF8DC71D)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onToggleStudyLater != null || onMarkLearned != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (onToggleStudyLater != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onToggleStudyLater,
                          icon: Icon(
                            word.studyLater
                                ? Icons.bookmark_remove
                                : Icons.bookmark_add,
                            color: Colors.amber,
                          ),
                          label: Text(
                            word.studyLater
                                ? 'Remove from study'
                                : 'Study later',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                    if (onToggleStudyLater != null && onMarkLearned != null)
                      const SizedBox(width: 8),
                    if (onMarkLearned != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onMarkLearned,
                          icon: const Icon(Icons.check),
                          label: const Text('Learned'),
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

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF8DC71D).withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Color(0xFF8DC71D)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Word Details',
              style: TextStyle(
                color: Color(0xFF8DC71D),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF8DC71D)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {Color color = const Color(0xFF8DC71D)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _block({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    Widget? trailing,
    bool large = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[400], size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: large ? 22 : 16,
              fontWeight: large ? FontWeight.bold : FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listBlock({
    required String label,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[400], size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => _chip(item, color: color)).toList(),
          ),
        ],
      ),
    );
  }
}
