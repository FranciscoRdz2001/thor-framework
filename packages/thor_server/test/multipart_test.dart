import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

const _b = '----thorBoundary7MA4YWxk';

/// A multipart body from [parts] (headers, content), as browsers write it.
Uint8List _body(
  List<(String, List<int>)> parts, {
  String boundary = _b,
  String preamble = '',
  bool close = true,
}) {
  final out = BytesBuilder()..add(utf8.encode(preamble));
  for (final (headers, content) in parts) {
    out
      ..add(utf8.encode('--$boundary\r\n$headers\r\n\r\n'))
      ..add(content)
      ..add(utf8.encode('\r\n'));
  }
  if (close) out.add(utf8.encode('--$boundary--\r\n'));
  return out.takeBytes();
}

String _field(String name) => 'Content-Disposition: form-data; name="$name"';
String _file(String name, String filename, [String? type]) =>
    'Content-Disposition: form-data; name="$name"; filename="$filename"'
    '${type == null ? '' : '\r\nContent-Type: $type'}';

Future<FormData> _form(
  Uint8List body, {
  String type = 'multipart/form-data; boundary=$_b',
  int max = 1 << 20,
}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://x/upload'),
  headers: {const HttpHeader('Content-Type'): type},
  body: Stream.value(body),
  maxBodyBytes: max,
).form();

Matcher _status(int code) =>
    throwsA(isA<HttpError>().having((e) => e.status, 'status', code));

