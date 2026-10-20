// Recipe: a confirmation dialog without JavaScript. DialogTrigger opens the
// native <dialog> (commandfor/command); its buttons are a form that posts
// the action, or a DialogClose. Esc, backdrop and focus are the browser's.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../router.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The page `/dialog`.
class DialogPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const DialogPage();

  /// The delete action the dialog confirms.
  Future<ActionResult?> delete(PageRequest request) async =>
      Redirect(RouteUrl('${dialogRoute.link()}?deleted=1'));

  /// `/dialog`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Diálogo');

  /// A button that asks before deleting.
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final deleted = state.request.queryParameters['deleted'] == '1';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        const PageTitle('Diálogo', description: 'Confirmar antes de borrar.'),
        if (deleted)
          const Semantics(role: SemanticsRole.status, child: Text('Borrado.')),
        DialogTrigger(
          id: 'confirm',
          child: OutlinedButton(
            onPressed: () {},
            child: const Text(
              'Borrar proyecto',
              style: TextStyle(color: danger),
            ),
          ),
        ),
        AlertDialog(
          id: 'confirm',
          title: const Text('¿Borrar el proyecto?'),
          content: const Text('No se puede deshacer.'),
          actions: [
            DialogClose(
              id: 'confirm',
              child: TextButton(
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
            ),
            Form(
              onPost: delete,
              child: FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Borrar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
