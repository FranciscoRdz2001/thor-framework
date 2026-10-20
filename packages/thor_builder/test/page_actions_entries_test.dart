import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';

import 'support.dart';

const _pages = r'''
import 'dart:async';

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final class ContactForm extends FormSchema {
  const ContactForm._() : super(const [email]);
  static const schema = ContactForm._();
  static const email = TextSchemaField('email');
}

final class NoteForm extends FormSchema {
  const NoteForm() : super(const [text]);
  static const text = TextSchemaField('text');
}

final class LooseForm extends FormSchema {
  const LooseForm(String x) : super(const []);
}

enum Role { admin, guest }

mixin Shared on ThorPage<void> {
  Future<ActionResult?> share(PageRequest request) async => null;
}

abstract class BasePage extends ThorPage<void> with Shared {
  const BasePage();

  Future<ActionResult?> logout(PageRequest request) async => null;
}

class ContactPage extends BasePage {
  const ContactPage();

  Future<ActionResult?> send(
    PageRequest request,
    FormValues<ContactForm> values,
  ) async => const Redirect('/thanks');

  FutureOr<ActionResult?> note(PageRequest r, FormValues<NoteForm> v) => null;

  ActionResult remove(PageRequest request) => const ActionResult.success();

  Future<Redirect> go(PageRequest request) async => const Redirect('/');

  // Arguments a button binds (`onPost: delete.withArg(id)`).
  Future<ActionResult?> delete(PageRequest r, int id) async => null;
  Future<ActionResult?> grant(PageRequest r, Role role, bool on) async => null;
  ActionResult? maybe(PageRequest r, int? id, DateTime? at, double? x) => null;

  // Not actions: other returns, other parameters, private, static.
  Future<void> helper(PageRequest request) async {}
  Future<ActionResult?> list(PageRequest r, List<int> ids) async => null;
  Future<ActionResult?> klass(PageRequest r, Object o) async => null;
  Future<ActionResult?> five(PageRequest r, int a, int b, int c, int d) async =>
      null;
  Future<ActionResult?> named(PageRequest r, {int? id}) async => null;
  Future<ActionResult?> optional(PageRequest r, [int? id]) async => null;
  Future<ActionResult?> mixed(PageRequest r, int a, List<int> b) async => null;
  Future<ActionResult?> _hidden(PageRequest request) async => null;
  static Future<ActionResult?> shared(PageRequest request) async => null;

  @override
  FutureOr<String?> redirect(PageRequest request) => null;

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('x');
}

class PlainPage extends ThorPage<void> {
  const PlainPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('x');
}
''';

const _bad = r'''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final class LooseForm extends FormSchema {
  const LooseForm(String x) : super(const []);
}

class _PrivatePage extends ThorPage<void> {
  const _PrivatePage();

  Future<ActionResult?> go(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}

class LoosePage extends ThorPage<void> {
  const LoosePage();

  Future<ActionResult?> save(PageRequest r, FormValues<LooseForm> v) async =>
      null;

  Future<ActionResult?> plain(PageRequest r, FormValues<FormSchema> v) async =>
      null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}

enum _Secret { a }

class ArgPage extends ThorPage<void> {
  const ArgPage();

  Future<ActionResult?> hide(PageRequest r, _Secret s) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}
''';

