import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../router.dart';
import '../ui.dart';

const _link = TextStyle(color: Color(0x4D000000), fontSize: 16, height: 1.5);

/// `nav.navbar`: the logo and the links (the current one highlighted).
class NavBar extends StatelessWidget implements ThorElementWidget {
  /// The bar for [user] (or a guest) at [path].
  const NavBar({super.key, required this.user, required this.path});

  /// Signed-in user.
  final User? user;

  /// Current path.
  final String path;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return cls(
      'navbar navbar-light',
      Semantics(
        role: SemanticsRole.navigation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: PageContainer(
            child: Row(
              children: [
                cls(
                  'navbar-brand',
                  Link(
                    href: homeRoute.link(),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 4, right: 32),
                      child: html.img(
                        src: '/conduit-logo.svg',
                        alt: 'Conduit',
                        classes: 'navbar-logo',
                        attributes: {
                          'style': 'height:1.25rem;vertical-align:middle',
                        },
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                cls(
                  'nav navbar-nav pull-xs-right',
                  Semantics(
                    role: SemanticsRole.list,
                    child: Row(
                      spacing: 16,
                      children: [
                        _item('/', const Text('Home')),
                        if (u == null) ...[
                          _item('/login', const Text('Sign in')),
                          _item('/register', const Text('Sign up')),
                        ] else ...[
                          _item(
                            '/editor',
                            _withIcon(ConduitIcons.compose, 'New Post'),
                          ),
                          _item(
                            '/settings',
                            _withIcon(ConduitIcons.gear, 'Settings'),
                          ),
                          _item(
                            '/profile/${u.username}',
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 5,
                              children: [
                                Avatar(
                                  u.image,
                                  name: u.username,
                                  size: 26,
                                  classes: 'user-pic',
                                ),
                                Text(u.username),
                              ],
                            ),
                            active: path == '/profile/${u.username}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(String href, Widget label, {bool? active}) {
    final on = active ?? path == href;
    return cls(
      'nav-item',
      Semantics(
        role: SemanticsRole.listItem,
        child: Container(
          child: cls(
            on ? 'nav-link active' : 'nav-link',
            Link(
              href: RouteUrl(href),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.8),
                child: DefaultTextStyle(
                  style: on
                      ? _link.copyWith(color: const Color(0xCC000000))
                      : _link.copyWith(
                          color: const Color(
                            0x4D000000,
                          ).when(hover: const Color(0x99000000)),
                        ),
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _withIcon(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [Icon(icon, size: 14), Text(label)],
  );
}

/// The few icons of the theme (ionicons outlines, as inline SVG).
abstract final class ConduitIcons {
  /// Compose (New Post).
  static const compose = IconData.svg(
    'rw-compose',
    '<path fill="currentColor" d="M16 3l5 5-11 11H5v-5L16 3zm0 2.8L7 14.8V17h2.2l9-9L16 5.8zM3 21h18v-2H3v2z"/>',
  );

  /// Gear (Settings).
  static const gear = IconData.svg(
    'rw-gear',
    '<path fill="currentColor" d="M12 8a4 4 0 100 8 4 4 0 000-8zm8.9 5.2l2-1.6-2-3.4-2.4.8a7 7 0 00-1.7-1L16.5 5.5h-4l-.4 2.5a7 7 0 00-1.7 1l-2.4-.8-2 3.4 2 1.6a7 7 0 000 2l-2 1.6 2 3.4 2.4-.8a7 7 0 001.7 1l.4 2.5h4l.4-2.5a7 7 0 001.7-1l2.4.8 2-3.4-2-1.6a7 7 0 000-2z"/>',
  );

  /// Heart (favorite).
  static const heart = IconData.svg(
    'rw-heart',
    '<path fill="currentColor" d="M12 21s-7.5-4.6-9.5-9.2C1 8.4 3.3 5 6.6 5c2 0 3.4 1.1 4.4 2.4C12 6.1 13.4 5 15.4 5 18.7 5 21 8.4 19.5 11.8 17.5 16.4 12 21 12 21z"/>',
  );

  /// Plus (follow).
  static const plus = IconData.svg(
    'rw-plus',
    '<path fill="currentColor" d="M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6z"/>',
  );

  /// Pencil (edit).
  static const edit = IconData.svg(
    'rw-edit',
    '<path fill="currentColor" d="M4 17v3h3l9-9-3-3-9 9zm14.7-9.3a1 1 0 000-1.4l-2-2a1 1 0 00-1.4 0L14 5.6l3 3 1.7-1.9z"/>',
  );

  /// Trash (delete).
  static const trash = IconData.svg(
    'rw-trash',
    '<path fill="currentColor" d="M9 3h6l1 2h4v2H4V5h4l1-2zM6 8h12l-1 13H7L6 8zm4 3v7h1v-7h-1zm3 0v7h1v-7h-1z"/>',
  );

  /// Cross (remove a tag).
  static const close = IconData.svg(
    'rw-close',
    '<path fill="currentColor" d="M6.4 5L12 10.6 17.6 5 19 6.4 13.4 12 19 17.6 17.6 19 12 13.4 6.4 19 5 17.6 10.6 12 5 6.4z"/>',
  );

  /// Hash (the tag tab).
  static const pound = IconData.svg(
    'rw-pound',
    '<path fill="currentColor" d="M10 3l-1 5H5v2h3.6l-.8 4H4v2h3.4l-1 5h2l1-5h4l-1 5h2l1-5H19v-2h-3.2l.8-4H20V8h-3.2l1-5h-2l-1 5h-4l1-5h-2zm.6 7h4l-.8 4h-4l.8-4z"/>',
  );
}

/// An icon inside `<i class=…>` (the contract's `i.ion-trash-a`).
Widget ionIcon(String className, IconData icon, {double size = 14}) =>
    html.i(classes: className, [Icon(icon, size: size)]);
