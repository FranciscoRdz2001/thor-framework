import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  test('parses comments, export, quotes and inline comments', () {
    expect(
      parseDotEnv('''
# a comment
API_URL=https://api.test
export PORT = 4300
SECRET="a b # not a comment"
SINGLE='x\\ny'
MULTI="a\\nb"
TRAILING=value # a comment
EMPTY=
=nokey
1BAD=x
no equals
'''),
      {
        'API_URL': 'https://api.test',
        'PORT': '4300',
        'SECRET': 'a b # not a comment',
        'SINGLE': r'x\ny',
        'MULTI': 'a\nb',
        'TRAILING': 'value',
        'EMPTY': '',
      },
    );
  });

  test('the process environment wins; no file is nothing', () async {
    final dir = await Directory.systemTemp.createTemp('thor_dotenv_');
    addTearDown(() => dir.delete(recursive: true));
    expect(dotEnv(dir.path, const {}), isEmpty);
    File(p.join(dir.path, '.env')).writeAsStringSync('A=file\nB=file\n');
    expect(dotEnv(dir.path, const {'A': 'process'}), {'B': 'file'});
  });

  test("a command's environment: the .env, then what thor sets", () async {
    final dir = await Directory.systemTemp.createTemp('thor_dotenv_');
    addTearDown(() => dir.delete(recursive: true));
    File(
      p.join(dir.path, '.env'),
    ).writeAsStringSync('SESSION_SECRET=file\nPORT=1\nHOME_SET=file\n');
    expect(
      appEnvironment(dir.path, const {'PORT': '4000'}, const {'HOME_SET': 'x'}),
      {'SESSION_SECRET': 'file', 'PORT': '4000'},
    );
    // No file: only what thor sets.
    final empty = await Directory.systemTemp.createTemp('thor_dotenv_');
    addTearDown(() => empty.delete(recursive: true));
    expect(appEnvironment(empty.path, const {'A': 'b'}, const {}), {'A': 'b'});
  });
}
