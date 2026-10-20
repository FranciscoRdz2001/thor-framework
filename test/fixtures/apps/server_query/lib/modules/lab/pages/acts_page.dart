import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/acts_repository.dart';
import '../state/acts_state.dart';

/// `/acts`: public, for the tests and the browser check of the actions with
/// arguments, `confirm`, `toast` and the flash.
class ActsPage extends ThorPage<void> {
  const ActsPage();

  /// Deletes an order: a typed argument from a button, and a flash.
  Future<ActionResult?> delete(PageRequest request, int id) async {
    final found = actsRepository.remove(id);
    return const Redirect(RouteUrl('/acts')).flash(
      found ? 'Pedido eliminado' : 'No existe',
      kind: found ? FlashKind.success : FlashKind.error,
    );
  }

  /// Two arguments, one an enum.
  Future<ActionResult?> assign(PageRequest request, int id, Owner owner) async {
    actsRepository.assign(id, owner);
    return null;
  }

  /// A flash with HTML in it, and a second redirect on the way.
  Future<ActionResult?> hostile(PageRequest request) async => const Redirect(
    RouteUrl('/acts/next'),
  ).flash('<img src=x onerror=alert(1)> & "q"');

  /// The row's key first, a text second: what a client-made row must escape.
  Future<ActionResult?> mark(
    PageRequest request,
    String key,
    String note,
  ) async => const Redirect(RouteUrl('/acts')).flash('marca $key|$note');

  /// A form with a text field and a `confirm:` on the whole form: Enter in
  /// the field must ask too.
  Future<ActionResult?> note(PageRequest request) async {
    final form = await request.form();
    return const Redirect(
      RouteUrl('/acts'),
    ).flash('Nota: ${form['title'] ?? ''}');
  }

  /// Arguments AND the fields of the `Form` the button is in (HALLAZGOS 14).
  Future<ActionResult?> addLine(
    PageRequest request,
    String sku,
    String seller,
  ) async {
    final form = await request.form();
    return const Redirect(
      RouteUrl('/acts'),
    ).flash('línea $sku/$seller x${form['qty']} nota ${form['memo']}');
  }

  /// Two submit buttons of one `Form`: only the pressed one's argument arrives.
  Future<ActionResult?> pick(PageRequest request, String which) async {
    final form = await request.form();
    return const Redirect(RouteUrl('/acts')).flash(
      'pick $which de ${form.all('thor-arg').length} nota ${form['picknote']}',
    );
  }

