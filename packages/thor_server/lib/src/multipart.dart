import 'dart:convert';
import 'dart:typed_data';

import 'results.dart';

/// A file sent with a form (`<input type="file">`), held in memory (the
/// whole body is bounded by the server's `maxBodyBytes`).
class UploadedFile {
  /// A file named [filename] of [contentType] with [bytes].
  UploadedFile(this.filename, this.contentType, this.bytes);

  /// The name the browser gave, reduced to its last path segment and
  /// without control characters. Still the visitor's text: never use it
  /// as a path on the server as it is.
  final String filename;

  /// Its media type as the browser sent it (`application/octet-stream`
  /// when it sent none): a claim, not a check of the content.
  final String contentType;

  /// Its content.
  final Uint8List bytes;

  /// Its size in bytes.
  int get length => bytes.length;

  @override
  String toString() => 'UploadedFile($filename, $contentType, $length B)';
}

// RFC 2046 `boundary`: bchars, not ending in a space (so ASCII only).
final _bchars = RegExp(r"^[0-9A-Za-z'()+_,\-./:=? ]*[0-9A-Za-z'()+_,\-./:=?]$");

/// The fields and files of a `multipart/form-data` [body] (RFC 7578)
/// whose parts are separated by [boundary].
///
/// Fail-closed: a body that doesn't follow the format (no final delimiter,
/// a part without `Content-Disposition` or a name, headers that don't end)
/// is a `400`; more than [maxParts] parts or [maxHeaderBytes] of headers in
/// a part, a `413`. A file input left empty (no filename, no content) is
/// skipped, as browsers send it anyway.
({Map<String, List<String>> fields, Map<String, List<UploadedFile>> files})
parseMultipart(
  Uint8List body,
  String boundary, {
  int maxParts = 1000,
  int maxHeaderBytes = 8 * 1024,
}) {
  if (boundary.isEmpty || boundary.length > 70 || !_bchars.hasMatch(boundary)) {
    throw const HttpError(400, 'Bad multipart boundary');
  }
  final dash = ascii.encode('--$boundary');
  final crlfDash = ascii.encode('\r\n--$boundary');
  final fields = <String, List<String>>{};
  final files = <String, List<UploadedFile>>{};

  // The first delimiter: at the very start, or after a preamble's CRLF.
  var at = _startsWith(body, 0, dash) ? 0 : _indexOf(body, crlfDash, 0);
  if (at < 0) throw const HttpError(400, 'Malformed multipart body');
  if (at > 0) at += 2;
  var parts = 0;
  while (true) {
    at += dash.length;
    // `--` after a delimiter closes the body (what follows is ignored).
    if (_startsWith(body, at, const [0x2D, 0x2D])) break;
    // Transport padding, then the line break before the part's headers.
    while (at < body.length && (body[at] == 0x20 || body[at] == 0x09)) {
      at++;
    }
    if (!_startsWith(body, at, const [0x0D, 0x0A])) {
      throw const HttpError(400, 'Malformed multipart body');
    }
    at += 2;
    if (++parts > maxParts) throw const HttpError(413, 'Too many form parts');

    final headersEnd = _indexOf(body, const [0x0D, 0x0A, 0x0D, 0x0A], at);
    if (headersEnd < 0) throw const HttpError(400, 'Malformed multipart body');
    if (headersEnd - at > maxHeaderBytes) {
      throw const HttpError(413, 'Form part headers too large');
    }
    final headers = _headers(body.sublist(at, headersEnd));
    final contentStart = headersEnd + 4;
    final next = _nextDelimiter(body, crlfDash, contentStart);
    if (next < 0) throw const HttpError(400, 'Malformed multipart body');
    final content = Uint8List.sublistView(body, contentStart, next);
    at = next + 2;

    final disposition = headers['content-disposition'];
    if (disposition == null) {
      throw const HttpError(400, 'Form part without Content-Disposition');
    }
    if (!disposition.toLowerCase().startsWith('form-data')) {
      throw const HttpError(400, 'Form part is not form-data');
    }
    final params = _dispositionParams(disposition);
    final name = params['name'];
    if (name == null) throw const HttpError(400, 'Form part without a name');
    final filename = params['filename'];
    if (filename == null) {
      (fields[name] ??= []).add(utf8.decode(content, allowMalformed: true));
    } else if (filename.isNotEmpty || content.isNotEmpty) {
      (files[name] ??= []).add(
        UploadedFile(
          _baseName(filename),
          headers['content-type'] ?? 'application/octet-stream',
          Uint8List.fromList(content),
        ),
      );
    }
  }
  return (fields: fields, files: files);
}

