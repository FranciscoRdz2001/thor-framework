import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  tearDown(() {
    PageNavigator.handler = null;
    PageNavigator.popHandler = null;
    PageNavigator.canPopHandler = null;
    PageNavigator.reloadHandler = null;
  });

  test('go hands the location to the engine, with replace', () {
    final calls = <String>[];
    PageNavigator.handler = (location, replace) =>
        calls.add('${replace ? 'replace' : 'assign'} $location');
    PageNavigator.go('/article/a?x=1:2');
    PageNavigator.go('https://example.test/', replace: true);
    PageNavigator.go('');
    expect(calls, [
      'assign /article/a?x=1:2',
      'replace https://example.test/',
      'assign ',
    ]);
  });

  test('go leaves a flash for the next page before it navigates', () {
    final calls = <String>[];
    PageNavigator.flashHandler = (message, kind) =>
        calls.add('flash ${kind.name} $message');
    PageNavigator.handler = (location, replace) => calls.add('go $location');
    addTearDown(() => PageNavigator.flashHandler = null);
    PageNavigator.go('/a', flash: 'Saved', flashKind: ToastKind.success);
    PageNavigator.go('/b', flash: 'Note');
    PageNavigator.go('/c');
    PageNavigator.go('/d', flash: '  ');
    expect(calls, [
      'flash success Saved',
      'go /a',
      'flash info Note',
      'go /b',
      'go /c',
      'go /d',
    ]);
    // An unsafe location leaves no flash behind.
    calls.clear();
    expect(
      () => PageNavigator.go('javascript:x', flash: 'No'),
      throwsA(isA<ArgumentError>()),
    );
    expect(calls, isEmpty);
  });

  test('on the server (no engine) it does nothing', () {
    expect(() => PageNavigator.go('/x'), returnsNormally);
    expect(PageNavigator.pop, returnsNormally);
    expect(PageNavigator.reload, returnsNormally);
    expect(PageNavigator.canPop(), isFalse);
  });

  test('pop hands the fallback to the engine, canPop asks it', () {
    final calls = <String>[];
    var can = false;
    PageNavigator.popHandler = calls.add;
    PageNavigator.canPopHandler = () => can;
    expect(PageNavigator.canPop(), isFalse);
    PageNavigator.pop();
    PageNavigator.pop(fallback: '/home');
    can = true;
    expect(PageNavigator.canPop(), isTrue);
    expect(calls, ['/', '/home']);
  });

  test('pop refuses an unsafe fallback (THOR-S008)', () {
    PageNavigator.popHandler = (_) {};
    expect(
      () => PageNavigator.pop(fallback: 'javascript:alert(1)'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('reload hands over to the engine', () {
    var n = 0;
    PageNavigator.reloadHandler = () => n++;
    PageNavigator.reload();
    expect(n, 1);
  });

  test('only relative, http: and https: locations (THOR-S008)', () {
    final calls = <String>[];
    PageNavigator.handler = (location, _) => calls.add(location);
    for (final bad in [
      'javascript:alert(1)',
      'JavaScript:alert(1)',
      ' java\tscript:alert(1)',
      'java\nscript:alert(1)',
      'data:text/html,<script>x</script>',
      'vbscript:x',
      'x:y',
    ]) {
      expect(
        () => PageNavigator.go(bad),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '$e',
            'message',
            contains('THOR-S008'),
          ),
        ),
        reason: bad,
      );
    }
    for (final ok in [
      'a/b:c',
      '?q=a:b',
      '#x:y',
      '//cdn.test/x',
      'HTTPS://x.test',
      'http://x.test',
    ]) {
      expect(PageNavigator.isNavigable(ok), isTrue, reason: ok);
    }
    expect(calls, isEmpty);
  });
}