  Future<ActionResult?> reset(PageRequest request) async {
    actsRepository.reset();
    return null;
  }

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Acciones');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      const Text('Servidor', style: TextStyle(fontSize: 20)),
      for (final o in actsRepository.orders)
        Row(
          spacing: 8,
          children: [
            Text('#${o.id} ${o.customer} (${o.owner})'),
            FilledButton(
              onPost: delete.withArg(o.id),
              confirm: ConfirmSpec(
                '¿Eliminar #${o.id}?',
                message: 'Se borra en el servidor',
                confirmLabel: 'Eliminar',
              ),
              child: Text('Eliminar ${o.id}'),
            ),
            OutlinedButton(
              onPost: assign.withArgs(o.id, Owner.luis),
              child: Text('A Luis ${o.id}'),
            ),
          ],
        ),
      OutlinedButton(onPost: hostile, child: const Text('Aviso hostil')),
      OutlinedButton(onPost: reset, child: const Text('Reiniciar')),
      Form(
        onPost: note,
        confirm: const ConfirmSpec('¿Guardar la nota?'),
        child: Row(
          spacing: 8,
          children: [
            const TextField(
              name: 'title',
              decoration: InputDecoration(labelText: 'Nota'),
            ),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: () {},
              child: const Text('Guardar nota'),
            ),
          ],
        ),
      ),
      Form(
        child: Row(
          spacing: 8,
          children: [
            const TextField(
              name: 'qty',
              decoration: InputDecoration(labelText: 'Cantidad'),
            ),
            const HiddenField(name: 'memo', value: 'oculto'),
            FilledButton(
              onPost: addLine.withArgs('sku9', 'seller2'),
              child: const Text('Agregar línea'),
            ),
          ],
        ),
      ),
      Form(
        child: Row(
          spacing: 8,
          children: [
            const TextField(
              name: 'picknote',
              decoration: InputDecoration(labelText: 'Pick note'),
            ),
            FilledButton(
              onPost: pick.withArg('A'),
              child: const Text('Pick A'),
            ),
            FilledButton(
              onPost: pick.withArg('B'),
              child: const Text('Pick B'),
            ),
          ],
        ),
      ),
      // The action of another page: posts to `/acts/other` (its only action).
      OutlinedButton(
        onPost: const ActsOtherPage().ping,
        child: const Text('Ping otra página'),
      ),
      Form(
        onPost: const ActsOtherPage().ping,
        child: const FilledButton(
          buttonType: ButtonType.submit,
          child: Text('Ping en Form'),
        ),
      ),
      const Text('Navegador', style: TextStyle(fontSize: 20)),
      Watch.list(
        acts.rows.call,
        itemKey: acts.idOf,
        each: (row) => Row(
          spacing: 8,
          children: [
            row.text((o) => o.customer),
            OutlinedButton(
              onPressed: acts.removeAsk.withArg(row.key),
              child: const Text('Quitar'),
            ),
            TextButton(
              onPost: delete.withArg(row.key),
              child: const Text('Quitar (servidor)'),
            ),
          ],
        ),
      ),
      Watch.list(
        acts.tags.call,
        itemKey: acts.tagKey,
        each: (row) => Row(
          spacing: 8,
          children: [
            const Text('clave'),
            OutlinedButton(
              onPressed: acts.mark.withArgs(row.key, 'ok'),
              child: const Text('Marcar'),
            ),
            TextButton(
              onPost: mark.withArgs(row.key, 'ok'),
              child: const Text('Marcar (servidor)'),
            ),
          ],
        ),
      ),
      OutlinedButton(onPressed: acts.addTag, child: const Text('Nueva clave')),
      Watch(acts.logText),
      Row(
        spacing: 8,
        children: [
          OutlinedButton(onPressed: acts.askTwice, child: const Text('Dos')),
          OutlinedButton(onPressed: acts.addRow, child: const Text('Añadir')),
          OutlinedButton(
            onPressed: acts.renameFirst,
            child: const Text('Renombrar'),
          ),
          OutlinedButton(
            onPressed: acts.flood.withArg(10),
            child: const Text('Diluvio'),
          ),
          OutlinedButton(
            onPressed: acts.hideNotice,
            child: const Text('Ocultar aviso'),
          ),
          OutlinedButton(
            onPressed: acts.clearNotices,
            child: const Text('Limpiar avisos'),
          ),
          OutlinedButton(
            onPressed: acts.say.withArg('Hola <b>'),
            child: const Text('Decir'),
          ),
          OutlinedButton(onPressed: acts.fail, child: const Text('Fallar')),
          OutlinedButton(
            onPressed: acts.toggleOpen,
            child: const Text('Alternar'),
          ),
          Watch(
            acts.isOpen,
            builder: (open) => Text(open ? 'abierto' : 'cerrado'),
          ),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          for (final who in const ['ana', 'luis'])
            OutlinedButton(
              onPressed: acts.pick.withArg(who),
              child: Text('Elegir $who'),
            ),
          Watch(acts.pickedText),
          OutlinedButton(
            onPressed: acts.tag.withArgs(4, 'a~b'),
            child: const Text('Etiquetar'),
          ),
        ],
      ),
    ],
  );
}

/// `/acts/next`: sends on to `/acts` (a guard, as a sign-in would): the
/// flash waits through this redirect for the page that draws.
class ActsNextPage extends ThorPage<void> {
  const ActsNextPage();

  @override
  RouteUrl? redirect(PageRequest request) => const RouteUrl('/acts');

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('nunca');
}

/// `/acts/other`: a page with an action another page's button posts to.
class ActsOtherPage extends ThorPage<void> {
  const ActsOtherPage();

  Future<ActionResult?> ping(PageRequest request) async =>
      const Redirect(RouteUrl('/acts')).flash('ping de otra página');

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('otra');
}
