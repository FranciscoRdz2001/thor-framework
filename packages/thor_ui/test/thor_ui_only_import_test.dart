// A reusable widget imports only `package:thor_ui/thor_ui.dart`:
// `withArg` on a page action must pick the page extension (the request stays
// first), `withArg` on a state method the state one, and `HiddenField` is
// there too. The router library is imported with `show`, so it brings none of
// the extensions: what these shapes need must come from thor_ui.dart. A
// compile error here is the bug ("String can't be assigned to PageRequest").
import 'package:test/test.dart';
import 'package:thor_ui/router.dart'
    as r
    show ActionResult, HttpMethod, PageRequest;
import 'package:thor_ui/thor_ui.dart';

final _log = <String>[];

class _CartState extends ThorState {
  void one(String sku) => _log.add('one $sku');
  void two(int n, String sku) => _log.add('two $n $sku');
  void three(int n, String a, bool b) => _log.add('three $n $a $b');
  Future<void> async(String sku) async => _log.add('async $sku');
}

class _Actions {
  const _Actions();

  Future<r.ActionResult?> one(r.PageRequest request, String sku) async {
    _log.add('page one $sku');
    return null;
  }

  Future<r.ActionResult?> two(r.PageRequest request, int n, String sku) async {
    _log.add('page two $n $sku');
    return null;
  }

  Future<r.ActionResult?> three(
    r.PageRequest request,
    int n,
    String a,
    bool b,
  ) async {
    _log.add('page three $n $a $b');
    return null;
  }
}

/// What the reusable widget writes: both shapes side by side.
Widget _card(_CartState state, _Actions actions) => Column(
  children: [
    FilledButton(onPressed: state.one.withArg('a'), child: const Text('s1')),
    FilledButton(
      onPressed: state.two.withArgs(1, 'a'),
      child: const Text('s2'),
    ),
    FilledButton(
      onPressed: state.three.withArgs(1, 'a', true),
      child: const Text('s3'),
    ),
    FilledButton(onPressed: state.async.withArg('a'), child: const Text('s4')),
    FilledButton(onPost: actions.one.withArg('a'), child: const Text('p1')),
    FilledButton(onPost: actions.two.withArgs(1, 'a'), child: const Text('p2')),
    FilledButton(
      onPost: actions.three.withArgs(1, 'a', true),
      child: const Text('p3'),
    ),
    const HiddenField(name: 'id', value: '7'),
  ],
);

void main() {
  test('both shapes compile and bind the right extension', () async {
    expect(_card(_CartState(), const _Actions()), isA<Widget>());
    final request = r.PageRequest(
      method: r.HttpMethod.post,
      uri: Uri.parse('http://s.test/'),
      headers: const {},
    );
    const actions = _Actions();
    await actions.one.withArg('x')(request);
    await actions.two.withArgs(2, 'y')(request);
    await actions.three.withArgs(3, 'z', false)(request);
    final state = _CartState();
    state.one.withArg('x')();
    state.two.withArgs(2, 'y')();
    expect(_log, [
      'page one x',
      'page two 2 y',
      'page three 3 z false',
      'one x',
      'two 2 y',
    ]);
  });
}
