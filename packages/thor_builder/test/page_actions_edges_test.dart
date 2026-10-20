import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';

import 'support.dart';

// Page action edges a real CRUD app writes: generic bases and mixins in the
// schema, overrides, and pages whose file does not name `ThorPage`.
const _pages = r'''
import 'dart:async';

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final class ClientForm extends FormSchema {
  const ClientForm._() : super(const [name]);
  static const schema = ClientForm._();
  static const name = TextSchemaField('name');
}

final class SaleForm extends FormSchema {
  const SaleForm._() : super(const [total]);
  static const schema = SaleForm._();
  static const total = TextSchemaField('total');
}

abstract class CrudPage<S extends FormSchema> extends ThorPage<void> {
  const CrudPage();

  Future<ActionResult?> save(PageRequest request, FormValues<S> values) async =>
      null;
}

class ClientPage extends CrudPage<ClientForm> {
  const ClientPage();

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}

mixin Editing<S extends FormSchema> on ThorPage<void> {
  Future<ActionResult?> update(PageRequest request, FormValues<S> values) async =>
      null;
}

class SalePage extends ThorPage<void> with Editing<SaleForm> {
  const SalePage();

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}

abstract class Base extends ThorPage<void> {
  const Base();

  Future<ActionResult?> archive(PageRequest request) async => null;
}

class Overrides extends Base {
  const Overrides();

  // A valid override still takes `(PageRequest)`: still the action.
  @override
  Future<ActionResult?> archive(PageRequest request, [int n = 0]) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}
''';

Future<(String?, List<EntryProblem>)> _registry(String source) =>
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
        return (actionsLibrary(pages, problems: problems), problems);
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );

void main() {
  test('a generic base page gets the schema of its subclass', () async {
    final (code, problems) = await _registry(_pages);
    expect(problems, isEmpty, reason: '${problems.map((p) => p.message)}');
    expect(
      code,
      contains(
        "PageActionMethod.valid('save', (p) => (p as t0.ClientPage).save, "
        't0.ClientForm.schema)',
      ),
    );
  });

  test('a generic mixin gets the schema of its application', () async {
    final (code, _) = await _registry(_pages);
    expect(
      code,
      contains(
        "PageActionMethod.valid('update', (p) => (p as t0.SalePage).update, "
        't0.SaleForm.schema)',
      ),
    );
  });

  test(
    'an override with an extra optional parameter is still the action',
    () async {
      final (code, _) = await _registry(_pages);
      expect(
        code,
        contains(
          "PageActionMethod.request('archive', "
          '(p) => (p as t0.Overrides).archive)',
        ),
      );
    },
  );

  test('the registry of these pages compiles', () async {
    final (code, _) = await _registry(_pages);
    final errors = await compileErrors({
      'app|lib/pages.dart': _pages,
      'app|lib/actions.dart': code!,
    }, 'app|lib/actions.dart');
    expect(errors, isEmpty);
  });

  test('a page file that names neither Page nor ActionResult is read', () {
    // `class Clients extends Screen` where `Screen extends ThorPage` elsewhere,
    // and the method returns `Future<Redirect>`.
    const source = '''
import 'screen.dart';

class Clients extends Screen {
  const Clients();
  Future<Redirect> logout(PageRequest request) async => const Redirect('/');
}
''';
    expect(mayDeclareActions(source), isTrue);
  });
}
