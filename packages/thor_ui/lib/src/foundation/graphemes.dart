/// How many user-perceived characters (extended grapheme clusters, UAX #29)
/// [text] has: what Flutter's `TextField.maxLength` counts and what
/// `Intl.Segmenter` counts in the browser. The common clusters: a base with
/// its combining marks, emoji with skin tones, variation selectors and ZWJ
/// sequences, regional-indicator pairs (flags), CRLF and tag sequences.
/// (Hangul syllable jamo and the Indic conjuncts of Unicode 15.1 are counted
/// by code point.) Not exported.
int graphemeCount(String text) {
  var count = 0;
  var joined = false; // after a ZWJ: the next symbol joins the cluster
  var regionalPending = false; // one regional indicator waiting for its pair
  int? previous;
  for (final r in text.runes) {
    final extend = _extendsCluster(r);
    final isRegional = r >= 0x1F1E6 && r <= 0x1F1FF;
    if (previous == 0x0D && r == 0x0A) {
      // CRLF is one.
    } else if (extend) {
      if (previous == null) count++;
    } else if (joined) {
      // The symbol after a zero-width joiner.
    } else if (isRegional && regionalPending) {
      regionalPending = false;
    } else {
      count++;
      regionalPending = isRegional;
    }
    if (!isRegional) regionalPending = false;
    joined = r == 0x200D && previous != null;
    previous = r;
  }
  return count;
}

final _marks = RegExp(r'\p{M}', unicode: true);

bool _extendsCluster(int r) =>
    r == 0x200D ||
    (r >= 0xFE00 && r <= 0xFE0F) || // variation selectors
    (r >= 0x1F3FB && r <= 0x1F3FF) || // emoji skin tones
    (r >= 0xE0020 && r <= 0xE007F) || // tag characters
    (r >= 0x0300 && _marks.hasMatch(String.fromCharCode(r)));
