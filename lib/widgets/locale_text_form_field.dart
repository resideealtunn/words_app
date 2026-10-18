import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text form field that hints the soft-keyboard language (Android API 24+).
///
/// Does not wrap with [Localizations.override] — that breaks Material widgets
/// when Turkish locale delegates are missing ("No MaterialLocalizations found").
class LocaleTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final Locale inputLocale;

  const LocaleTextFormField({
    super.key,
    required this.inputLocale,
    this.controller,
    this.decoration,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onChanged,
    this.obscureText = false,
    this.inputFormatters,
  });

  const LocaleTextFormField.english({
    super.key,
    this.controller,
    this.decoration,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onChanged,
    this.obscureText = false,
    this.inputFormatters,
  }) : inputLocale = const Locale('en', 'US');

  const LocaleTextFormField.turkish({
    super.key,
    this.controller,
    this.decoration,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onChanged,
    this.obscureText = false,
    this.inputFormatters,
  }) : inputLocale = const Locale('tr', 'TR');

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: decoration,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onChanged: onChanged,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      hintLocales: [inputLocale],
    );
  }
}
