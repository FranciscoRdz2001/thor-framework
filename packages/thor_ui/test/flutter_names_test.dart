import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _Greeting extends InheritedWidget {
  const _Greeting({required this.text, required super.child});

  final String text;

  @override
  bool updateShouldNotify(_Greeting oldWidget) => text != oldWidget.text;
}

class _Hello extends StatelessWidget implements ThorElementWidget {
  const _Hello();

  @override
  Widget build(BuildContext context) => Text(
    context.dependOnInheritedWidgetOfExactType<_Greeting>()?.text ?? 'none',
  );
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  final int count = 3;

  @override
  Widget build(BuildContext context) => Text('count $count');
}

void main() {
  initializeThorTests();

  test('the widget model works under Flutter names', () async {
    final html = await renderHtml(
      const Column(
        children: [
          _Greeting(text: 'hello', child: _Hello()),
          _Counter(),
        ],
      ),
    );
    expect(html, contains('hello'));
    expect(html, contains('count 3'));
  });
}
