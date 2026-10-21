import '../widgets/theme.dart' show FontFace;

final _familyDecl = RegExp(r'font-family\s*:\s*([^;}]+)');
final _weightDecl = RegExp(r'font-weight\s*:\s*([^;}]+)');
final _italicDecl = RegExp(r'font-style\s*:\s*(?:italic|oblique)');
final _varRef = RegExp(r'var\(\s*(--[\w-]+)\s*(?:,\s*([^)]*))?\)');

/// The faces of [candidates] (among the theme's [faces]) that the
/// stylesheet [css] uses.
///
/// A face is used when its family is named by a `font-family` declaration
/// (a `var(--x)` is followed to the `--x:` declaration). When the family
/// has several faces, the face also needs a `font-weight` it covers (400
/// counts as always used: it is the text's default) and, for an italic
/// face, a `font-style: italic`. `// web:` a weight set only by the
/// browser's own styles (`<strong>`) is not seen: its face loads on first
/// use instead of being preloaded.
List<FontFace> usedFontFaces(
  List<FontFace> candidates,
  List<FontFace> faces,
  String css,
) {
  if (candidates.isEmpty) return const [];
  final variables = <String, String>{};
  for (final m in RegExp(r'(--[\w-]+)\s*:\s*([^;}]+)').allMatches(css)) {
    variables.putIfAbsent(m[1]!, () => m[2]!.trim());
  }
  String resolve(String value, [int depth = 0]) {
    if (depth > 4) return value;
    return value.replaceAllMapped(_varRef, (m) {
      final found = variables[m[1]!];
      return found != null ? resolve(found, depth + 1) : (m[2] ?? '');
    });
  }

  final families = <String>{};
  for (final m in _familyDecl.allMatches(css)) {
    for (final name in resolve(m[1]!).split(',')) {
      families.add(_normalize(name));
    }
  }
  final weights = <int>{400};
  for (final m in _weightDecl.allMatches(css)) {
    for (final w in resolve(m[1]!).split(RegExp(r'\s+'))) {
      switch (w.trim().toLowerCase()) {
        case 'normal':
          weights.add(400);
        case 'bold' || 'bolder':
          weights.add(700);
        case 'lighter':
          weights.add(300);
        case final n:
          if (int.tryParse(n) case final v?) weights.add(v);
      }
    }
  }
  final italic = _italicDecl.hasMatch(css);

  final sameFamily = <String, int>{};
  for (final f in faces) {
    sameFamily.update(_normalize(f.family), (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final f in candidates)
      if (families.contains(_normalize(f.family)) &&
          (sameFamily[_normalize(f.family)]! == 1 ||
              _covers(f, weights, italic)))
        f,
  ];
}

bool _covers(FontFace f, Set<int> weights, bool italic) {
  if (f.style.name != 'normal' && !italic) return false;
  final low = f.weight.value, high = f.maxWeight?.value ?? low;
  return weights.any((w) => w >= low && w <= high);
}

String _normalize(String name) =>
    name.trim().replaceAll(RegExp('^["\']|["\']\$'), '').toLowerCase();
