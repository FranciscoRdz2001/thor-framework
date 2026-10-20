import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/stats_state.dart';

/// `/`: public.
class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Inicio');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Watch(stats.label),
      TextButton(
        onPressed: stats.orders.refresh,
        child: const Text('Actualizar'),
      ),
      const Link(href: RouteUrl('/profile'), child: Text('Mi perfil')),
    ],
  );
}
