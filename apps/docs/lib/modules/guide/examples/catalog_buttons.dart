/// The component catalog: buttons (`docs/guia/es/componentes-botones.md`).
/// Every example is a bench: a stage, a panel with Switches and Levels, and
/// a Code view that follows them. The ids (`cat-filled-button`…) are the ones
/// the widget pages of the API reference reuse.
library;

import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_preview.dart';

/// How many times a button of the catalog was pressed.
class PressCounterViewModel extends ThorState {
  /// The presses.
  final count = state(0);

  /// The number on the stage.
  String text() => '${count.value}';

  /// What the buttons call.
  void add() => count.value++;
}

/// One instance, at the top level: the browser boots with it.
final presses = PressCounterViewModel();

/// The row every button stage ends with: how many presses it has had.
class PressesLabel extends StatelessWidget {
  /// The label with its count.
  const PressesLabel({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      const Text(
        'Presses',
        style: TextStyle(fontSize: 13, color: ThemeColor.onSurfaceVariant),
      ),
      Watch(
        presses.text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

// ---------------------------------------------------------------- FilledButton

/// Which `FilledButton` constructor.
enum FilledKind {
  /// `FilledButton`.
  filled,

  /// `FilledButton.tonal`.
  tonal,
}

/// What the FilledButton panel controls.
class FilledButtonViewModel extends ThorState {
  /// Filled or tonal.
  final kind = state(FilledKind.filled);

  /// With an icon.
  final icon = state(false);

  /// Whether `onPressed` is set.
  final enabled = state(true);

  /// The constructor line of the Code view.
  String headCode() {
    final tonal = kind.value == FilledKind.tonal;
    final name = icon.value
        ? (tonal ? 'tonalIcon' : 'icon')
        : (tonal ? 'tonal' : '');
    return name.isEmpty ? 'FilledButton(' : 'FilledButton.$name(';
  }

  /// The `onPressed` line.
  String pressedCode() =>
      enabled.value ? 'onPressed: presses.add,' : 'onPressed: null,';

  /// The child line(s).
  String bodyCode() => icon.value
      ? "icon: Icon(Icons.add), label: Text('Add'),"
      : "child: Text('Add'),";

  /// What the kind Switch calls.
  void setKind(Set<FilledKind> value) => kind.value = value.first;

  /// What the icon Switch calls.
  void setIcon(bool value) => icon.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final filledButton = FilledButtonViewModel();

/// `cat-filled-button`.
final filledButtonBench = BenchExample(
  title: (t) => t.exBtnFilledTitle,
  description: (t) => t.exBtnFilledDescription,
  stage: const _FilledButtonStage(),
  code: BenchCode([
    BenchCodeLine.live(filledButton.headCode),
    BenchCodeLine.live(filledButton.pressedCode, indent: 1),
    BenchCodeLine.live(filledButton.bodyCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<FilledKind>(
      label: (t) => t.exCatVariant,
      value: filledButton.kind.value,
      onChanged: filledButton.setKind,
      segments: [
        BenchSegment(FilledKind.filled, label: (t) => t.exBtnKindFilled),
        BenchSegment(FilledKind.tonal, label: (t) => t.exBtnKindTonal),
      ],
    ),
    boolSwitch(
      label: (t) => t.exCatIcon,
      value: filledButton.icon.value,
      onChanged: filledButton.setIcon,
    ),
    enabledSwitch(
      value: filledButton.enabled.value,
      onChanged: filledButton.setEnabled,
    ),
  ],
);

class _FilledButtonStage extends StatelessWidget {
  const _FilledButtonStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          filledButton.kind,
          builder: (kind) => Watch.field(
            filledButton.icon,
            builder: (icon) => Watch.field(
              filledButton.enabled,
              builder: (enabled) {
                final onPressed = enabled ? presses.add : null;
                const label = Text('Add');
                const glyph = Icon(Icons.add, size: 18);
                return switch ((kind, icon)) {
                  (FilledKind.filled, false) => FilledButton(
                    onPressed: onPressed,
                    child: label,
                  ),
                  (FilledKind.filled, true) => FilledButton.icon(
                    onPressed: onPressed,
                    icon: glyph,
                    label: label,
                  ),
                  (FilledKind.tonal, false) => FilledButton.tonal(
                    onPressed: onPressed,
                    child: label,
                  ),
                  (FilledKind.tonal, true) => FilledButton.tonalIcon(
                    onPressed: onPressed,
                    icon: glyph,
                    label: label,
                  ),
                };
              },
            ),
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}

// -------------------------------------------------------------- ElevatedButton

/// What the ElevatedButton panel controls.
class ElevatedButtonViewModel extends ThorState {
  /// With an icon.
  final icon = state(false);

  /// Whether `onPressed` is set.
  final enabled = state(true);

  /// The constructor line.
  String headCode() => icon.value ? 'ElevatedButton.icon(' : 'ElevatedButton(';

  /// The `onPressed` line.
  String pressedCode() =>
      enabled.value ? 'onPressed: presses.add,' : 'onPressed: null,';

  /// The child line.
  String bodyCode() => icon.value
      ? "icon: Icon(Icons.add), label: Text('Add'),"
      : "child: Text('Add'),";

  /// What the icon Switch calls.
  void setIcon(bool value) => icon.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final elevatedButton = ElevatedButtonViewModel();

/// `cat-elevated-button`.
final elevatedButtonBench = BenchExample(
  title: (t) => t.exBtnElevatedTitle,
  description: (t) => t.exBtnElevatedDescription,
  stage: const _ElevatedButtonStage(),
  code: BenchCode([
    BenchCodeLine.live(elevatedButton.headCode),
    BenchCodeLine.live(elevatedButton.pressedCode, indent: 1),
    BenchCodeLine.live(elevatedButton.bodyCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exCatIcon,
      value: elevatedButton.icon.value,
      onChanged: elevatedButton.setIcon,
    ),
    enabledSwitch(
      value: elevatedButton.enabled.value,
      onChanged: elevatedButton.setEnabled,
    ),
  ],
);

class _ElevatedButtonStage extends StatelessWidget {
  const _ElevatedButtonStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          elevatedButton.icon,
          builder: (icon) => Watch.field(
            elevatedButton.enabled,
            builder: (enabled) {
              final onPressed = enabled ? presses.add : null;
              return icon
                  ? ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    )
                  : ElevatedButton(
                      onPressed: onPressed,
                      child: const Text('Add'),
                    );
            },
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}

// ------------------------------------------------------- `.icon` constructors

/// The four button families that take `.icon`.
enum IconFamily {
  /// `FilledButton`.
  filled,

  /// `FilledButton.tonal`.
  tonal,

  /// `OutlinedButton`.
  outlined,

  /// `TextButton`.
  text,
}

/// What the `.icon` panel controls.
class IconLabelsViewModel extends ThorState {
  /// The family.
  final family = state(IconFamily.filled);

  /// With an icon.
  final icon = state(true);

  /// The constructor line.
  String headCode() {
    final base = switch (family.value) {
      IconFamily.filled || IconFamily.tonal => 'FilledButton',
      IconFamily.outlined => 'OutlinedButton',
      IconFamily.text => 'TextButton',
    };
    final tonal = family.value == IconFamily.tonal;
    final name = icon.value
        ? (tonal ? 'tonalIcon' : 'icon')
        : (tonal ? 'tonal' : '');
    return name.isEmpty ? '$base(' : '$base.$name(';
  }

  /// The child line.
  String bodyCode() => icon.value
      ? "icon: Icon(Icons.shopping_cart), label: Text('Order'),"
      : "child: Text('Order'),";

  /// What the family Switch calls.
  void setFamily(Set<IconFamily> value) => family.value = value.first;

  /// What the icon Switch calls.
  void setIcon(bool value) => icon.value = value;
}

/// One instance, at the top level.
final iconLabels = IconLabelsViewModel();

/// `cat-icon-labels`.
final iconLabelsBench = BenchExample(
  title: (t) => t.exBtnIconLabelsTitle,
  description: (t) => t.exBtnIconLabelsDescription,
  stage: const _IconLabelsStage(),
  code: BenchCode([
    BenchCodeLine.live(iconLabels.headCode),
    const BenchCodeLine('onPressed: presses.add,', indent: 1),
    BenchCodeLine.live(iconLabels.bodyCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<IconFamily>(
      stacked: true,
      label: (t) => t.exCatVariant,
      value: iconLabels.family.value,
      onChanged: iconLabels.setFamily,
      segments: [
        BenchSegment(IconFamily.filled, label: (t) => t.exBtnKindFilled),
        BenchSegment(IconFamily.tonal, label: (t) => t.exBtnKindTonal),
        BenchSegment(IconFamily.outlined, label: (t) => t.exBtnKindOutlined),
        BenchSegment(IconFamily.text, label: (t) => t.exBtnKindText),
      ],
    ),
    boolSwitch(
      label: (t) => t.exCatIcon,
      value: iconLabels.icon.value,
      onChanged: iconLabels.setIcon,
    ),
  ],
);

class _IconLabelsStage extends StatelessWidget {
  const _IconLabelsStage();

  @override
  Widget build(BuildContext context) {
    const label = Text('Order');
    const glyph = Icon(Icons.shopping_cart, size: 18);
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          iconLabels.family,
          builder: (family) => Watch.field(
            iconLabels.icon,
            builder: (icon) => switch ((family, icon)) {
              (IconFamily.filled, true) => FilledButton.icon(
                onPressed: presses.add,
                icon: glyph,
                label: label,
              ),
              (IconFamily.filled, false) => FilledButton(
                onPressed: presses.add,
                child: label,
              ),
              (IconFamily.tonal, true) => FilledButton.tonalIcon(
                onPressed: presses.add,
                icon: glyph,
                label: label,
              ),
              (IconFamily.tonal, false) => FilledButton.tonal(
                onPressed: presses.add,
                child: label,
              ),
              (IconFamily.outlined, true) => OutlinedButton.icon(
                onPressed: presses.add,
                icon: glyph,
                label: label,
              ),
              (IconFamily.outlined, false) => OutlinedButton(
                onPressed: presses.add,
                child: label,
              ),
              (IconFamily.text, true) => TextButton.icon(
                onPressed: presses.add,
                icon: glyph,
                label: label,
              ),
              (IconFamily.text, false) => TextButton(
                onPressed: presses.add,
                child: label,
              ),
            },
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}

// ------------------------------------------------- OutlinedButton / TextButton

/// What the OutlinedButton and TextButton panels control.
class LinkButtonViewModel extends ThorState {
  /// A link (`href:`) instead of a button.
  final link = state(false);

  /// Whether `onPressed` is set (a button only).
  final enabled = state(true);

  /// The `onPressed` / `href` lines of the Code view.
  String actionCode() => link.value
      ? "href: '/componentes/componentes',"
      : (enabled.value ? 'onPressed: presses.add,' : 'onPressed: null,');

  /// What the link Switch calls.
  void setLink(bool value) => link.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// The OutlinedButton panel's state.
final outlinedButton = LinkButtonViewModel();

/// The TextButton panel's state.
final textButton = LinkButtonViewModel();

BenchExample _linkBench({
  required String widget,
  required LinkButtonViewModel state,
  required Widget stage,
  required MessageOf title,
  required MessageOf description,
}) => BenchExample(
  title: title,
  description: description,
  stage: stage,
  code: BenchCode([
    BenchCodeLine('$widget('),
    BenchCodeLine.live(state.actionCode, indent: 1),
    const BenchCodeLine("child: Text('See components'),", indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    boolSwitch(
      label: (t) => t.exBtnLink,
      value: state.link.value,
      onChanged: state.setLink,
    ),
    enabledSwitch(value: state.enabled.value, onChanged: state.setEnabled),
  ],
);

/// `cat-outlined-button`.
final outlinedButtonBench = _linkBench(
  widget: 'OutlinedButton',
  state: outlinedButton,
  stage: const _LinkButtonStage(outlined: true),
  title: (t) => t.exBtnOutlinedTitle,
  description: (t) => t.exBtnOutlinedDescription,
);

/// `cat-text-button`.
final textButtonBench = _linkBench(
  widget: 'TextButton',
  state: textButton,
  stage: const _LinkButtonStage(outlined: false),
  title: (t) => t.exBtnTextTitle,
  description: (t) => t.exBtnTextDescription,
);

class _LinkButtonStage extends StatelessWidget {
  const _LinkButtonStage({required this.outlined});

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final state = outlined ? outlinedButton : textButton;
    final href = context.localized('/componentes/componentes');
    const label = Text('See components');
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          state.link,
          builder: (link) => Watch.field(
            state.enabled,
            builder: (enabled) {
              final onPressed = enabled && !link ? presses.add : null;
              final String? to = link ? href : null;
              final button = outlined
                  ? OutlinedButton(onPressed: onPressed, href: to, child: label)
                  : TextButton(onPressed: onPressed, href: to, child: label);
              // `// web:` a link is an <a>, not a <button>: the tag says so.
              return Column(
                spacing: 14,
                children: [
                  button,
                  ElementTag(
                    link
                        ? '<a href="$href">'
                        : (enabled ? '<button>' : '<button disabled>'),
                  ),
                ],
              );
            },
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}

// ------------------------------------------------------------------ IconButton

/// What the IconButton panel controls.
class IconButtonViewModel extends ThorState {
  /// The toggle: a favorite or not.
  final on = state(false);

  /// The icon's size, in steps of 4 px from 16.
  final size = state(2);

  /// Whether `onPressed` is set.
  final enabled = state(true);

  /// The pixels of the size Level.
  String sizeText() => '${16 + size.value * 4} px';

  /// The `iconSize` line of the Code view.
  String sizeCode() => 'iconSize: ${16 + size.value * 4},';

  /// The `onPressed` line.
  String pressedCode() =>
      enabled.value ? 'onPressed: favorite.toggle,' : 'onPressed: null,';

  /// What the button calls.
  void toggle() => on.value = !on.value;

  /// What the size Level calls.
  void setSize(double value) => size.value = ((value - 16) / 4).round();

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final favorite = IconButtonViewModel();

/// `cat-icon-button`.
final iconButtonBench = BenchExample(
  title: (t) => t.exBtnIconTitle,
  description: (t) => t.exBtnIconDescription,
  stage: const _IconButtonStage(),
  code: BenchCode([
    const BenchCodeLine('IconButton('),
    const BenchCodeLine('icon: Icon(Icons.favorite),', indent: 1),
    BenchCodeLine.live(favorite.sizeCode, indent: 1),
    const BenchCodeLine("tooltip: 'Add to favorites',", indent: 1),
    BenchCodeLine.live(favorite.pressedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    enabledSwitch(
      value: favorite.enabled.value,
      onChanged: favorite.setEnabled,
    ),
    pxLevel(
      label: (t) => t.exCatSize,
      value: 16 + favorite.size.value * 4,
      min: 16,
      max: 40,
      divisions: 6,
      onChanged: favorite.setSize,
      valueText: favorite.sizeText,
    ),
  ],
);

class _IconButtonStage extends StatelessWidget {
  const _IconButtonStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      favorite.size,
      count: 7,
      builder: (step) => Watch.field(
        favorite.enabled,
        builder: (enabled) => Watch.field(
          favorite.on,
          builder: (on) => IconButton(
            icon: const Icon(Icons.favorite),
            iconSize: 16.0 + step * 4,
            color: on ? const Color(0xFFE11D48) : ThemeColor.onSurfaceVariant,
            tooltip: on ? 'Remove from favorites' : 'Add to favorites',
            onPressed: enabled ? favorite.toggle : null,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- IconButton variants

/// The Material 3 icon button variants.
enum IconVariant {
  /// `IconButton`.
  standard,

  /// `IconButton.filled`.
  filled,

  /// `IconButton.filledTonal`.
  tonal,

  /// `IconButton.outlined`.
  outlined,
}

/// What the variants panel controls.
class IconButtonVariantsViewModel extends ThorState {
  /// The variant.
  final variant = state(IconVariant.filled);

  /// A link (`href:`) instead of an action.
  final link = state(false);

  /// Whether `onPressed` is set.
  final enabled = state(true);

  /// The constructor line.
  String headCode() => switch (variant.value) {
    IconVariant.standard => 'IconButton(',
    IconVariant.filled => 'IconButton.filled(',
    IconVariant.tonal => 'IconButton.filledTonal(',
    IconVariant.outlined => 'IconButton.outlined(',
  };

  /// The action line.
  String actionCode() => link.value
      ? "href: '/componentes/componentes',"
      : (enabled.value ? 'onPressed: presses.add,' : 'onPressed: null,');

  /// What the variant Switch calls.
  void setVariant(Set<IconVariant> value) => variant.value = value.first;

  /// What the link Switch calls.
  void setLink(bool value) => link.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final iconButtonVariants = IconButtonVariantsViewModel();

/// `cat-icon-button-variants`.
final iconVariantsBench = BenchExample(
  title: (t) => t.exBtnVariantsTitle,
  description: (t) => t.exBtnVariantsDescription,
  stage: const _IconVariantsStage(),
  code: BenchCode([
    BenchCodeLine.live(iconButtonVariants.headCode),
    BenchCodeLine.live(iconButtonVariants.actionCode, indent: 1),
    const BenchCodeLine("tooltip: 'Settings',", indent: 1),
    const BenchCodeLine('icon: Icon(Icons.settings),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<IconVariant>(
      stacked: true,
      label: (t) => t.exCatVariant,
      value: iconButtonVariants.variant.value,
      onChanged: iconButtonVariants.setVariant,
      segments: [
        BenchSegment(IconVariant.standard, label: (t) => t.exBtnVarStandard),
        BenchSegment(IconVariant.filled, label: (t) => t.exBtnKindFilled),
        BenchSegment(IconVariant.tonal, label: (t) => t.exBtnKindTonal),
        BenchSegment(IconVariant.outlined, label: (t) => t.exBtnKindOutlined),
      ],
    ),
    boolSwitch(
      label: (t) => t.exBtnLink,
      value: iconButtonVariants.link.value,
      onChanged: iconButtonVariants.setLink,
    ),
    enabledSwitch(
      value: iconButtonVariants.enabled.value,
      onChanged: iconButtonVariants.setEnabled,
    ),
  ],
);

class _IconVariantsStage extends StatelessWidget {
  const _IconVariantsStage();

  @override
  Widget build(BuildContext context) {
    final href = context.localized('/componentes/componentes');
    const glyph = Icon(Icons.settings);
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          iconButtonVariants.variant,
          builder: (variant) => Watch.field(
            iconButtonVariants.link,
            builder: (link) => Watch.field(
              iconButtonVariants.enabled,
              builder: (enabled) {
                final onPressed = enabled && !link ? presses.add : null;
                final String? to = link ? href : null;
                const tooltip = 'Settings';
                final tag = link
                    ? '<a href="$href">'
                    : (enabled ? '<button>' : '<button disabled>');
                final button = switch (variant) {
                  IconVariant.standard => IconButton(
                    onPressed: onPressed,
                    href: to,
                    tooltip: tooltip,
                    icon: glyph,
                  ),
                  IconVariant.filled => IconButton.filled(
                    onPressed: onPressed,
                    href: to,
                    tooltip: tooltip,
                    icon: glyph,
                  ),
                  IconVariant.tonal => IconButton.filledTonal(
                    onPressed: onPressed,
                    href: to,
                    tooltip: tooltip,
                    icon: glyph,
                  ),
                  IconVariant.outlined => IconButton.outlined(
                    onPressed: onPressed,
                    href: to,
                    tooltip: tooltip,
                    icon: glyph,
                  ),
                };
                return Column(spacing: 14, children: [button, ElementTag(tag)]);
              },
            ),
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}

// ------------------------------------------------------ FloatingActionButton

/// The sizes of a floating action button.
enum FabSize {
  /// `FloatingActionButton.small`.
  small,

  /// `FloatingActionButton`.
  regular,

  /// `FloatingActionButton.large`.
  large,

  /// `FloatingActionButton.extended`.
  extended,
}

/// What the FAB panel controls.
class FabViewModel extends ThorState {
  /// The size.
  final size = state(FabSize.regular);

  /// The constructor line.
  String headCode() => switch (size.value) {
    FabSize.small => 'FloatingActionButton.small(',
    FabSize.regular => 'FloatingActionButton(',
    FabSize.large => 'FloatingActionButton.large(',
    FabSize.extended => 'FloatingActionButton.extended(',
  };

  /// The child line.
  String bodyCode() => size.value == FabSize.extended
      ? "icon: Icon(Icons.edit), label: Text('Compose'),"
      : "tooltip: 'Add', child: Icon(Icons.add),";

  /// What the size Switch calls.
  void setSize(Set<FabSize> value) => size.value = value.first;
}

/// One instance, at the top level.
final fab = FabViewModel();

/// `cat-fab`.
final fabBench = BenchExample(
  title: (t) => t.exBtnFabTitle,
  description: (t) => t.exBtnFabDescription,
  stage: const _FabStage(),
  code: BenchCode([
    BenchCodeLine.live(fab.headCode),
    const BenchCodeLine('onPressed: presses.add,', indent: 1),
    BenchCodeLine.live(fab.bodyCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<FabSize>(
      stacked: true,
      label: (t) => t.exCatSize,
      value: fab.size.value,
      onChanged: fab.setSize,
      segments: [
        BenchSegment(FabSize.small, label: (t) => t.exCatSmall),
        BenchSegment(FabSize.regular, label: (t) => t.exCatMedium),
        BenchSegment(FabSize.large, label: (t) => t.exCatLarge),
        BenchSegment(FabSize.extended, label: (t) => t.exBtnFabExtended),
      ],
    ),
  ],
);

class _FabStage extends StatelessWidget {
  const _FabStage();

  @override
  Widget build(BuildContext context) {
    const add = Icon(Icons.add);
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          fab.size,
          builder: (size) => switch (size) {
            FabSize.small => FloatingActionButton.small(
              onPressed: presses.add,
              tooltip: 'Add',
              child: add,
            ),
            FabSize.regular => FloatingActionButton(
              onPressed: presses.add,
              tooltip: 'Add',
              child: add,
            ),
            FabSize.large => FloatingActionButton.large(
              onPressed: presses.add,
              tooltip: 'Add',
              child: add,
            ),
            FabSize.extended => FloatingActionButton.extended(
              onPressed: presses.add,
              icon: const Icon(Icons.edit),
              label: const Text('Compose'),
            ),
          },
        ),
        const PressesLabel(),
      ],
    );
  }
}

// ---------------------------------------------------------------- ButtonStyle

/// The shapes of the styled button.
enum StyleShape {
  /// `RoundedRectangleBorder`.
  rounded,

  /// `StadiumBorder`.
  stadium,
}

/// What the ButtonStyle panel controls.
class ButtonStyleViewModel extends ThorState {
  /// The shape.
  final shape = state(StyleShape.rounded);

  /// The corner radius of a rounded shape, in px.
  final radius = state(8.0);

  /// The horizontal padding, in px.
  final padding = state(28.0);

  /// The number next to the radius Level.
  String radiusText() => '${radius.value.round()} px';

  /// The number next to the padding Level.
  String paddingText() => '${padding.value.round()} px';

  /// The `padding` line of the Code view.
  String paddingCode() =>
      'padding: EdgeInsets.symmetric(horizontal: ${padding.value.round()}, vertical: 14),';

  /// The `shape` line.
  String shapeCode() => shape.value == StyleShape.stadium
      ? 'shape: StadiumBorder(),'
      : 'shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(${radius.value.round()})),';

  /// What the shape Switch calls.
  void setShape(Set<StyleShape> value) => shape.value = value.first;

  /// What the radius Level calls.
  void setRadius(double value) => radius.value = value;

  /// What the padding Level calls.
  void setPadding(double value) => padding.value = value;
}

/// One instance, at the top level.
final buttonStyle = ButtonStyleViewModel();

/// `cat-button-style`.
final buttonStyleBench = BenchExample(
  title: (t) => t.exBtnStyleTitle,
  description: (t) => t.exBtnStyleDescription,
  stage: const _ButtonStyleStage(),
  code: BenchCode([
    const BenchCodeLine('FilledButton('),
    const BenchCodeLine('onPressed: presses.add,', indent: 1),
    const BenchCodeLine('style: FilledButton.styleFrom(', indent: 1),
    BenchCodeLine.live(buttonStyle.paddingCode, indent: 2),
    BenchCodeLine.live(buttonStyle.shapeCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine("child: Text('Pay'),", indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<StyleShape>(
      label: (t) => t.exBtnShape,
      value: buttonStyle.shape.value,
      onChanged: buttonStyle.setShape,
      segments: [
        BenchSegment(StyleShape.rounded, label: (t) => t.exBtnShapeRounded),
        BenchSegment(StyleShape.stadium, label: (t) => t.exBtnShapeStadium),
      ],
    ),
    pxLevel(
      label: (t) => t.exBtnRadius,
      value: buttonStyle.radius.value,
      min: 0,
      max: 28,
      divisions: 14,
      onChanged: buttonStyle.setRadius,
      valueText: buttonStyle.radiusText,
    ),
    pxLevel(
      label: (t) => t.exBtnPadding,
      value: buttonStyle.padding.value,
      min: 12,
      max: 48,
      divisions: 18,
      onChanged: buttonStyle.setPadding,
      valueText: buttonStyle.paddingText,
    ),
  ],
);

class _ButtonStyleStage extends StatelessWidget {
  const _ButtonStyleStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          buttonStyle.shape,
          builder: (shape) => FilledButton(
            onPressed: presses.add,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: const Color(0xFFFFFFFF),
              // `// web:` a value a control drags follows the state in the
              // browser (`BoundLength`).
              padding: EdgeInsetsGeometry.symmetricLength(
                horizontal: buttonStyle.padding.px,
                vertical: const Length.px(14),
              ),
              shape: shape == StyleShape.stadium
                  ? const StadiumBorder()
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circularLength(
                        buttonStyle.radius.px,
                      ),
                    ),
            ),
            child: const Text('Pay'),
          ),
        ),
        const PressesLabel(),
      ],
    );
  }
}
