import 'package:dart_style/dart_style.dart';

/// [source] formatted like `dart format` (generated files pass the format
/// check and read like hand-written code).
String formatDart(String source) => DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
).format(source);
