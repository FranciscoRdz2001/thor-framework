/// `confirm:` without JavaScript: the question a control carries, and the
/// page that asks it.
///
/// A button or a `Form` with `confirm:` asks in the page's dialog when JS
/// runs. Without it the browser would submit straight away, so the control
/// also carries its question in the request ([askField] in the body, or
/// [askQueryKey] in the URL of a button that already posts an argument).
/// A POST that has a question and not the answer ([confirmedField]) gets
/// this page instead of running the action; its button posts the same
/// request again with the answer. The dialog's yes sends the answer too.
///
/// It is advice for the visitor, not a lock: whoever can craft the request
/// can add the answer, as they could always post the action. What it keeps
/// is the guarantee that a visitor without JS who presses a destructive
/// button is asked first.
library;

import 'dart:convert';

import '../server_messages.dart';
import 'handler.dart' show ThorResponse;
import 'http_types.dart';
import 'list_query.dart' show queryWithoutAction, sitePath;
import 'request.dart' show FormData, PageRequest;

/// The body field that carries the question (a JSON object: `t` the question,
/// `m` a text under it, `o` and `n` the labels of yes and no).
const askField = 'thor-ask';

/// The answer: `1` once the visitor said yes (the page's dialog or this
/// page's button).
const confirmedField = 'thor-confirmed';

/// The query key that carries the question for a button whose own `name` is
/// taken (an action with an argument). It starts with `/`, so it is
/// dropped with the action key everywhere a URL is rebuilt.
const askQueryKey = '/thor-ask';

/// The question of a control with `confirm:`.
final class ConfirmAsk {
  /// A question; [title] is what is asked.
  const ConfirmAsk(this.title, {this.message, this.yes, this.no});

  /// The question.
  final String title;

  /// A text under the question.
  final String? message;

  /// The label of the button that says yes (the app's when null).
  final String? yes;

  /// The label of the way back (the app's when null).
  final String? no;

  /// What [raw] (the JSON of [askField]) asks, or null when it is no question
  /// (not JSON, not an object, no text): the request then runs as it came.
  /// Texts are cut to a size a question can have.
  static ConfirmAsk? parse(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > 32768) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
      // Anything the visitor's browser (or curl) sent: not a question.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    String? text(Object? v, int max) {
      if (v is! String || v.trim().isEmpty) return null;
      final runes = v.trim().runes;
      return runes.length <= max
          ? v.trim()
          : String.fromCharCodes(runes.take(max));
    }

    final title = text(json['t'], 200);
    if (title == null) return null;
    return ConfirmAsk(
      title,
      message: text(json['m'], 600),
      yes: text(json['o'], 60),
      no: text(json['n'], 60),
    );
  }
}

const _escape = HtmlEscape(HtmlEscapeMode.attribute);

/// The question [request] carries and has not been answered, as the page
/// that asks it; null when there is none (nothing asked, or already
/// answered) and the action runs.
///
/// [form] is the parsed body, null when it is not a form. A form with a file
/// is answered with an explanation instead (status 400): the file cannot go
/// through a second post, and running the action without asking is what the
/// control exists to prevent.
ThorResponse? confirmationFor(
  PageRequest request,
  FormData? form,
  ServerMessages appMessages, {
  Set<String> trustedOrigins = const {},
}) {
  // The last value: a `Form` with `confirm:` and a button of its own with
  // one both post `thor-ask`, the form's first (DOM order); the dialog asks
  // the button's, so this page does too.
  final raw =
      request.queryParameters[askQueryKey] ?? form?.all(askField).lastOrNull;
  final ask = ConfirmAsk.parse(raw);
  if (ask == null || form?[confirmedField] == '1') return null;
  // The app's texts, the rest in the language of the request.
  final messages = appMessages.forLocale(request.locale);
  final back = _wayBack(request, trustedOrigins);
  if (form != null && form.files.isNotEmpty) {
    return _page(
      request,
      title: ask.title,
      body:
          '<p>${_escape.convert(messages.confirmNeedsScript)}</p>\n'
          '<p><a href="${_escape.convert(back)}">'
          '${_escape.convert(ask.no ?? messages.cancel)}</a></p>',
      status: 400,
    );
  }
  final uri = request.uri;
  final query = uri.query;
  final action = '${sitePath(uri.path)}${query.isEmpty ? '' : '?$query'}';
  final hidden = StringBuffer();
  for (final field
      in form?.fields.entries ?? const <MapEntry<String, List<String>>>[]) {
    if (field.key == askField || field.key == confirmedField) continue;
    for (final value in field.value) {
      hidden.writeln(
        '<input type="hidden" name="${_escape.convert(field.key)}" '
        'value="${_escape.convert(value)}">',
      );
    }
  }
  return _page(
    request,
    title: ask.title,
    body:
        '<form method="post" action="${_escape.convert(action)}">\n'
        '$hidden'
        '<input type="hidden" name="$confirmedField" value="1">\n'
        '${ask.message == null ? '' : '<p>${_escape.convert(ask.message!)}</p>\n'}'
        '<p><a href="${_escape.convert(back)}">'
        '${_escape.convert(ask.no ?? messages.cancel)}</a> '
        '<button type="submit">'
        '${_escape.convert(ask.yes ?? messages.ok)}</button></p>\n'
        '</form>',
  );
}

/// The page the visitor goes back to: the one that sent the form when the
/// browser says so and it is this site's, else the page of the request.
String _wayBack(PageRequest request, Set<String> trusted) {
  final own = () {
    final uri = request.uri;
    final query = queryWithoutAction(uri.query);
    return '${sitePath(uri.path)}${query.isEmpty ? '' : '?$query'}';
  }();
  final referer = request.headers['referer'];
  if (referer == null) return own;
  final from = Uri.tryParse(referer);
  final host = request.headers['host'];
  // Same site only: a page of this host (or a trusted origin), over http(s).
  if (from == null ||
      !(from.scheme == 'http' || from.scheme == 'https') ||
      !from.hasAuthority ||
      host == null ||
      !(from.authority == host || trusted.contains(from.origin))) {
    return own;
  }
  final path = sitePath(from.path.isEmpty ? '/' : from.path);
  return '$path${from.hasQuery ? '?${from.query}' : ''}';
}

ThorResponse _page(
  PageRequest request, {
  required String title,
  required String body,
  int status = 200,
}) {
  final lang = request.locale?.toLanguageTag() ?? 'en';
  final html =
      '<!doctype html>\n'
      '<html lang="${_escape.convert(lang)}">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<meta name="color-scheme" content="light dark">\n'
      '<meta name="robots" content="noindex">\n'
      '<title>${_escape.convert(title)}</title>\n'
      '</head>\n'
      '<body>\n'
      '<main>\n'
      '<h1>${_escape.convert(title)}</h1>\n'
      '$body\n'
      '</main>\n'
      '</body>\n'
      '</html>\n';
  return ThorResponse(
    status,
    headers: {
      HttpHeader.contentType: 'text/html; charset=utf-8',
      HttpHeader.cacheControl: 'no-store',
    },
    body: utf8.encode(html),
  );
}
