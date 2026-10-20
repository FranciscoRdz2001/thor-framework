/// The one-line description of a widget's API page, in the page's language.
///
/// `docs/api/widgets.json` is written from the English dartdoc of
/// `packages/`; a page in another language shows the translation of the
/// widgets listed in `docs/guia/<locale>/widget_summaries.json` (the most
/// visited ones) and, for a widget whose whole doc is the sentence
/// "Flutter's `X`.", that sentence translated (the file's `plain` template).
/// Anything else keeps the English text of the code until it is added.
/// A language is a file there: no Dart changes.
library;

import 'dart:convert';
import 'dart:io';

import 'library.dart' show docsDir;

/// The translation of [doc] (the widget [name]'s dartdoc) into [locale], or
/// [doc] itself when there is none.
String localizedWidgetDoc(String locale, String name, String doc) {
  final table = _table(locale);
  if (table == null) return doc;
  final own = table.summaries[name];
  if (own != null) return own;
  final plain = RegExp(r"^Flutter's `(\w+)`\.$").firstMatch(doc.trim());
  final template = table.plain;
  if (plain != null && template != null) {
    return template.replaceAll('{name}', plain[1]!);
  }
  return doc;
}

/// One language's file: the translated summaries by widget name, and the
/// template for a plain "Flutter's `X`." (`{name}` is the widget).
class _SummaryTable {
  const _SummaryTable(this.plain, this.summaries);

  final String? plain;
  final Map<String, String> summaries;
}

final _tables = <String, _SummaryTable?>{};

_SummaryTable? _table(String locale) => _tables.putIfAbsent(locale, () {
  final file = File('${docsDir()}/guia/$locale/widget_summaries.json');
  if (!file.existsSync()) return null;
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return _SummaryTable(
    json['plain'] as String?,
    (json['summaries'] as Map<String, Object?>? ?? const {}).cast(),
  );
});
