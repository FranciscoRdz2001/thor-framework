/// What `thor dev` says when the engine of the page did not build: the page
/// keeps being served, so without this nobody would see that every button
/// and every validation does nothing.
class EngineFailure {
  EngineFailure._(this.title, this.detail, this.code, this.banner);

  /// The title of the overlay: what failed and what the page does now.
  final String title;

  /// Lines `file:line:col: Error: message (THOR-B012 · url) fix` (or the
  /// whole report when it has no such line): what the overlay lists.
  final String detail;

  /// The first THOR code of the report (`THOR-B012`), if it has one.
  final String? code;

  /// The prominent line of the terminal.
  final String banner;

  /// The failure of the engine [name] (`lite engine`, `engine`) whose
  /// builder said [message]. [stale]: an older build of it is still served.
  factory EngineFailure.of(String name, String message, {required bool stale}) {
    final code = _code.firstMatch(message);
    final found = <String>[];
    var at = -1;
    final fixes = <int, String>{};
    for (final raw in message.split('\n')) {
      final line = raw.trim();
      if (_construct.firstMatch(line) case final m?) {
        found.add('${m[1]}:${m[2]}:${m[3]}: Error: ${m[4]}');
        at = found.length - 1;
      } else if (line.startsWith('fix: ') && at >= 0) {
        fixes[at] = line.substring(5).trim();
      }
    }
    final mark = code == null ? '' : ' (${code[1]} · ${code[2]})';
    final detail = found.isEmpty
        ? _cut(message)
        : _cut(
            [
              for (var i = 0; i < found.length; i++)
                '${found[i]}$mark${fixes[i] == null ? '' : ' ${fixes[i]}'}',
            ].join('\n'),
          );
    final effect = stale
        ? 'this page runs an OUTDATED engine (the last good build)'
        : 'this page runs WITHOUT its engine (interactivity disabled)';
    return EngineFailure._(
      'The $name did not build: $effect',
      detail,
      code?[1],
      '══ ENGINE BUILD FAILED${code == null ? '' : ' · ${code[1]}'} · '
          '$effect ══',
    );
  }

  /// The most the page carries of a report: every page would repeat a
  /// compiler's megabytes (the terminal has them all). Never empty.
  static String _cut(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      return 'The builder failed and said nothing (see the terminal).';
    }
    if (t.length <= _maxDetail) return t;
    return '${t.substring(0, _maxDetail)}\n… (${t.length - _maxDetail} more '
        'characters: the terminal has the whole report)';
  }

  static const _maxDetail = 8000;

  // `lib/a.dart:14:22: message` (not a line that already says Error:).
  static final _construct = RegExp(
    r'^((?:(?!: ).)+?\.dart):(\d+):(\d+): (?!(?:Error|Warning): )(.+)$',
  );
  static final _code = RegExp(r'\((THOR-[A-Z]\d{3}) · (https?://\S+)\)');
}
