// ignore_for_file: public_member_api_docs
// (each example is named by its use in the guide)
// The examples of "Routes" and "Data": a navigation built from the route
// table, a form declared with a schema (before and after the server
// rejects it) and the tree of a modular app.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import '../guide_routes.dart' show guideRoute;

/// The code face of the diagrams.
const _mono = TextStyle(
  fontFamily: StudioFontFamilies.mono,
  fontSize: 12,
  height: 1.5,
);

// region: routes-nav
/// A side navigation: each link comes from a route, and the page being
/// shown is marked with `current:` (`aria-current="page"`).
class GuideNav extends StatelessWidget {
  const GuideNav({super.key, required this.path});

  /// The path of the page being shown (`state.request.uri.path`).
  final String path;

  static const links = [
    ('instalacion', 'Installation'),
    ('primera-app', 'Your first app'),
    ('desde-flutter', 'Coming from Flutter'),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.navigation,
    child: SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          for (final (slug, label) in links)
            NavEntry(
              // guideRoute = ThorRoute('/empezar/:slug', const GuidePage('empezar'))
              href: context.localized(guideRoute.link({'slug': slug})),
              label: label,
              current: guideRoute.link({'slug': slug}) == path,
            ),
        ],
      ),
    ),
  );
}

class NavEntry extends StatelessWidget {
  const NavEntry({
    super.key,
    required this.href,
    required this.label,
    required this.current,
  });

  final String href;
  final String label;
  final bool current;

  @override
  Widget build(BuildContext context) => Link(
    href: RouteUrl(href),
    current: current,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: current
            ? ThemeColor.secondaryContainer
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          color: current ? ThemeColor.onSurface : ThemeColor.onSurfaceVariant,
        ),
      ),
    ),
  );
}
// endregion

// region: data-form
/// The rules of the form, declared once: the browser checks them before
/// sending, the server checks them again before the action runs.
final class ContactForm extends FormSchema {
  const ContactForm._() : super(const [name, email]);

  static const schema = ContactForm._();

  static const name = TextSchemaField(
    'name',
    validators: [Validator.required('Enter your name.')],
  );
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Enter your email.'),
      Validator.email('That email does not look valid.'),
    ],
  );
}

/// The form of the page: [onValid] is the page's action method, [failed]
/// is `state.form` after a rejected POST.
class ContactFormView extends StatelessWidget {
  const ContactFormView({super.key, this.onValid, this.failed});

  final PageValidPost<ContactForm>? onValid;
  final Object? failed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Form(
      schema: ContactForm.schema,
      onValid: onValid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            field: ContactForm.name,
            form: failed,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextFormField(
            field: ContactForm.email,
            form: failed,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Submit'),
          ),
        ],
      ),
    ),
  );
}
// endregion

// region: data-form-failed
/// What the page shows after `ActionResult.fail(422)`: the same form, with
/// what the person typed and the message of each field.
class ContactFormFailed extends StatelessWidget {
  const ContactFormFailed({super.key});

  @override
  Widget build(BuildContext context) => ContactFormView(
    failed: FormInvalid(
      errors: {'email': 'That email does not look valid.'},
      values: {'name': 'Ana', 'email': 'ana@'},
    ),
  );
}
// endregion

// ── The tree of a modular app (an illustration, no code panel) ──

/// One line of the tree: its depth, what it is, its code and a note.
typedef _Node = ({int depth, String kind, String code, String note});

const _tree = <_Node>[
  (
    depth: 0,
    kind: 'Group',
    code: 'layout: AppShell',
    note: 'the frame of the whole app and its error page',
  ),
  (depth: 1, kind: 'Route', code: "'/'", note: 'HomePage'),
  (
    depth: 1,
    kind: 'Group',
    code: 'salesModule',
    note: 'its layout, its middleware and its error page',
  ),
  (depth: 2, kind: 'Route', code: "'/sales/orders'", note: 'OrdersPage'),
  (depth: 2, kind: 'Route', code: "'/sales/orders/:id:int'", note: 'OrderPage'),
  (depth: 1, kind: 'Group', code: 'catalogModule', note: 'another module'),
  (depth: 2, kind: 'Route', code: "'/catalog'", note: 'ProductsPage'),
  (
    depth: 0,
    kind: 'Group',
    code: 'no layout',
    note: 'full screen, outside the frame',
  ),
  (depth: 1, kind: 'Route', code: "'/login'", note: 'LoginPage'),
];

class RouteTreeView extends StatelessWidget {
  const RouteTreeView({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: StudioSurfaceColors.panel,
      border: Border.fromBorderSide(BorderSide(color: StudioBorderColors.line)),
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          'ThorRouter([ … ])',
          style: _mono.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        for (final node in _tree) _TreeRow(node),
      ],
    ),
  );
}

class _TreeRow extends StatelessWidget {
  const _TreeRow(this.node);

  final _Node node;

  @override
  Widget build(BuildContext context) {
    final group = node.kind == 'Group';
    return Padding(
      padding: EdgeInsets.only(left: 12.0 + node.depth * 22),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: StudioBorderColors.line, width: 2),
          ),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: group
                    ? StudioAccentColors.accentTint
                    : StudioSurfaceColors.hover,
                borderRadius: const BorderRadius.all(
                  Radius.circular(StudioRadii.small),
                ),
              ),
              child: Text(
                node.kind,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: group
                      ? StudioAccentColors.accent
                      : StudioContentColors.muted,
                ),
              ),
            ),
            Text(node.code, style: _mono.copyWith(fontSize: 13)),
            Text(
              node.note,
              style: const TextStyle(
                fontSize: 13,
                color: StudioContentColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
