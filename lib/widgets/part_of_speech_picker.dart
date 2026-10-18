import 'package:flutter/material.dart';

import '../constants/word_types.dart';

/// Checkbox grid for selecting one or more word types.
class PartOfSpeechPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final List<String>? extraTypes;

  const PartOfSpeechPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.extraTypes,
  });

  @override
  Widget build(BuildContext context) {
    final options = <String>[
      ...kStandardWordTypes,
      ...?extraTypes?.where((t) => !kStandardWordTypes.contains(t)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Part of speech',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: options.map((type) {
            final label = kWordTypeLabels[type] ?? type;
            final isOn = selected.contains(type);
            return FilterChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: isOn,
              onSelected: (value) {
                final next = Set<String>.from(selected);
                if (value) {
                  next.add(type);
                } else {
                  next.remove(type);
                }
                onChanged(next);
              },
              selectedColor: const Color(0xFF8DC71D).withValues(alpha: 0.35),
              checkmarkColor: Colors.black,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Dropdown of types present in data (+ All).
class PartOfSpeechFilterDropdown extends StatelessWidget {
  final String? value;
  final List<String> availableTypes;
  final ValueChanged<String?> onChanged;
  final bool dark;

  const PartOfSpeechFilterDropdown({
    super.key,
    required this.value,
    required this.availableTypes,
    required this.onChanged,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All types')),
      ...availableTypes.map(
        (t) => DropdownMenuItem(
          value: t,
          child: Text(kWordTypeLabels[t] ?? t),
        ),
      ),
    ];

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value ?? 'all',
        dropdownColor: dark ? Colors.grey[900] : null,
        style: TextStyle(
          color: dark ? const Color(0xFF8DC71D) : Colors.black87,
          fontSize: 14,
        ),
        icon: Icon(
          Icons.arrow_drop_down,
          color: dark ? const Color(0xFF8DC71D) : Colors.grey[700],
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
