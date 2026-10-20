/// The app's forms, declared once: the browser validates with
/// the native attributes these rules become, the server checks the same
/// rules before the page's action method runs (it receives
/// `FormValues<ContactForm>`), and the page takes each field's attributes,
/// value and message from here.
library;

import 'package:thor_ui/router.dart';

/// The contact form of `/form`: its own class, so an action method
/// says which form it takes (`FormValues<ContactForm>`).
final class ContactForm extends FormSchema {
  ContactForm._() : super([name, email, message]);

  /// Name.
  static const name = TextSchemaField(
    'name',
    validators: [Validator.required('Escribe tu nombre.')],
  );

  /// Email.
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Escribe tu correo.'),
      Validator.email('Ese correo no parece válido.'),
    ],
  );

  /// Message: at least 10 letters (native `minlength`) and no links
  /// (a rule only the server can run: `Validator.custom`).
  static final message = TextSchemaField(
    'message',
    validators: [
      const Validator.minLength(10, 'Cuéntanos un poco más (10 letras o más).'),
      Validator.custom(
        (v) => v.contains('http') ? 'Sin enlaces, por favor.' : null,
      ),
    ],
  );

  /// The whole form.
  static final schema = ContactForm._();
}
