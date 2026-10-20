/// The recipes' shared pieces in the web layer (`package:thor_ui/web.dart`),
/// next to their Flutter versions in `ui/`: same screen, web names.
library;

import 'package:thor_ui/web.dart';

import '../data.dart';
import '../router.dart';

/// A page's `<h1>` and its description, with utilities.
class WebTitle extends StatelessWidget implements ThorElementWidget {
  /// The title [text] and its [description].
  const WebTitle(this.text, {super.key, this.description});

  /// The title.
  final String text;

  /// Under the title.
  final String? description;

  @override
  Widget build(BuildContext context) => Box(
    style: tw('flex flex-col gap-1'),
    children: [
      H1(text: text, style: tw('text-[28px] font-bold text-ink')),
      if (description != null) P(text: description, style: tw('text-muted')),
    ],
  );
}

/// The same title with `Style`.
class StyleTitle extends StatelessWidget implements ThorElementWidget {
  /// The title [text] and its [description].
  const StyleTitle(this.text, {super.key, this.description});

  /// The title.
  final String text;

  /// Under the title.
  final String? description;

  @override
  Widget build(BuildContext context) => Box(
    style: Style(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      gap: 4.px,
    ),
    children: [
      H1(
        text: text,
        style: Style(fontSize: 28.px, fontWeight: FontWeight.w700, color: _ink),
      ),
      if (description != null)
        P(
          text: description,
          style: Style(color: _muted),
        ),
    ],
  );
}

/// The product card with utilities: stacked below 440 px of its own width,
/// in a row from there (`@container` + `@min-[440px]:`).
class WebProductCard extends StatelessWidget implements ThorElementWidget {
  /// The card of [product].
  const WebProductCard(this.product, {super.key});

  /// What it shows.
  final Product product;

  @override
  Widget build(BuildContext context) => Box(
    style: tw('@container'),
    children: [
      Article(
        style: tw(
          'flex flex-col overflow-hidden rounded-xl border border-line '
          'bg-white @min-[440px]:flex-row',
        ),
        children: [
          Box(style: tw('min-h-30 shrink-0 bg-[#c7d2fe] @min-[440px]:w-40')),
          Box(
            style: tw('flex flex-col items-start gap-1.5 p-4'),
            children: [
              H2(
                text: product.name,
                style: tw('text-[18px] font-semibold text-ink'),
              ),
              P(text: product.category.label, style: tw('text-muted')),
              P(text: money(product.price), style: tw('font-bold')),
              FilledButton(
                onPressed: () {},
                href: _listHref(product),
                child: const Text('Ver en la lista'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The same card with `Style`.
class StyleProductCard extends StatelessWidget implements ThorElementWidget {
  /// The card of [product].
  const StyleProductCard(this.product, {super.key});

  /// What it shows.
  final Product product;

  @override
  Widget build(BuildContext context) => Box(
    style: const Style(containerType: ContainerType.inlineSize),
    children: [
      Article(
        style: Style(
          display: Display.flex,
          flexDirection: FlexDirection.column,
          overflow: Overflow.hidden,
          borderRadius: 12.px,
          borderWidth: 1.px,
          borderColor: _line,
          backgroundColor: const Color(0xFFFFFFFF),
        ).when(container: {440: const Style(flexDirection: FlexDirection.row)}),
        children: [
          Box(
            style: Style(
              minHeight: 120.px,
              flexShrink: 0,
              backgroundColor: const Color(0xFFC7D2FE),
            ).when(container: {440: Style(width: 160.px)}),
          ),
          Box(
            style: Style(
              display: Display.flex,
              flexDirection: FlexDirection.column,
              alignItems: AlignItems.flexStart,
              gap: 6.px,
              padding: 16.px,
            ),
            children: [
              H2(
                text: product.name,
                style: Style(
                  fontSize: 18.px,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              P(
                text: product.category.label,
                style: Style(color: _muted),
              ),
              P(
                text: money(product.price),
                style: const Style(fontWeight: FontWeight.w700),
              ),
              FilledButton(
                onPressed: () {},
                href: _listHref(product),
                child: const Text('Ver en la lista'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String _listHref(Product p) =>
    '${listRoute.link()}?q=${Uri.encodeQueryComponent(p.name)}';

// The theme's tokens by name, like `tw('text-ink')`: both modes write the
// same declarations.
final _ink = ThemeColor.token('ink');
final _muted = ThemeColor.token('muted');
final _line = ThemeColor.token('line');
