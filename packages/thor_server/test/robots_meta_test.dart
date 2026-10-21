@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  test('noindex leaves the default follow out', () {
    expect(RobotsMeta.noindex.content, 'noindex');
  });

  test('noindexFollow and explicitFollow write follow', () {
    expect(RobotsMeta.noindexFollow.content, 'noindex, follow');
    expect(
      const RobotsMeta(index: false, explicitFollow: true).content,
      'noindex, follow',
    );
  });

  test('nofollow wins over explicitFollow', () {
    expect(
      const RobotsMeta(
        index: false,
        follow: false,
        explicitFollow: true,
      ).content,
      'noindex, nofollow',
    );
  });

  test('parse keeps an explicit follow', () {
    expect(RobotsMeta.parse('noindex, follow').content, 'noindex, follow');
    expect(RobotsMeta.parse('noindex').content, 'noindex');
    expect(
      RobotsMeta.parse('noindex, follow').copyWith(index: true).content,
      'index, follow',
    );
  });
}