/// The part's headers, lowercase names (UTF-8: browsers send non-ASCII
/// filenames raw).
Map<String, String> _headers(List<int> bytes) {
  final out = <String, String>{};
  for (final line in utf8.decode(bytes, allowMalformed: true).split('\r\n')) {
    final colon = line.indexOf(':');
    if (colon <= 0) throw const HttpError(400, 'Malformed form part header');
    out[line.substring(0, colon).trim().toLowerCase()] = line
        .substring(colon + 1)
        .trim();
  }
  return out;
}

/// `form-data; name="a"; filename="b.png"` → `{name: a, filename: b.png}`
/// (quoted or not; `\"` inside quotes; `;` inside quotes is text).
Map<String, String> _dispositionParams(String value) {
  final out = <String, String>{};
  var i = value.indexOf(';');
  if (i < 0) return out;
  while (i < value.length) {
    i++; // past `;`
    while (i < value.length && value[i] == ' ') {
      i++;
    }
    final eq = value.indexOf('=', i);
    if (eq < 0) break;
    final key = value.substring(i, eq).trim().toLowerCase();
    i = eq + 1;
    final text = StringBuffer();
    if (i < value.length && value[i] == '"') {
      i++;
      while (i < value.length && value[i] != '"') {
        if (value[i] == r'\' && i + 1 < value.length) i++;
        text.write(value[i++]);
      }
      i++; // closing quote
      while (i < value.length && value[i] != ';') {
        i++;
      }
    } else {
      final end = value.indexOf(';', i);
      text.write(value.substring(i, end < 0 ? value.length : end).trim());
      i = end < 0 ? value.length : end;
    }
    out.putIfAbsent(key, () => '$text');
  }
  return out;
}

/// The last segment of [name] (`C:\fotos\a.png` → `a.png`), without
/// control characters.
String _baseName(String name) {
  final cut = name.lastIndexOf(RegExp(r'[/\\]'));
  return name
      .substring(cut + 1)
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .trim();
}

/// The next CRLF + `--boundary` that is a delimiter: followed by `--` (the
/// last one) or by optional spaces and CRLF (RFC 2046). Content may hold
/// the same bytes followed by anything else.
int _nextDelimiter(List<int> bytes, List<int> crlfDash, int from) {
  var at = _indexOf(bytes, crlfDash, from);
  while (at >= 0) {
    var i = at + crlfDash.length;
    if (_startsWith(bytes, i, const [0x2D, 0x2D])) return at;
    while (i < bytes.length && (bytes[i] == 0x20 || bytes[i] == 0x09)) {
      i++;
    }
    if (_startsWith(bytes, i, const [0x0D, 0x0A])) return at;
    at = _indexOf(bytes, crlfDash, at + 1);
  }
  return -1;
}

bool _startsWith(List<int> bytes, int at, List<int> prefix) {
  if (at + prefix.length > bytes.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[at + i] != prefix[i]) return false;
  }
  return true;
}

int _indexOf(List<int> bytes, List<int> needle, int from) {
  final last = bytes.length - needle.length;
  final first = needle[0];
  for (var i = from; i <= last; i++) {
    if (bytes[i] == first && _startsWith(bytes, i, needle)) return i;
  }
  return -1;
}
