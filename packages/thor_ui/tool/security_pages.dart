// The pages of the security battery (tool/thor e2e security): hostile text and
// URLs in every place a page writes data, rendered like a request would, and
// written as `security.html` in the directory given
// (`dart run tool/security_pages.dart <dir>`). The check loads it in a real
// browser and asserts nothing of it ran (`window.__pwned` stays unset), no
// element or attribute came out of a string, and the data survived as data.
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// Strings that break out of the place they are written in, if it is not
/// escaped for it: an attribute, an element, a script, a style, a comment.
/// Each one sets `window.__pwned` if it runs.
const hostileText = <String>[
  '"><img src=x onerror="window.__pwned=\'attribute\'">',
  "'><svg/onload=window.__pwned='svg'>",
  '</script><script>window.__pwned="script"</script>',
  '</style><script>window.__pwned="style"</script>',
  '<!--<script>window.__pwned="comment"</script>-->',
  '</textarea><script>window.__pwned="textarea"</script>',
  '  ',
  '&lt;b&gt; &#60;b&#62; &amp; &#x3c;',
  '{{key}} \$& %7E ~ ; __proto__ constructor',
];

/// URLs that run code (or navigate to something that does) when followed.
const hostileUrls = <String>[
  'javascript:window.__pwned="js"',
  'JaVaScRiPt:window.__pwned="js-case"',
  ' \tjavascript:window.__pwned="js-space"',
  'java\tscript:window.__pwned="js-tab"',
  'java\nscript:window.__pwned="js-newline"',
  '\u0001javascript:window.__pwned="js-control"',
  'vbscript:msgbox(1)',
  'data:text/html,<script>window.__pwned="data"</script>',
];

/// Content a user wrote, for `HtmlWidget` (the sanitizer): scripts, handlers,
/// code URLs, forms, frames, markup the parser mutates, and what would
/// forge the engine's own hooks (`data-t-on`, `#thor-state`, an id).
const hostileHtml = <String>[
  '<p>fine <b>bold</b></p><script>window.__pwned="html-script"</script>',
  '<img src=x onerror="window.__pwned=\'html-img\'">',
  '<a href="javascript:window.__pwned=\'html-js\'">click</a>',
  '<a href=" JaVa\tScRiPt:window.__pwned=\'html-js-tab\'">click</a>',
  '<svg><script>window.__pwned="html-svg"</script></svg>',
  '<math><mtext><table><mglyph><style><img src=x onerror="window.__pwned=\'mxss\'">',
  '<noscript><p title="</noscript><img src=x onerror=window.__pwned=\'noscript\'>">',
  '<form action="javascript:window.__pwned=\'html-form\'"><button>go</button></form>',
  '<iframe srcdoc="<script>window.parent.__pwned=\'html-frame\'</script>"></iframe>',
  '<div data-t-on="click:HostileState.pick" data-tx="forged" id="thor-state">forged hook</div>',
  '<script id="thor-state" type="application/json">{"HostileState.text":"forged"}</script>',
  '<p style="background:url(javascript:1)" class="x" onclick="window.__pwned=\'html-click\'">styled</p>',
  '<a href="https://example.com/x" target="_blank">out</a>',
];

/// The state a page ships as `#thor-state`: its initial values are the
/// hostile strings, so the JSON the server writes is one more place to break.
abstract class _HostileMembers extends ThorState {
  @override
  String get $type => 'HostileState';

  @override
  List<ThorMember> get $members {
    final s = this as HostileState;
    return [
      ThorMember.state('text', s.text),
      ThorMember.state('names', s.names),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'nameOf',
        s.nameOf,
        arity: 1,
        callWithItem: (i) => s.nameOf(i! as String),
      ),
      ThorMember('pick', s.pick, arity: 1, call: (a) => s.pick(a!)),
    ];
  }
}

class HostileState extends _HostileMembers {
  final text = state<String>('');
  final names = state<List<String>>(const []);
  String label() => text.value;
  String nameOf(String name) => name;
  void pick(String name) => text.value = name;
}

final hostile = HostileState();

class _SecurityPage extends StatelessWidget {
  const _SecurityPage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Text in an element, in a semantic label (an attribute), in a field.
      for (final (i, h) in hostileText.indexed)
        Container(
          key: ValueKey('case-$i'),
          child: Column(
            children: [
              Text(h),
              Semantics(label: h, child: Text('labelled $i')),
              TextField(
                name: 'f$i',
                controller: TextEditingController(text: h),
                decoration: InputDecoration(labelText: h, hintText: h),
              ),
              Link(href: RouteUrl('/page?q=$h'), child: Text('link $i')),
            ],
          ),
        ),
      // A URL that is not a path: every kind that runs code.
      for (final (i, u) in hostileUrls.indexed)
        Link(href: RouteUrl(u), child: Text('url $i')),
      // Content the sanitizer cleans.
      for (final (i, h) in hostileHtml.indexed)
        Container(key: ValueKey('html-$i'), child: HtmlWidget(h)),
      // State: the initial value in the markup and in `#thor-state`, a keyed
      // list whose keys are the hostile strings, a button that sends one.
      Watch(hostile.label),
      Watch.list(
        hostile.names,
        itemKey: hostile.nameOf,
        each: (row) => TextButton(
          onPressed: hostile.pick.withArg(row.key),
          child: row.text(hostile.nameOf),
        ),
      ),
    ],
  );
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/security_pages.dart <dir>');
    exit(64);
  }
  initializeThorTests();
  // Values that differ from the code's own: the page ships them as `#thor-state`.
  hostile.text.value = hostileText[3];
  hostile.names.value = [...hostileText, '__proto__', 'constructor', 'a~b'];
  final dir = Directory(args.single)..createSync(recursive: true);
  File('${dir.path}/security.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _SecurityPage())),
  );
}
