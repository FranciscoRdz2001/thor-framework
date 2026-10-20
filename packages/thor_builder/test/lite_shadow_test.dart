// App names that are JS globals (`Date`, `Promise`, `document`…) must not
// shadow what the runtime and the translated code use: each construct runs
// as lite JS in node and prints what dart2js prints.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  test('an app class named like a JS global (Date, Promise, RegExp, Reflect) '
      'next to the code that needs the global', () async {
    await sameAsWeb(r"""
class Date {
  Date(this.day);
  final int day;
  String show() => 'day $day';
}
class Promise {
  Promise(this.value);
  final String value;
}
class Reflect {
  static String get() => 'reflect';
}
class Intl {
  const Intl();
  String get label => 'intl';
}
class TypeError {
  TypeError(this.m);
  final String m;
}
Future<String> t0() async {
  final d = Date(3);
  final p = Promise('p');
  // The order of completion (not of the list) shows what runs the delays.
  final log = <String>[];
  await Future.wait([
    Future.delayed(const Duration(milliseconds: 20), () => log.add('slow')),
    Future.delayed(const Duration(milliseconds: 2), () => log.add('fast')),
  ]);
  final now = DateTime(2020, 1, 2);
  final m = <String, int>{'a': 1};
  return '${d.show()} ${p.value} ${Reflect.get()} ${const Intl().label} ${TypeError('x').m} ${now.day} ${m['a']} ${log.join(',')} ${RegExp(r'\d+').firstMatch('ab12')![0]}';
}
""", 1);
  });

  test(
    'a top-level variable or function named like a global, and locals',
    () async {
      await sameAsWeb(r"""
int document = 4;
String window() => 'w';
List<int> setTimeout = [1, 2];
Future<String> t0() async {
  final location = 'loc';
  var Object = 5;
  final String JSON = 'j';
  Object++;
  await Future<void>.delayed(const Duration(milliseconds: 1));
  final jsonText = [1, 2].map((e) => e * 2).toList();
  return '$document ${window()} $setTimeout $location $Object $JSON $jsonText ${DateTime(2020, 5, 6).month}';
}
""", 1);
    },
  );

  test(
    'the emitted code never declares a global (browser: document, window)',
    () async {
      final js = await translate('''
$header
int document = 4;
class Date { const Date(); }
class CState extends ThorState {
  int get n => document + (const Date() == null ? 0 : 1);
}
''');
      expect(
        js,
        isNot(
          contains(
            RegExp(r'(let|const|class|function) (document|Date)(?![\w$])'),
          ),
        ),
      );
      expect(js, contains(r'document$'));
      expect(js, contains(r'Date$'));
    },
  );
}
