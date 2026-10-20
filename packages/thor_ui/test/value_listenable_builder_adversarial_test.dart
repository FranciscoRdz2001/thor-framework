@TestOn('vm')
library;

// Adversarial: `ValueListenableBuilder` where it is pushed: a nullable
// bool (a value with no variant), an enum with many values, a signal of
// another state, one builder inside another, and the error text.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Big {
  v00,
  v01,
  v02,
  v03,
  v04,
  v05,
  v06,
  v07,
  v08,
  v09,
  v10,
  v11,
  v12,
  v13,
  v14,
  v15,
  v16,
  v17,
  v18,
  v19,
  v20,
  v21,
  v22,
  v23,
  v24,
  v25,
  v26,
  v27,
  v28,
  v29,
  v30,
  v31,
  v32,
  v33,
  v34,
  v35,
  v36,
  v37,
  v38,
  v39,
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'Panel';

  @override
  List<ThorMember> get $members {
    final s = this as Panel;
    return [
      ThorMember.state('open', s.open, variants: const [false, true]),
      ThorMember.state('big', s.big, variants: Big.values),
      ThorMember.state('maybe', s.maybe),
      ThorMember.state('bigOrNull', s.bigOrNull),
      ThorMember.state('countOrNull', s.countOrNull),
      ThorMember.state('count', s.count),
    ];
  }
}

class Panel extends _Members {
  final open = state(false);
  final big = state(Big.v00);
  final maybe = state<bool?>(null);
  final bigOrNull = state<Big?>(null);
  final countOrNull = state<int?>(null);
  final count = state(3);
}

final panel = Panel();

void main() {
  initializeThorTests();

  test('an enum with 40 values renders 40 variants, not one per state '
      'instance', () async {
    final html = await renderHtml(
      ValueListenableBuilder<Big>(
        valueListenable: panel.big,
        builder: (context, v, child) => Text(v.name),
      ),
    );
    expect(html, contains('data-tv="Panel.big"'));
    for (final v in Big.values) {
      expect(html, contains(v.name));
    }
  });

  test(
    'a builder inside another builder, both on fields of the same state',
    () async {
      final html = await renderHtml(
        ValueListenableBuilder<bool>(
          valueListenable: panel.open,
          builder: (context, open, _) => ValueListenableBuilder<Big>(
            valueListenable: panel.big,
            builder: (context, big, _) =>
                Text('${open ? "on" : "off"}-${big.name}'),
          ),
        ),
      );
      expect(html, contains('data-tv="Panel.open"'));
      expect(html, contains('data-tv="Panel.big"'));
    },
  );

  test('a nullable bool or enum field is THOR-S013 and says why (null has '
      'no variant to show)', () async {
    Future<String> failure(Widget w) async {
      try {
        await renderHtml(w);
      } on ArgumentError catch (e) {
        return '${e.message}';
      }
      fail('expected an ArgumentError');
    }

    final bool_ = await failure(
      ValueListenableBuilder<bool?>(
        valueListenable: panel.maybe,
        builder: (context, v, child) => Text('v=$v'),
      ),
    );
    expect(bool_, contains('THOR-S013'));
    expect(bool_, contains('can be null'));
    expect(bool_, contains('non-null'));
    final enum_ = await failure(
      ValueListenableBuilder<Big?>(
        valueListenable: panel.bigOrNull,
        builder: (context, v, child) => Text('v=$v'),
      ),
    );
    expect(enum_, contains('can be null'));
    // and an int? keeps the int advice, not the null one
    final int_ = await failure(
      ValueListenableBuilder<int?>(
        valueListenable: panel.countOrNull,
        builder: (context, v, child) => Text('v=$v'),
      ),
    );
    expect(int_, contains('unbounded'));
    expect(int_, contains('count:'));
  });
}
