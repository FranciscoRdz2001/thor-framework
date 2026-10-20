/// `:::bench bench-overlay`: the dialogs reference example. A Switch picks
/// what opens (an `AlertDialog`, a bottom sheet or a drawer);
/// the stage has the real overlay, and the browser opens, traps the focus in
/// and closes it with Esc.
///
/// The three overlays are `Watch.field` variants the server compiled: the
/// browser only shows one of them, so they all share one `id`.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// What the trigger opens.
enum OverlayKind {
  /// An `AlertDialog`.
  dialog,

  /// A `ModalBottomSheet`.
  sheet,

  /// A `Drawer`.
  drawer,
}

/// What the panel controls and the stage reads.
class OverlayViewModel extends ThorState {
  /// What opens.
  final kind = state(OverlayKind.dialog);

  /// The widget's line of the Code view.
  String widgetCode() => switch (kind.value) {
    OverlayKind.dialog => 'AlertDialog(',
    OverlayKind.sheet => 'ModalBottomSheet(',
    OverlayKind.drawer => 'Drawer(',
  };

  /// The `id` line of the Code view.
  String idCode() => "id: 'demo',";

  /// The line that tells the overlays apart.
  String extraCode() => switch (kind.value) {
    OverlayKind.dialog => 'barrierDismissible: true,',
    OverlayKind.sheet => 'showDragHandle: true,',
    OverlayKind.drawer => 'side: DrawerSide.start,',
  };

  /// The content line: an `AlertDialog` has `content`, the others a `child`.
  String contentCode() => kind.value == OverlayKind.dialog
      ? 'content: Content(),'
      : 'child: Content(),';

  /// What the Switch calls.
  void setKind(Set<OverlayKind> value) => kind.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final overlay = OverlayViewModel();

/// The example: a Switch, the stage and its code.
final overlayBench = BenchExample(
  title: (t) => t.exUiOverlayTitle,
  description: (t) => t.exUiOverlayDescription,
  stage: const OverlayStage(),
  code: BenchCode([
    const BenchCodeLine("DialogTrigger(id: 'demo', child: OpenButton()),"),
    BenchCodeLine.live(overlay.widgetCode),
    BenchCodeLine.live(overlay.idCode, indent: 1),
    BenchCodeLine.live(overlay.extraCode, indent: 1),
    BenchCodeLine.live(overlay.contentCode, indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<OverlayKind>(
      label: (t) => t.exUiOverlayKind,
      value: overlay.kind.value,
      onChanged: overlay.setKind,
      segments: [
        BenchSegment(OverlayKind.dialog, label: (t) => t.exUiOverlayDialog),
        BenchSegment(OverlayKind.sheet, label: (t) => t.exUiOverlaySheet),
        BenchSegment(OverlayKind.drawer, label: (t) => t.exUiOverlayDrawer),
      ],
    ),
  ],
);

/// The stage: the button and the overlay the Switch chose.
class OverlayStage extends StatelessWidget {
  /// The stage of the example.
  const OverlayStage({super.key});

  @override
  Widget build(BuildContext context) =>
      Watch.field(overlay.kind, builder: (kind) => _OverlayDemo(kind: kind));
}

/// A small screen that shows where the overlay will appear when the button
/// is pressed: a box in the middle, a panel at the bottom or one at the side.
class _Preview extends StatelessWidget {
  const _Preview({required this.kind});

  final OverlayKind kind;

  @override
  Widget build(BuildContext context) {
    final panel = BoxDecoration(
      color: ThemeColor.primary,
      borderRadius: BorderRadius.circular(8),
    );
    return Container(
      width: 320,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ThemeColor.surfaceContainer,
        border: Border.all(color: ThemeColor.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: switch (kind) {
          OverlayKind.dialog => Alignment.center,
          OverlayKind.sheet => Alignment.bottomCenter,
          OverlayKind.drawer => Alignment.centerLeft,
        },
        children: [
          switch (kind) {
            OverlayKind.dialog => Container(
              width: 180,
              height: 100,
              decoration: panel,
            ),
            OverlayKind.sheet => Container(
              width: double.infinity,
              height: 84,
              decoration: panel,
            ),
            OverlayKind.drawer => Container(
              width: 120,
              height: double.infinity,
              decoration: panel,
            ),
          },
        ],
      ),
    );
  }
}

class _OverlayDemo extends StatelessWidget {
  const _OverlayDemo({required this.kind});

  final OverlayKind kind;

  @override
  Widget build(BuildContext context) {
    // One id for every variant: the browser swaps the content of the same
    // elements, and the trigger keeps the `commandfor` it was drawn with.
    const id = 'bench-overlay';
    const content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            'Confirm order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        Text('We will email you the receipt.'),
        DialogClose(child: FilledButton(child: Text('Done'))),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        _Preview(kind: kind),
        const DialogTrigger(
          id: id,
          child: OutlinedButton(child: Text('Open')),
        ),
        switch (kind) {
          OverlayKind.dialog => const AlertDialog(
            id: id,
            title: Text('Confirm order'),
            content: Text('We will email you the receipt.'),
            actions: [DialogClose(child: FilledButton(child: Text('Done')))],
          ),
          OverlayKind.sheet => const ModalBottomSheet(
            id: id,
            label: 'Confirm order',
            child: content,
          ),
          OverlayKind.drawer => const Drawer(
            id: id,
            label: 'Confirm order',
            side: DrawerSide.start,
            child: content,
          ),
        },
      ],
    );
  }
}
