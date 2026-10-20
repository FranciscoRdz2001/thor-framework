import 'package:thor_ui/thor_ui.dart';

import '../ui.dart';

/// `.form-control` of the theme (`.form-control-lg` with [large]) inside a
/// `fieldset.form-group`.
Widget formField({
  required String name,
  required String hint,
  bool large = false,
  String? initialValue,
  bool obscure = false,
  int lines = 1,
  TextInputType keyboard = TextInputType.text,
  bool required = false,
  Map<String, String> attributes = const {},
}) {
  final radius = BorderRadius.circular(large ? 10 : 8);
  return cls(
    'form-group',
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        name: name,
        initialValue: initialValue,
        obscureText: obscure,
        maxLines: lines,
        keyboardType: keyboard,
        inputAttributes: HtmlAttributes.custom({
          'class': large ? 'form-control form-control-lg' : 'form-control',
          if (required) 'required': '',
          ...attributes,
        }),
        style: TextStyle(
          fontSize: large ? 20 : 16,
          height: 1.25,
          color: const Color(0xFF55595C),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: muted),
          filled: true,
          fillColor: white,
          contentPadding: large
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: brand),
          ),
        ),
      ),
    ),
  );
}
