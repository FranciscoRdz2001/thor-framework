// Writes the lite bundle of an app whose names shadow JS globals (`Date`,
// `Promise`, a top-level `document`), for the browser check
// test/e2e/checks/lite_shadow_check.mjs (the node oracle of
// lite_shadow_test.dart cannot catch what only a browser has: a `document`
// the page already owns). `dart run test/lite_shadow_dump.dart <out.js>`.
import 'dart:io';

import 'package:thor_engine/src/lite_bundle.dart';

import 'lite_oracle.dart';

Future<void> main(List<String> args) async {
  final js = await translate(r'''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';


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

int document = 4;
String window() => 'w';
List<int> setTimeout = [1, 2];

class ShadowState extends ThorState {
  Future<String> run() async {
    final d = Date(3);
    final p = Promise('p');
    final location = 'loc';
    var Object = 5;
    Object++;
    final log = <String>[];
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 30), () => log.add('slow')),
      Future.delayed(const Duration(milliseconds: 2), () => log.add('fast')),
    ]);
    return '${d.show()} ${p.value} ${Reflect.get()} $document ${window()} $setTimeout $location $Object ${log.join(',')} ${DateTime(2020, 5, 6).month}';
  }
}
''');
  const lite = '../thor_engine/lib/lite';
  final names = litePartsFor(stateJs: js, engineEntry: '');
  File(args.single).writeAsStringSync(
    liteBundle(
      runtime: File('$lite/runtime.js').readAsStringSync(),
      parts: {
        for (final n in names) n: File('$lite/parts/$n.js').readAsStringSync(),
      },
      stateJs: js,
      minify: false,
    ),
  );
}