void main() {
  group('reads', () {
    test('fields and files, several of each, in order', () async {
      final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 255];
      final form = await _form(
        _body([
          (_field('title'), utf8.encode('Hola, ñandú')),
          (_file('photos', 'a.png', 'image/png'), png),
          (_file('photos', 'b.txt', 'text/plain'), utf8.encode('b')),
          (_field('tag'), utf8.encode('x')),
          (_field('tag'), utf8.encode('y')),
        ]),
      );
      expect(form['title'], 'Hola, ñandú');
      expect(form.all('tag'), ['x', 'y']);
      expect(form.filesOf('photos').map((f) => f.filename), ['a.png', 'b.txt']);
      final a = form.file('photos')!;
      expect(a.contentType, 'image/png');
      expect(a.bytes, png);
      expect(a.length, png.length);
    });

    test('content that looks like a delimiter but is not one stays', () async {
      // `--boundary` not preceded by CRLF, and CRLF + `--other`.
      final tricky = utf8.encode('x--$_b y\r\n--other\r\n--${_b}x');
      final form = await _form(_body([(_file('f', 'a.bin'), tricky)]));
      expect(form.file('f')!.bytes, tricky);
    });

    test('a quoted boundary, a preamble and an epilogue', () async {
      final body = BytesBuilder()
        ..add(_body([(_field('a'), utf8.encode('1'))], preamble: 'ignored\r\n'))
        ..add(utf8.encode('epilogue ignored'));
      final form = await _form(
        body.takeBytes(),
        type: 'multipart/form-data; charset=utf-8; boundary="$_b"',
      );
      expect(form['a'], '1');
    });

    test('an empty file input (no file chosen) is not a file', () async {
      final form = await _form(
        _body([
          (_file('avatar', ''), const []),
          (_field('name'), utf8.encode('ana')),
        ]),
      );
      expect(form.files, isEmpty);
      expect(form.file('avatar'), isNull);
      expect(form['name'], 'ana');
    });

    test('an empty but named file is a file', () async {
      final form = await _form(_body([(_file('f', 'empty.txt'), const [])]));
      expect(form.file('f')!.length, 0);
    });

    test('no Content-Type: application/octet-stream', () async {
      final form = await _form(
        _body([
          (_file('f', 'a'), const [1]),
        ]),
      );
      expect(form.file('f')!.contentType, 'application/octet-stream');
    });

    test(
      'the filename is its last segment, without control characters',
      () async {
        final form = await _form(
          _body([
            (_file('a', r'C:\\fotos\\gato.png'), const [1]),
            (_file('b', '../../etc/passwd'), const [1]),
            (_file('c', 'bad\u0000name\u0007.txt'), const [1]),
            (_file('d', r'with \"quotes\".txt'), const [1]),
          ]),
        );
        expect(form.file('a')!.filename, 'gato.png');
        expect(form.file('b')!.filename, 'passwd');
        expect(form.file('c')!.filename, 'badname.txt');
        expect(form.file('d')!.filename, 'with "quotes".txt');
      },
    );

    test('a semicolon inside a quoted name is part of it', () async {
      final form = await _form(
        _body([
          (
            'Content-Disposition: form-data; name="a;b"; filename="x;y.txt"',
            const [1],
          ),
        ]),
      );
      expect(form.file('a;b')!.filename, 'x;y.txt');
    });

    test('a urlencoded form still works, and has no files', () async {
      final form = await _form(
        Uint8List.fromList(utf8.encode('a=1&b=2')),
        type: 'application/x-www-form-urlencoded',
      );
      expect(form.toMap(), {'a': '1', 'b': '2'});
      expect(form.files, isEmpty);
    });
  });

  group('fails closed', () {
    test('no boundary: 400', () async {
      await expectLater(
        _form(_body([]), type: 'multipart/form-data'),
        _status(400),
      );
    });

    test('a body without the final delimiter: 400', () async {
      await expectLater(
        _form(_body([(_field('a'), utf8.encode('1'))], close: false)),
        _status(400),
      );
    });

    test('a boundary outside RFC 2046 bchars: 400, not a throw', () async {
      for (final b in [
        '\u00c3\u00a9',
        'a\u0001b',
        'a"b',
        'a\\b',
        'ends with ',
      ]) {
        await expectLater(
          _form(_body([]), type: 'multipart/form-data; boundary="$b"'),
          _status(400),
          reason: b,
        );
      }
    });

    test('a body with another boundary: 400', () async {
      await expectLater(
        _form(_body([(_field('a'), const [])], boundary: 'other')),
        _status(400),
      );
    });

    test(
      'a part without Content-Disposition, or without a name: 400',
      () async {
        await expectLater(
          _form(
            _body([
              ('Content-Type: text/plain', const [1]),
            ]),
          ),
          _status(400),
        );
        await expectLater(
          _form(
            _body([
              ('Content-Disposition: form-data', const [1]),
            ]),
          ),
          _status(400),
        );
        await expectLater(
          _form(
            _body([
              ('Content-Disposition: attachment; name="a"', const [1]),
            ]),
          ),
          _status(400),
        );
      },
    );

    test('headers that never end, or a line without a colon: 400', () async {
      final noEnd = utf8.encode('--$_b\r\n${_field('a')}\r\n--$_b--');
      await expectLater(_form(Uint8List.fromList(noEnd)), _status(400));
      await expectLater(
        _form(_body([('${_field('a')}\r\ngarbage', const [])])),
        _status(400),
      );
    });

    test('a body over the limit (files count): 413', () async {
      await expectLater(
        _form(_body([(_file('f', 'big'), List.filled(2048, 7))]), max: 1024),
        _status(413),
      );
    });

    test('too many parts: 413', () async {
      await expectLater(
        _form(
          _body([for (var i = 0; i < 1001; i++) (_field('f$i'), const [])]),
        ),
        _status(413),
      );
    });

    test('huge part headers: 413', () async {
      await expectLater(
        _form(_body([('${_field('a')}\r\nX-Pad: ${'a' * 9000}', const [])])),
        _status(413),
      );
    });

    test('another content type: 415', () async {
      await expectLater(
        _form(Uint8List(0), type: 'application/json'),
        _status(415),
      );
    });
  });

  test(
    'the body is read once: form() then text() see the same bytes',
    () async {
      final request = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://x/'),
        headers: {HttpHeader.contentType: 'application/x-www-form-urlencoded'},
        body: Stream.value(utf8.encode('a=1')),
      );
      expect((await request.form())['a'], '1');
      expect(await request.text(), 'a=1');
    },
  );
}
