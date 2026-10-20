/// The names the fragments of the guide take for granted (tool/docs_check.dart
/// imports this file into every block it compiles): the `Order` and
/// `ItemCard` of the page's own domain, a handler, a router. Free variables
/// (`cart`, `orders`) need no entry; types, widgets and functions do, so a
/// typo in a name of the API (`Textt`) is never taken for the page's own. Keep
/// it small: a name here is one the reader is expected to have written.
// ignore_for_file: depend_on_referenced_packages, avoid_positional_boolean_parameters
library;

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

enum Owner { luis, ana }

enum Billing { monthly, yearly }

enum Role { sales, admin }

/// The counter of the state chapter's tests.
class CounterViewModel extends ThorState {
  final count = state(0);
  void increment() => count.value++;
  void decrement() => count.value--;
  void inc() => count.value++;
  void reset() => count.value = 0;
  bool isZero() => count.value == 0;
  String label() => '${count.value}';
}

final class ContactForm extends FormSchema {
  const ContactForm() : super(const [email]);
  static const email = TextSchemaField('email');
}

/// A value of the page's domain that is built with any arguments.
class Made {
  const Made([this.a, this.b, this.c, this.d, this.e]);
  final dynamic a, b, c, d, e;
}

class BrandShape extends ThemeExtension<BrandShape> {
  const BrandShape({required this.radius});
  final double radius;
}

final class SignUp extends FormSchema {
  const SignUp._() : super(const [email, password, age]);
  static const schema = SignUp._();

  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Escribe tu correo.'),
      Validator.email('Ese correo no parece válido.'),
    ],
  );
  static const password = TextSchemaField(
    'password',
    secret: true,
    validators: [Validator.minLength(8, 'Usa al menos 8 caracteres.')],
  );
  static const age = IntSchemaField('age', invalid: 'La edad es un número.');
}

class CartPage extends ThorPage<dynamic> {
  const CartPage();

  Future<ActionResult?> add(
    PageRequest request,
    dynamic sku,
    dynamic seller,
  ) async => null;

  @override
  Future<dynamic> load(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<dynamic> state) =>
      const SizedBox();
}

/// The class `flutter gen-l10n` writes for the app (the i18n chapter).
abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) =>
      throw UnimplementedError();
  static const List<LocalizationsDelegate<AppLocalizations>>
  localizationsDelegates = [];
  static const supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('es', 'MX'),
  ];

  String get storeTitle;
  String welcome(Object name);
  String cartItems(int count);
  String price(double amount);
  String since(DateTime date);
}

AppLocalizations lookupAppLocalizations(Locale locale) =>
    throw UnimplementedError();

class DataModel {
  static DataModel parse(dynamic body) => DataModel();
}

class SalesNav extends AmbientWidget {
  const SalesNav({this.path});
  final dynamic path;
}

class NavBar extends AmbientWidget {
  const NavBar({this.user, this.path});
  final dynamic user, path;
}

class Home extends Made {
  const Home({this.user, this.featured});
  final dynamic user, featured;
}

class ProductData extends Made {
  const ProductData({this.item});
  final dynamic item;
}

class Product extends Made {
  const Product([super.a, super.b, super.c, super.d]);
}

/// A category of a store's tree (the `LazyPiece` and `withArg` examples).
class Category {
  const Category(this.slug, this.name, this.url);
  final String slug, name, url;
}

// --- widgets of the page's own app ---
/// A widget of the page's own app, built with any arguments.
abstract class AmbientWidget extends StatelessWidget {
  const AmbientWidget([this.a, this.b, this.c, this.d]);
  final dynamic a, b, c, d;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class OrderDetail extends AmbientWidget {
  const OrderDetail({this.order});
  final dynamic order;
}

class ContactFormView extends AmbientWidget {
  const ContactFormView({this.onValid, this.failed});
  final dynamic onValid, failed;
}

class Header extends AmbientWidget {
  const Header({this.user});
  final dynamic user;
}

// --- the app's own functions ---

/// `AppIcons.chevronDown`: the app's own icon names.
abstract final class AppIcons {
  static const chevronDown = Icons.keyboard_arrow_down;
  static const user = Icons.person;
}

class OrdersPage extends ThorPage<dynamic> {
  Future<ActionResult?> archive(PageRequest request, int id) async => null;

  const OrdersPage();

  @override
  Future<dynamic> load(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<dynamic> state) =>
      const SizedBox();
}
