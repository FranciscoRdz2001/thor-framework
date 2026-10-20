@TestOn('vm')
library;

// A control that follows a state field in the browser (`valueWatch`,
// `selectedWatch`): the binding sits on the control's own element, so a
// `local:` field the browser moves at load moves the control too.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _Members extends ThorState {
  @override
  String get $type => 'DeviceState';

  @override
  List<ThorMember> get $members {
    final s = this as DeviceState;
    return [
      ThorMember.state('device', s.device),
      ThorMember('deviceId', s.deviceId, call: (_) => s.deviceId()),
    ];
  }
}

class DeviceState extends _Members {
  final device = state('phone', local: 'device');

  String deviceId() => device.value;
}

final devices = DeviceState();

const _items = [
  DropdownMenuItem(value: 'phone', child: Text('Phone')),
  DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
];

void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  String body(String html) =>
      html.substring(html.indexOf('<body'), html.indexOf('</body>'));

  test('a DropdownButtonFormField binds its <select>', () async {
    final html = body(
      await page(
        DropdownButtonFormField<String>(
          initialValue: 'phone',
          items: _items,
          onChanged: null,
          decoration: const InputDecoration(labelText: 'Device'),
          valueWatch: devices.deviceId,
        ),
      ),
    );
    final select = RegExp(r'<select[^>]*>').firstMatch(html)![0]!;
    expect(select, contains('data-tca="value:DeviceState.deviceId"'));
    // `value` is not an attribute of a <select>: the option is selected.
    expect(select, isNot(contains(' value=')));
    // The server still draws the value it has.
    expect(html, contains('<option value="phone" selected>'));
  });

  test('a DropdownButton binds its <select> too', () async {
    final html = body(
      await page(
        DropdownButton<String>(
          semanticLabel: 'Device',
          value: 'phone',
          items: _items,
          onChanged: null,
          valueWatch: devices.deviceId,
        ),
      ),
    );
    expect(
      RegExp(r'<select[^>]*>').firstMatch(html)![0],
      contains('data-tca="value:DeviceState.deviceId"'),
    );
  });

  test('a SegmentedButton binds its radio group', () async {
    final html = body(
      await page(
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'phone', label: Text('Phone')),
            ButtonSegment(value: 'tablet', label: Text('Tablet')),
          ],
          selected: const {'phone'},
          selectedWatch: devices.deviceId,
        ),
      ),
    );
    final group = RegExp(r'<div[^>]*role="radiogroup"[^>]*>').firstMatch(html)!;
    expect(group[0], contains('data-tca="value:DeviceState.deviceId"'));
    // Nor of a radio group's <div>: the radio is checked.
    expect(group[0], isNot(contains(' value=')));
  });

  test('without it nothing is bound', () async {
    final html = await page(
      const DropdownButtonFormField<String>(
        initialValue: 'phone',
        items: _items,
        onChanged: null,
      ),
    );
    expect(html, isNot(contains('data-tca')));
  });
}
