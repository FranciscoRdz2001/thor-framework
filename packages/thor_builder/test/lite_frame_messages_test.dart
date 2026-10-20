// FrameMessages in the translator and the `frame_messages` part: a state
// listens to (and posts to) the parent window and an iframe with
// `postMessage`, only with explicit origins. The output runs on the real
// runtime under node with a fake window.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_lints/lite.dart';

Future<String> _translate(String source) async {
  final units = await resolveSources(
    {'app|lib/s.dart': source},
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units);
}

const _header = '''
import 'dart:convert';

import 'package:thor_ui/thor_ui.dart';

''';

// A window inside a parent, with one iframe (`canvas`) and a stranger.
const _page = r'''
globalThis.window = globalThis;
const winL = {};
globalThis.addEventListener = (t, f) => { (winL[t] ||= []).push(f); };
globalThis.removeEventListener = (t, f) => { winL[t] = (winL[t] || []).filter((x) => x !== f); };
const posted = [];
const parentWin = { postMessage: (m, o) => posted.push(['parent', m, o]) };
const frameWin = { postMessage: (m, o) => posted.push(['canvas', m, o]) };
const strangerWin = {};
globalThis.parent = parentWin;
globalThis.errs = [];
globalThis.reportError = (x) => globalThis.errs.push(x.message);
globalThis.MutationObserver = class { observe() {} };
const root = { innerHTML: '', addEventListener() {}, querySelectorAll: () => [] };
const iframe = { contentWindow: frameWin };
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: () => [], querySelector: () => null,
  getElementById: (id) => (id === 'canvas' ? iframe : null),
  getElementsByTagName: (t) => (t === 'iframe' ? [iframe] : []),
  addEventListener() {}, dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
const send = (data, origin, source) => (winL.message || []).slice().forEach((f) => f({ data, origin, source }));
''';

Map<String, Object?> _run(String js, String script) {
  final runtime = File('../thor_engine/lib/lite/runtime.js').readAsStringSync();
  final names =
      RegExp(
        r'^// thor-lite parts: (.*)$',
        multiLine: true,
      ).firstMatch(js)?.group(1)!.split(' ') ??
      const <String>[];
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      for (final p in names)
        p: File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: js,
    minify: false,
  );
  final program =
      '$_page$bundle\n(async () => {\nawait new Promise((r) => setTimeout(r, 0));\n'
      'const out = {};\n$script\nconsole.log(JSON.stringify(out));\nprocess.exit(0);\n})();';
  final r = Process.runSync('node', ['-e', program]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

const _state =
    '''
$_header
class CanvasViewModel extends ThorState {
  final zoom = state(1);
  final heard = state('');
  FrameSubscription? _sub;

  @override
  void onHydrated() {
    zoom.addListener(_tell);
    _sub = FrameMessages.listen(
      origins: ['https://preview.example.com', 'http://localhost:8080'],
      onMessage: _got,
    );
  }

  @override
  void dispose() => _sub?.cancel();

  void _tell() => FrameMessages.postToFrame(
    'canvas',
    jsonEncode({'type': 'zoom', 'zoom': zoom.value}),
    targetOrigin: 'https://preview.example.com',
  );

  void _got(String origin, String message) {
    final data = jsonDecode(message) as Map<String, Object?>;
    heard.value += '\$origin:\${data['type'] as String};';
  }

  void up() => zoom.value++;
  void ready() => FrameMessages.postToParent('{"type":"ready"}', targetOrigin: 'https://editor.example.com');
  void bad() => FrameMessages.postToParent('x', targetOrigin: '*');
  String text() => heard.value;
  void stop() => _sub?.cancel();
}
''';

void main() {
  test('a field change posts to the frame; messages come in only from '
      'listed origins and our own windows', () async {
    final js = await _translate(_state);
    expect(js, contains('frame_messages'));
    final out = _run(js, r'''
const S = thor.use('CanvasViewModel');
await new Promise((r) => setTimeout(r, 30));
S.up();
out.posted = posted.slice();
S.ready();
out.parent = posted[posted.length - 1];
// accepted: the iframe or the parent, from a listed origin, as text
send('{"type":"hover"}', 'https://preview.example.com', frameWin);
send('{"type":"clear"}', 'http://localhost:8080', parentWin);
// dropped: wrong origin, a window that is neither, an object, too big
send('{"type":"evil"}', 'https://evil.example', frameWin);
send('{"type":"evil2"}', 'https://preview.example.com', strangerWin);
send('{"type":"evil3"}', 'https://preview.example.com', null);
send({ type: 'obj' }, 'https://preview.example.com', frameWin);
send('"' + 'a'.repeat(1 << 20) + '"', 'https://preview.example.com', frameWin);
send('{"type":"prefix"}', 'https://preview.example.com.evil.example', frameWin);
out.heard = S.text();
// a bad message from an allowed sender is reported, the listener lives on
send('not json', 'https://preview.example.com', frameWin);
send('{"type":"after"}', 'https://preview.example.com', frameWin);
out.after = S.text();
out.errs = globalThis.errs.length;
// '*' is never accepted
try { S.bad(); out.star = null; } catch (e) { out.star = e.message; }
S.stop();
send('{"type":"late"}', 'https://preview.example.com', frameWin);
out.stopped = S.text() === out.after;
''');
    expect(out['posted'], [
      ['canvas', '{"type":"zoom","zoom":2}', 'https://preview.example.com'],
    ]);
    expect(out['parent'], [
      'parent',
      '{"type":"ready"}',
      'https://editor.example.com',
    ]);
    expect(
      out['heard'],
      'https://preview.example.com:hover;http://localhost:8080:clear;',
    );
    expect(
      out['after'],
      'https://preview.example.com:hover;http://localhost:8080:clear;'
      'https://preview.example.com:after;',
    );
    expect(out['errs'], 1);
    expect(out['star'], contains('THOR-S044'));
    expect(out['stopped'], isTrue);
  });

  test('listen with no origin or a wildcard throws in the page', () async {
    final js = await _translate('''
$_header
class WildViewModel extends ThorState {
  final n = state(0);
  void any() => FrameMessages.listen(origins: ['*'], onMessage: _got);
  void none() => FrameMessages.listen(origins: [], onMessage: _got);
  void nullOrigin() => FrameMessages.listen(origins: ['null'], onMessage: _got);
  void path() => FrameMessages.listen(origins: ['https://a.com/x'], onMessage: _got);
  void _got(String origin, String message) => n.value++;
}
''');
    final out = _run(js, r'''
const S = thor.use('WildViewModel');
for (const k of ['any', 'none', 'nullOrigin', 'path']) {
  try { S[k](); out[k] = null; } catch (e) { out[k] = e.message; }
}
''');
    for (final k in ['any', 'none', 'nullOrigin', 'path']) {
      expect(out[k], contains('THOR-S044'), reason: k);
    }
  });

  test(
    'a top-level page has no parent to post to, a missing frame is quiet',
    () async {
      final js = await _translate('''
$_header
class QuietViewModel extends ThorState {
  final n = state(0);
  void toParent() => FrameMessages.postToParent('x', targetOrigin: 'https://a.com');
  void toGhost() => FrameMessages.postToFrame('ghost', 'x', targetOrigin: 'https://a.com');
}
''');
      final out = _run(js, r'''
globalThis.parent = globalThis;
const S = thor.use('QuietViewModel');
S.toParent();
S.toGhost();
out.posted = posted.length;
''');
      expect(out['posted'], 0);
    },
  );
}
