/// `:::bench bench-middleware`: what a group's middleware decides. A Switch
/// picks who visits, another the page they ask for; the stage shows what the
/// visit ends in: the page, a redirect to the login or a 403.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';

/// Who visits.
enum Visitor {
  /// No session cookie.
  guest,

  /// A signed-in user without the admin role.
  member,

  /// A signed-in admin.
  admin,
}

/// Which page they ask for.
enum Target {
  /// `/account`: any signed-in user.
  account,

  /// `/admin`: admins only.
  admin,
}

/// What the panels control and the stage reads.
class MiddlewareViewModel extends ThorState {
  /// Who visits.
  final visitor = state(Visitor.guest);

  /// Which page they ask for.
  final target = state(Target.account);

  /// The route line of the Code view.
  String routeCode() => target.value == Target.account
      ? "ThorRoute('/account', const AccountPage()),"
      : "ThorRoute('/admin', const AdminPage(), middleware: [requireAdmin]),";

  /// The comment of the Code view: what the visit ends in.
  String outcomeCode() {
    if (visitor.value == Visitor.guest) {
      return '// guest: Redirect.found(/login)';
    }
    if (target.value == Target.admin && visitor.value != Visitor.admin) {
      return '// member: HttpError(StatusCode.forbidden)';
    }
    return '// ${visitor.value.name}: next() runs the page';
  }

  /// What the visitor Switch calls.
  void setVisitor(Set<Visitor> value) => visitor.value = value.first;

  /// What the target Switch calls.
  void setTarget(Set<Target> value) => target.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final middlewareDemo = MiddlewareViewModel();

/// The example.
final middlewareBench = BenchExample(
  title: (t) => t.exRoutesMiddlewareTitle,
  description: (t) => t.exRoutesMiddlewareDescription,
  stage: const MiddlewareStage(),
  code: BenchCode([
    const BenchCodeLine('Future<ThorResponse> requireUser('),
    const BenchCodeLine('PageRequest request, Next next) async {', indent: 2),
    const BenchCodeLine(
      'final user = await users.fromCookie(request.cookies[\'session\']);',
      indent: 1,
    ),
    const BenchCodeLine(
      'if (user == null) throw Redirect.found(loginRoute.link());',
      indent: 1,
    ),
    const BenchCodeLine('request.context.set(currentUser, user);', indent: 1),
    const BenchCodeLine('return next();', indent: 1),
    const BenchCodeLine('}'),
    const BenchCodeLine(' '),
    BenchCodeLine.live(middlewareDemo.routeCode),
    BenchCodeLine.live(middlewareDemo.outcomeCode),
  ], appCode: true),
  controls: [
    BenchSwitch<Visitor>(
      label: (t) => t.exRoutesMiddlewareVisitor,
      value: middlewareDemo.visitor.value,
      onChanged: middlewareDemo.setVisitor,
      segments: [
        BenchSegment(Visitor.guest, label: (t) => t.exRoutesMiddlewareGuest),
        BenchSegment(Visitor.member, label: (t) => t.exRoutesMiddlewareMember),
        BenchSegment(Visitor.admin, label: (t) => t.exRoutesMiddlewareAdmin),
      ],
    ),
    BenchSwitch<Target>(
      label: (t) => t.exRoutesMiddlewareTarget,
      value: middlewareDemo.target.value,
      onChanged: middlewareDemo.setTarget,
      segments: [
        BenchSegment(Target.account, label: (t) => t.exRoutesMiddlewareAccount),
        BenchSegment(Target.admin, label: (t) => t.exRoutesMiddlewareAdminPage),
      ],
    ),
  ],
);

/// The stage: the response of the visit.
class MiddlewareStage extends StatelessWidget {
  /// The stage of the example.
  const MiddlewareStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      middlewareDemo.visitor,
      builder: (visitor) => Watch.field(
        middlewareDemo.target,
        builder: (target) {
          final (status, text) = switch ((visitor, target)) {
            (Visitor.guest, _) => ('302', 'Redirects to /login.'),
            (Visitor.member, Target.admin) => (
              '403',
              'You do not have access to this page.',
            ),
            (_, Target.account) => ('200', 'Your account page.'),
            (_, Target.admin) => ('200', 'The admin panel.'),
          };
          final ok = status == '200';
          final ink = ok ? ThemeColor.onSurface : ThemeColor.onPrimaryContainer;
          final path = target == Target.account ? '/account' : '/admin';
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ok
                    ? ThemeColor.surfaceContainerHigh
                    : ThemeColor.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    'GET $path',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontFamilyFallback: const ['ui-monospace', 'monospace'],
                      fontSize: 15,
                      color: ink,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(text, style: TextStyle(fontSize: 20, color: ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
