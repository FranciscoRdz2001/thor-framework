// The data classes of another workspace package that `events<T>`, `query`
// and `command` send to the browser come with their source, like the ones a
// `state<T>` holds: the package's libraries they import come too, and the
// classes they hold in other packages.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_builder/src/app_steps.dart';

const _event = '''
import 'node.dart';

class SessionEvent {
  const SessionEvent(this.kind, this.node);
  factory SessionEvent.fromJson(Map<String, Object?> j) => SessionEvent(
    j['k']! as String,
    NodeRef.fromJson(j['n']! as Map<String, Object?>),
  );
  final String kind;
  final NodeRef node;
  Map<String, Object?> toJson() => {'k': kind, 'n': node.toJson()};
  String label() => '\$kind:\${node.id}';
}
''';

const _node = '''
import 'package:other_models/stamp.dart';

class NodeRef {
  const NodeRef(this.id, [this.stamp = const Stamp(0)]);
  factory NodeRef.fromJson(Map<String, Object?> j) =>
      NodeRef(j['id']! as String, Stamp.fromJson(j['s']! as Map<String, Object?>));
  final String id;
  final Stamp stamp;
  Map<String, Object?> toJson() => {'id': id, 's': stamp.toJson()};
}
''';

const _stamp = '''
class Stamp {
  const Stamp(this.at);
  factory Stamp.fromJson(Map<String, Object?> j) => Stamp(j['a']! as int);
  final int at;
  Map<String, Object?> toJson() => {'a': at};
}
''';

const _state = '''
import 'package:shared_models/event.dart';
import 'package:shared_models/node.dart';
import 'package:thor_ui/thor_ui.dart';

Future<List<NodeRef>> nodesOf(NodeRef root) async => [root];
Future<NodeRef> touch(NodeRef n) async => n;

class LiveState extends ThorState {
  final feed = events<SessionEvent>('/s/events');
  final nodes = queryWith(nodesOf, arg: const NodeRef('root'));
  final touched = commandWith(touch);

  String last() => feed.data.value?.label() ?? '';
  String first() => nodes.data.value?.first.id ?? '';
}
''';

void main() {
  test(
    'writeLiteStates adds the packages of the classes the wire carries',
    () async {
      final lib = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_builder/src/app_steps.dart'),
      );
      final builder = p.normalize(
        p.join(p.dirname(lib!.toFilePath()), '..', '..'),
      );
      final checkout = p.dirname(p.dirname(builder));
      final tmp = Directory.systemTemp.createTempSync('thor_workspace_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final root = tmp.resolveSymbolicLinksSync();
      final app = p.join(root, 'app');
      final shared = p.join(root, 'shared_models');
      final other = p.join(root, 'other_models');
      final config =
          jsonDecode(
                File(
                  p.join(checkout, '.dart_tool', 'package_config.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final base = Uri.directory(p.join(checkout, '.dart_tool'));
      final packages = [
        for (final package
            in (config['packages']! as List).cast<Map<String, Object?>>())
          {
            ...package,
            'rootUri': '${base.resolve(package['rootUri']! as String)}',
          },
        for (final (name, dir) in [
          ('app', app),
          ('shared_models', shared),
          ('other_models', other),
        ])
          {
            'name': name,
            'rootUri': '${Uri.directory(dir)}',
            'packageUri': 'lib/',
            'languageVersion': '3.8',
          },
      ];
      File(p.join(app, '.dart_tool', 'package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({...config, 'packages': packages}));
      File(
        p.join(app, 'pubspec.yaml'),
      ).writeAsStringSync('name: app\nenvironment:\n  sdk: ^3.10.0\n');
      for (final (path, source) in [
        (p.join(app, 'lib', 's.dart'), _state),
        (p.join(shared, 'lib', 'event.dart'), _event),
        (p.join(shared, 'lib', 'node.dart'), _node),
        (p.join(other, 'lib', 'stamp.dart'), _stamp),
      ]) {
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync(source);
      }

      final out = StringBuffer(), err = StringBuffer();
      final outPath = p.join(app, 'build', 'state.js');
      final code = await writeLiteStates(
        app,
        outPath: outPath,
        readable: true,
        out: out,
        err: err,
      );
      expect(code, 0, reason: '$err');
      final js = File(outPath).readAsStringSync();
      // The event, the node it holds (another library) and the stamp the
      // node holds (another package) are decoded in the browser.
      expect(js, contains('SessionEvent.fromJson'));
      expect(js, contains('NodeRef.fromJson'));
      expect(js, contains('Stamp.fromJson'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
