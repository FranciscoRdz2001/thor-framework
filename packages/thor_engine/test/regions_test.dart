import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  tearDown(() => PageRegion.handler = null);

  test('refresh hands the region id to the engine', () {
    final calls = <String>[];
    PageRegion.handler = calls.add;
    PageRegion.refresh('tracking');
    PageRegion.refresh('week.grid');
    expect(calls, ['tracking', 'week.grid']);
  });

  test('on the server, with no engine, refresh does nothing', () {
    expect(() => PageRegion.refresh('tracking'), returnsNormally);
  });
}
