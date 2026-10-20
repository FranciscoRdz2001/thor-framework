// Recipe: a form with a schema (lib/forms.dart). One declaration, two
// ends: the browser checks what HTML can (required, email, min length)
// without JavaScript; the server checks everything again before the action
// method runs (a tampered form or a curl never reaches your code) and a
// failure repaints values and messages. Success: redirect
// (POST → 303 → GET).
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../forms.dart';
import '../../router.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The page `/form`.
class FormPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const FormPage();

  /// `<form method=post action="?/send">`: runs only with a valid form
  /// (an invalid one is a 422 back to the page).
  Future<ActionResult?> send(
    PageRequest request,
    FormValues<ContactForm> values,
  ) async {
    // Typed values; here the real app saves them.
    values.of(ContactForm.email);
    return Redirect(RouteUrl('${formRoute.link()}?sent=1'));
  }

  /// `/form`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Formulario');

  /// The form, its errors, or the thank-you line.
  @override
  Widget build(BuildContext context, PageState<void> state) {
    // A failed POST: the messages and the values typed (a FormInvalid).
    final failed = state.form;
    final sent = state.request.queryParameters['sent'] == '1';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const PageTitle('Formulario', description: 'Contáctanos.'),
        if (sent)
          const Semantics(
            role: SemanticsRole.status,
            child: Text('¡Gracias! Te respondemos pronto.'),
          ),
        if (failed is FormInvalid)
          Semantics(
            role: SemanticsRole.alert,
            child: Text(
              'Revisa ${failed.errors.length == 1 ? 'el campo marcado' : 'los campos marcados'}.',
              style: const TextStyle(
                color: danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          decoration: surface,
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            schema: ContactForm.schema,
            onValid: send,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                // Attributes, value and message come from the schema.
                TextFormField(
                  field: ContactForm.name,
                  form: failed,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextFormField(
                  field: ContactForm.email,
                  form: failed,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextFormField(
                  field: ContactForm.message,
                  form: failed,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                ),
                FilledButton(
                  buttonType: ButtonType.submit,
                  onPressed: () {},
                  child: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