/// The page classes of [source] (`lib/pages.dart`) and the registry.
Future<(List<String>, String?, List<EntryProblem>)> _registry(String source) =>
    resolveSources(
      {'app|lib/pages.dart': source},
      (resolver) async {
        final lib = await resolver.libraryFor(
          AssetId.parse('app|lib/pages.dart'),
        );
        final pages = <(ClassElement, String)>[
          for (final c in lib.classes)
            if (isPageClass(c)) (c, 'lib/pages.dart'),
        ];
        final problems = <EntryProblem>[];
        final code = actionsLibrary(pages, problems: problems);
        return ([for (final (c, _) in pages) c.name!], code, problems);
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );

void main() {
  test('lists the action methods of each concrete page', () async {
    final (pages, code, problems) = await _registry(_pages);
    expect(problems, isEmpty);
    expect(pages, ['ContactPage', 'PlainPage']);
    expect(code, contains("import 'package:app/pages.dart' as t0;"));
    expect(
      code,
      contains(
        "PageActionMethod.valid('send', (p) => (p as t0.ContactPage).send, "
        't0.ContactForm.schema)',
      ),
    );
    // No `static const schema`: its const constructor.
    expect(
      code,
      contains(
        "PageActionMethod.valid('note', (p) => (p as t0.ContactPage).note, "
        'const t0.NoteForm())',
      ),
    );
    for (final name in ['remove', 'go', 'logout', 'share']) {
      expect(
        code,
        contains(
          "PageActionMethod.request('$name', "
          '(p) => (p as t0.ContactPage).$name)',
        ),
      );
    }
    // The request plus arguments a button binds, parsed back to their types.
    expect(
      code,
      contains(
        "PageActionMethod.args('delete', (p) => (p as t0.ContactPage).delete, "
        '1, (x) => [int.parse(x[0]!)])',
      ),
    );
    expect(
      code,
      contains(
        "PageActionMethod.args('grant', (p) => (p as t0.ContactPage).grant, "
        "2, (x) => [t0.Role.values.byName(x[0]!), x[1] == 'true'])",
      ),
    );
    expect(
      code,
      contains(
        "PageActionMethod.args('maybe', (p) => (p as t0.ContactPage).maybe, "
        '3, (x) => [(x[0].isEmpty ? null : int.parse(x[0]!)), '
        '(x[1].isEmpty ? null : DateTime.parse(x[1]!)), '
        '(x[2].isEmpty ? null : double.parse(x[2]!))])',
      ),
    );
    for (final name in [
      'helper',
      'list',
      'klass',
      'five',
      'named',
      'optional',
      'mixed',
      '_hidden',
      'shared',
      'build',
    ]) {
      expect(code, isNot(contains("'$name'")));
    }
    expect(code, isNot(contains('PlainPage')));
    expect(code, isNot(contains('BasePage')));
  });

  test('the registry compiles against the app', () async {
    final (_, code, _) = await _registry(_pages);
    final errors = await compileErrors({
      'app|lib/pages.dart': _pages,
      'app|lib/actions.dart': code!,
    }, 'app|lib/actions.dart');
    expect(errors, isEmpty);
  });

  test('no page with actions: no registry', () async {
    final (pages, code, _) = await _registry(
      "import 'package:thor_ui/router.dart';\n"
      "import 'package:thor_ui/thor_ui.dart';\n"
      '${_pages.substring(_pages.indexOf('class PlainPage'))}',
    );
    expect(pages, ['PlainPage']);
    expect(code, isNull);
  });

  test('a private page or a schema it cannot build stops the build', () async {
    final (_, _, problems) = await _registry(_bad);
    final messages = problems.map((p) => p.message).toList();
    expect(messages, hasLength(4), reason: messages.join('\n'));
    expect(messages[0], contains('THOR-B023'));
    expect(messages[0], contains('_PrivatePage'));
    expect(messages[1], contains('THOR-B024'));
    expect(messages[1], contains('LoosePage.save'));
    expect(messages[2], contains('THOR-B024'));
    expect(messages[2], contains('FormValues<FormSchema>'));
    expect(messages[3], contains('THOR-B023'));
    expect(messages[3], contains('ArgPage.hide'));
  });

  test('the server entry registers the actions when there are some', () {
    final code = serverEntry('../../bin/server.dart', actions: true);
    expect(code, contains("import 'actions.dart';"));
    final actions = code.indexOf(
      'ThorServer.setUpIsolates(registerThorActions);',
    );
    expect(actions, greaterThan(0));
    expect(code.indexOf('run(args)'), greaterThan(actions));
    expect(
      serverEntry('../../bin/server.dart'),
      isNot(contains('registerThorActions')),
    );
  });
}
