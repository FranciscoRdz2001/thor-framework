/// Raw HTML elements for the few places a page needs them directly (the
/// document head, markup ported from another site). Each one is
/// `Widget.element` with its attributes after the given `attributes`.
library;

// Lowercase class names on purpose: they read like the HTML they write.
// ignore_for_file: camel_case_types

import 'framework.dart';

export 'framework.dart' show RawText;

/// `<div>`.
final class div extends StatelessWidget {
  /// A `<div>` element.
  const div(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'div',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h1>`.
final class h1 extends StatelessWidget {
  /// A `<h1>` element.
  const h1(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h1',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h2>`.
final class h2 extends StatelessWidget {
  /// A `<h2>` element.
  const h2(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h2',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h3>`.
final class h3 extends StatelessWidget {
  /// A `<h3>` element.
  const h3(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h3',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h4>`.
final class h4 extends StatelessWidget {
  /// A `<h4>` element.
  const h4(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h4',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h5>`.
final class h5 extends StatelessWidget {
  /// A `<h5>` element.
  const h5(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h5',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<h6>`.
final class h6 extends StatelessWidget {
  /// A `<h6>` element.
  const h6(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'h6',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<i>`.
final class i extends StatelessWidget {
  /// A `<i>` element.
  const i(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'i',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<nav>`.
final class nav extends StatelessWidget {
  /// A `<nav>` element.
  const nav(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'nav',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<p>`.
final class p extends StatelessWidget {
  /// A `<p>` element.
  const p(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'p',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<span>`.
final class span extends StatelessWidget {
  /// A `<span>` element.
  const span(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'span',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<summary>`.
final class summary extends StatelessWidget {
  /// A `<summary>` element.
  const summary(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'summary',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<ul>`.
final class ul extends StatelessWidget {
  /// A `<ul>` element.
  const ul(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'ul',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<a>`.
final class a extends StatelessWidget {
  /// A `<a>` element.
  const a(
    this.children, {
    this.href,
    this.target,
    this.download,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `href` attribute. Without it the `<a>` is a placeholder link (valid
  /// HTML: no destination, not focusable), e.g. a control a state method
  /// handles.
  final String? href;

  /// The `target` attribute.
  final String? target;

  /// The `download` attribute.
  final String? download;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'a',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'href': ?href,
      'target': ?target,
      'download': ?download,
    },
    children: children,
  );
}

/// `<button>`.
final class button extends StatelessWidget {
  /// A `<button>` element.
  const button(
    this.children, {
    this.autofocus = false,
    this.disabled = false,
    this.type,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `autofocus` attribute.
  final bool autofocus;

  /// The `disabled` attribute.
  final bool disabled;

  /// The `type` attribute.
  final String? type;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'button',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      if (autofocus) 'autofocus': '',
      if (disabled) 'disabled': '',
      'type': ?type,
    },
    children: children,
  );
}

/// `<details>`.
final class details extends StatelessWidget {
  /// A `<details>` element.
  const details(
    this.children, {
    this.open = false,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `open` attribute.
  final bool open;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'details',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {...?attributes, if (open) 'open': ''},
    children: children,
  );
}

/// `<label>`.
final class label extends StatelessWidget {
  /// A `<label>` element.
  const label(
    this.children, {
    this.htmlFor,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `htmlFor` attribute.
  final String? htmlFor;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'label',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {...?attributes, 'for': ?htmlFor},
    children: children,
  );
}

/// `<li>`.
final class li extends StatelessWidget {
  /// A `<li>` element.
  const li(
    this.children, {
    this.value,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `value` attribute.
  final int? value;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'li',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {...?attributes, 'value': ?value?.toString()},
    children: children,
  );
}

/// `<ol>`.
final class ol extends StatelessWidget {
  /// A `<ol>` element.
  const ol(
    this.children, {
    this.reversed = false,
    this.start,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `reversed` attribute.
  final bool reversed;

  /// The `start` attribute.
  final int? start;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'ol',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      if (reversed) 'reversed': '',
      'start': ?start?.toString(),
    },
    children: children,
  );
}

/// `<textarea>`.
final class textarea extends StatelessWidget {
  /// A `<textarea>` element.
  const textarea(
    this.children, {
    this.autofocus = false,
    this.cols,
    this.disabled = false,
    this.minLength,
    this.name,
    this.placeholder,
    this.readonly = false,
    this.required = false,
    this.rows,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `autofocus` attribute.
  final bool autofocus;

  /// The `cols` attribute.
  final int? cols;

  /// The `disabled` attribute.
  final bool disabled;

  /// The `minLength` attribute.
  final int? minLength;

  /// The `name` attribute.
  final String? name;

  /// The `placeholder` attribute.
  final String? placeholder;

  /// The `readonly` attribute.
  final bool readonly;

  /// The `required` attribute.
  final bool required;

  /// The `rows` attribute.
  final int? rows;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'textarea',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      if (autofocus) 'autofocus': '',
      'cols': ?cols?.toString(),
      if (disabled) 'disabled': '',
      'minlength': ?minLength?.toString(),
      'name': ?name,
      'placeholder': ?placeholder,
      if (readonly) 'readonly': '',
      if (required) 'required': '',
      'rows': ?rows?.toString(),
    },
    children: children,
  );
}

/// `<link>`.
final class link extends StatelessWidget {
  /// A `<link>` element.
  const link({
    required this.href,
    this.rel,
    this.type,
    this.as,
    this.sizes,
    this.media,
    this.crossOrigin,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `href` attribute.
  final String href;

  /// The `rel` attribute.
  final String? rel;

  /// The `type` attribute.
  final String? type;

  /// The `as` attribute.
  final String? as;

  /// The `sizes` attribute: the icon sizes (`'96x96'`, `'180x180'`, `'any'`)
  /// of a `rel: 'icon'` or `'apple-touch-icon'` link.
  final String? sizes;

  /// The `media` attribute: a media query the linked resource applies to.
  final String? media;

  /// The `crossorigin` attribute (`'anonymous'`, `'use-credentials'`).
  final String? crossOrigin;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'link',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'href': href,
      'rel': ?rel,
      'type': ?type,
      'as': ?as,
      'sizes': ?sizes,
      'media': ?media,
      'crossorigin': ?crossOrigin,
    },
  );
}

/// `<meta>`.
final class meta extends StatelessWidget {
  /// A `<meta>` element.
  const meta({
    this.name,
    this.content,
    this.charset,
    this.httpEquiv,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `name` attribute.
  final String? name;

  /// The `content` attribute.
  final String? content;

  /// The `charset` attribute.
  final String? charset;

  /// The `httpEquiv` attribute.
  final String? httpEquiv;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'meta',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'name': ?name,
      'content': ?content,
      'charset': ?charset,
      'http-equiv': ?httpEquiv,
    },
  );
}

/// `<img>`.
final class img extends StatelessWidget {
  /// A `<img>` element.
  const img({
    this.alt,
    this.width,
    this.height,
    required this.src,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `alt` attribute.
  final String? alt;

  /// The `width` attribute.
  final int? width;

  /// The `height` attribute.
  final int? height;

  /// The `src` attribute.
  final String src;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'img',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'alt': ?alt,
      'width': ?width?.toString(),
      'height': ?height?.toString(),
      'src': src,
    },
  );
}

/// `<input>`.
final class input extends StatelessWidget {
  /// A `<input>` element.
  const input({
    this.type,
    this.name,
    this.value,
    this.disabled = false,
    this.checked,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `type` attribute.
  final InputType? type;

  /// The `name` attribute.
  final String? name;

  /// The `value` attribute.
  final String? value;

  /// The `disabled` attribute.
  final bool disabled;

  /// The `checked` attribute.
  final bool? checked;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'input',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'type': ?type?.value,
      'name': ?name,
      'value': ?value,
      if (disabled) 'disabled': '',
      if (checked ?? false) 'checked': '',
    },
  );
}

/// `<script>`.
final class script extends StatelessWidget {
  /// A `<script>` element.
  const script({
    this.src,
    this.async = false,
    this.defer = false,
    this.content,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `src` attribute.
  final String? src;

  /// The `async` attribute.
  final bool async;

  /// The `defer` attribute.
  final bool defer;

  /// The `content` attribute (the script itself).
  final String? content;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'script',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'src': ?src,
      if (async) 'async': '',
      if (defer) 'defer': '',
    },
    children: [if (content case final content?) RawText(content)],
  );
}

/// The `type` of an `<input>`.
enum InputType {
  /// `type="text"`.
  text('text'),

  /// `type="button"`.
  button('button'),

  /// `type="checkbox"`.
  checkbox('checkbox'),

  /// `type="color"`.
  color('color'),

  /// `type="date"`.
  date('date'),

  /// `type="datetime-local"`.
  dateTimeLocal('datetime-local'),

  /// `type="email"`.
  email('email'),

  /// `type="file"`.
  file('file'),

  /// `type="hidden"`.
  hidden('hidden'),

  /// `type="image"`.
  image('image'),

  /// `type="month"`.
  month('month'),

  /// `type="number"`.
  number('number'),

  /// `type="password"`.
  password('password'),

  /// `type="radio"`.
  radio('radio'),

  /// `type="range"`.
  range('range'),

  /// `type="reset"`.
  reset('reset'),

  /// `type="search"`.
  search('search'),

  /// `type="submit"`.
  submit('submit'),

  /// `type="tel"`.
  tel('tel'),

  /// `type="time"`.
  time('time'),

  /// `type="url"`.
  url('url'),

  /// `type="week"`.
  week('week');

  const InputType(this.value);

  /// The attribute value.
  final String value;
}

/// `<table>`.
final class table extends StatelessWidget {
  /// A `<table>` element.
  const table(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'table',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<caption>`: the table's title.
final class caption extends StatelessWidget {
  /// A `<caption>` element.
  const caption(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'caption',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<colgroup>`.
final class colgroup extends StatelessWidget {
  /// A `<colgroup>` element.
  const colgroup(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'colgroup',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<thead>`.
final class thead extends StatelessWidget {
  /// A `<thead>` element.
  const thead(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'thead',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<tbody>`.
final class tbody extends StatelessWidget {
  /// A `<tbody>` element.
  const tbody(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'tbody',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<tfoot>`.
final class tfoot extends StatelessWidget {
  /// A `<tfoot>` element.
  const tfoot(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'tfoot',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<tr>`.
final class tr extends StatelessWidget {
  /// A `<tr>` element.
  const tr(
    this.children, {
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'tr',
    id: id,
    classes: classes,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

/// `<col>`: a column of a [colgroup].
final class col extends StatelessWidget {
  /// A `<col>` element.
  const col({
    this.span,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The `span` attribute: columns it covers.
  final int? span;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'col',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {...?attributes, 'span': ?span?.toString()},
  );
}

/// `<th>`: a table header cell.
final class th extends StatelessWidget {
  /// A `<th>` element.
  const th(
    this.children, {
    this.scope,
    this.colSpan,
    this.rowSpan,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `scope` attribute: what the header cell heads (`col`, `row`,
  /// `colgroup`, `rowgroup`).
  final String? scope;

  /// The `colspan` attribute: columns it takes.
  final int? colSpan;

  /// The `rowspan` attribute: rows it takes.
  final int? rowSpan;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'th',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'scope': ?scope,
      'colspan': ?colSpan?.toString(),
      'rowspan': ?rowSpan?.toString(),
    },
    children: children,
  );
}

/// `<td>`: a table data cell.
final class td extends StatelessWidget {
  /// A `<td>` element.
  const td(
    this.children, {
    this.colSpan,
    this.rowSpan,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    super.key,
  });

  /// The content.
  final List<Widget> children;

  /// The `colspan` attribute: columns it takes.
  final int? colSpan;

  /// The `rowspan` attribute: rows it takes.
  final int? rowSpan;

  /// The element's id.
  final String? id;

  /// Its classes, separated by spaces.
  final String? classes;

  /// Its inline styles.
  final Styles? styles;

  /// More attributes (written before the ones above).
  final Map<String, String>? attributes;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'td',
    id: id,
    classes: classes,
    styles: styles,
    attributes: {
      ...?attributes,
      'colspan': ?colSpan?.toString(),
      'rowspan': ?rowSpan?.toString(),
    },
    children: children,
  );
}
