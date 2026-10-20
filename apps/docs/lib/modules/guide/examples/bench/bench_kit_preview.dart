/// Pieces the catalog's benches use to make a setting visible on the stage
/// when what it changes is closed (a dialog, a drawer, a menu, a bubble) or
/// is an attribute and not a look (an `<a>` that opens in another tab).
///
/// A preview is drawn with the same text and the same colors as the real
/// overlay, and it follows the same state, so dragging a control moves it.
library;

import 'package:thor_ui/thor_ui.dart';

import '../catalog_shared.dart' show modalShadowColor, scrimColor;

const _muted = TextStyle(fontSize: 13, color: ThemeColor.onSurfaceVariant);

const _mono = TextStyle(
  fontFamily: 'ui-monospace',
  fontFamilyFallback: ['SFMono-Regular', 'Menlo', 'monospace'],
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

/// A muted label followed by a value (`Pulsaciones 3`): the row the stages
/// use to say what a setting amounts to.
class NoteRow extends StatelessWidget {
  /// The row: [label] then [value] (a `Text`, a `Watch`).
  const NoteRow({super.key, required this.label, required this.value});

  /// What it is.
  final String label;

  /// What it is now.
  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Text(label, style: _muted),
      DefaultTextStyle(
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        child: value,
      ),
    ],
  );
}

/// The element a setting leaves in the page: `<a href="…">`, `<button>`.
class ElementTag extends StatelessWidget {
  /// The tag, written as HTML.
  const ElementTag(this.tag, {super.key});

  /// The element and its attributes.
  final String tag;

  @override
  Widget build(BuildContext context) => NoteRow(
    label: 'Element',
    value: Text(tag, style: _mono),
  );
}

/// A muted label over a line of code that may wrap: the markup a setting
/// leaves in the page.
class CodeNote extends StatelessWidget {
  /// [label] over [code].
  const CodeNote({super.key, required this.label, required this.code});

  /// What it is.
  final String label;

  /// The code.
  final String code;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      Text(label, style: _muted),
      Text(code, style: _mono),
    ],
  );
}

/// A box with a small caption: what an overlay looks like once it is open.
class PreviewFrame extends StatelessWidget {
  /// A [child] under the "Preview" caption, [width] wide.
  const PreviewFrame({
    super.key,
    required this.child,
    this.width = 320,
    this.scrim = false,
    this.padding = const EdgeInsets.all(16),
  });

  /// The preview.
  final Widget child;

  /// Its width.
  final double width;

  /// Whether it sits over the dimmed backdrop of a modal.
  final bool scrim;

  /// The space around [child].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        const Text('Preview', style: _muted),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: scrim ? scrimColor : ThemeColor.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: const Border.fromBorderSide(
              BorderSide(color: ThemeColor.outlineVariant),
            ),
          ),
          child: child,
        ),
      ],
    ),
  );
}

/// The surface of an open dialog (28 px corners, the container color).
class ModalSurface extends StatelessWidget {
  /// A dialog's surface around [child].
  const ModalSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  /// What is inside.
  final Widget child;

  /// The space around [child].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: modalShadowColor,
          offset: Offset(0, 8),
          blurRadius: 24,
        ),
      ],
    ),
    child: child,
  );
}

/// The bubble of a tooltip, drawn in place.
class BubblePreview extends StatelessWidget {
  /// A bubble that says [message].
  const BubblePreview(this.message, {super.key});

  /// Its text.
  final String message;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThemeColor.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: ThemeColor.onInverseSurface,
        ),
      ),
    ),
  );
}
