// GeolocationRequest and ShareRequest reach the browser as data attributes
// on their child's element (the lite parts `geolocation` and `share` read
// them).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _NearbyMembers extends ThorState {
  @override
  String get $type => 'Nearby';

  @override
  List<ThorMember> get $members {
    final s = this as _Nearby;
    return [
      ThorMember(
        'found',
        s.found,
        arity: 3,
        call: (a) {
          final x = splitArgs(a, 3);
          return s.found(
            double.parse(x[0]),
            double.parse(x[1]),
            double.parse(x[2]),
          );
        },
      ),
      ThorMember('failed', s.failed, arity: 1, call: (a) => s.failed(a!)),
      ThorMember('shared', s.shared, arity: 1, call: (a) => s.shared(a!)),
    ];
  }
}

class _Nearby extends _NearbyMembers {
  void found(double latitude, double longitude, double accuracy) {}
  void failed(String reason) {}
  void shared(String result) {}
}

final _nearby = _Nearby();

Widget _button(String label) =>
    TextButton(onPressed: () {}, child: Text(label));

void main() {
  initializeThorTests();

  test(
    'GeolocationRequest marks its child with handlers and options',
    () async {
      final html = await renderHtml(
        GeolocationRequest(
          onPosition: _nearby.found,
          onError: _nearby.failed,
          highAccuracy: true,
          timeout: const Duration(seconds: 5),
          maximumAge: const Duration(minutes: 1),
          child: _button('Near me'),
        ),
      );
      expect(RegExp('<button').allMatches(html), hasLength(1));
      expect(html, contains('data-t-geo="ok:Nearby.found;err:Nearby.failed"'));
      expect(html, contains('data-t-geo-o="1|5000|60000"'));
      expect(html, isNot(contains(RegExp(r'<button[^>]* disabled'))));
    },
  );

  test('a GeolocationRequest with no listener marks nothing', () async {
    final html = await renderHtml(GeolocationRequest(child: _button('x')));
    expect(html, isNot(contains('data-t-geo')));
  });

  test(
    'ShareRequest carries what it shares and who hears the result',
    () async {
      final html = await renderHtml(
        ShareRequest(
          title: 'Tacos',
          text: 'The best "tacos"',
          url: '/places/tacos',
          onResult: _nearby.shared,
          child: _button('Share'),
        ),
      );
      expect(html, contains('data-t-share="result:Nearby.shared"'));
      expect(html, contains('data-t-share-d='));
      expect(html, contains('&quot;url&quot;:&quot;/places/tacos&quot;'));
      expect(html, contains('&quot;title&quot;:&quot;Tacos&quot;'));
    },
  );

  test(
    'a ShareRequest with no url or listener still marks the child',
    () async {
      final html = await renderHtml(ShareRequest(child: _button('Share')));
      expect(html, contains('data-t-share-d="{}"'));
      expect(html, isNot(contains('data-t-share="')));
    },
  );
}
