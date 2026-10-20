@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Session], by hand.
abstract class _SessionMembers extends ThorState {
  @override
  String get $type => 'Session';

  @override
  List<ThorMember> get $members {
    final s = this as _Session;
    return [
      ThorMember.state('user', s.user),
      ThorMember('greeting', s.greeting, call: (_) => s.greeting()),
    ];
  }
}

class _Session extends _SessionMembers {
  final user = state('nobody');
  String greeting() => 'Hello ${user.value}';
}

final _session = _Session();

void main() {
  initializeThorTests();

  test('a page writes its signals in its own scope: the next page and the '
      'process never see them', () async {
    Future<String> page(String user) => renderDocument(
      Builder(
        builder: (context) {
          _session.user.value = user;
          return Watch(_session.greeting);
        },
      ),
    );

    final pages = await Future.wait([page('ana'), page('beto')]);
    expect(pages[0], contains('Hello ana'));
    expect(pages[0], isNot(contains('beto')));
    expect(pages[1], contains('Hello beto'));
    expect(_session.user.peek(), 'nobody');
    // A page that doesn't write reads the code's value, not the last page's.
    expect(
      await renderDocument(Watch(_session.greeting)),
      contains('Hello nobody'),
    );
  });
}
