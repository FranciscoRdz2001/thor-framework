// The page of the `expanded` browser check: `Expanded` in columns and rows
// whose main size is definite and not, rendered by the real widgets.
//
//   dart run packages/thor_ui/tool/expanded_page.dart <out.html>
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// A box of [height] with an id the check measures.
Widget box(String id, {double? height, double? width}) => Semantics(
  identifier: id,
  child: Container(
    height: height,
    width: width,
    color: const Color(0xFFCCDDEE),
  ),
);

/// A box that is [height] tall by its content, not by its own height: what
/// an auto-height Column's Expanded has to keep (`flex-basis: content`).
Widget content(String id, double height) => Semantics(
  identifier: id,
  child: Container(child: SizedBox(height: height)),
);

void main(List<String> args) async {
  initializeThorTests();
  final body = Column(
    spacing: 24,
    children: [
      // (a) a Column that grows with its content: the Expanded keeps its.
      Semantics(
        identifier: 'auto-col',
        child: Column(
          children: [
            box('auto-head', height: 40),
            Expanded(child: content('auto-body', 120)),
          ],
        ),
      ),
      // (a') a Column that is a row only from `lg`.
      Semantics(
        identifier: 'layout-col',
        child: Column(
          layout: const FlexLayout().when(
            expanded: const FlexLayout(direction: Axis.horizontal),
          ),
          children: [
            box('layout-side', height: 40, width: 100),
            Expanded(child: content('layout-body', 120)),
          ],
        ),
      ),
      // (b) a fixed height: the Expanded fills the rest exactly, and the
      // two of them share it by flex factor whatever their content.
      SizedBox(
        height: 300,
        child: Column(
          children: [
            box('fixed-head', height: 40),
            Expanded(child: box('fixed-a')),
            Expanded(flex: 2, child: box('fixed-b', height: 500)),
            box('fixed-foot', height: 20),
          ],
        ),
      ),
      // (b') a scroll area inside an Expanded still shrinks to its share.
      SizedBox(
        height: 200,
        child: Column(
          children: [
            box('scroll-head', height: 20),
            const Expanded(
              child: Semantics(
                identifier: 'scroll-area',
                child: SingleChildScrollView(
                  child: Container(height: 900, color: Color(0xFFEEDDCC)),
                ),
              ),
            ),
          ],
        ),
      ),
      // (d) siblings and nesting in a Column that grows with its content.
      Semantics(
        identifier: 'mix-col',
        child: Column(
          children: [
            box('mix-head', height: 30),
            Expanded(child: content('mix-a', 50)),
            const SizedBox(height: 10),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  box('mix-inner-head', height: 20),
                  Expanded(child: content('mix-inner', 70)),
                ],
              ),
            ),
          ],
        ),
      ),
      // (e) Flexible(loose) never grows past its content, definite or not.
      SizedBox(
        height: 300,
        child: Column(
          children: [
            Flexible(child: content('loose-fixed', 60)),
            box('loose-foot', height: 20),
          ],
        ),
      ),
      Column(
        children: [
          Flexible(child: content('loose-auto', 60)),
          box('loose-auto-foot', height: 20),
        ],
      ),
      // (f) a Row of intrinsic-width children: Expanded still takes the rest.
      SizedBox(
        width: 300,
        child: Row(
          children: [
            const Container(
              child: SizedBox(width: 80, height: 10),
              color: Color(0xFFDDDDDD),
            ),
            Expanded(child: box('row-intrinsic', height: 20)),
            const Container(
              child: SizedBox(width: 60, height: 10),
              color: Color(0xFFDDDDDD),
            ),
          ],
        ),
      ),
      // (c) rows: the Expanded takes the rest of a definite width.
      SizedBox(
        width: 300,
        child: Row(
          children: [
            box('row-side', width: 100, height: 20),
            Expanded(child: box('row-a', height: 20)),
            Expanded(flex: 2, child: box('row-b', height: 20)),
          ],
        ),
      ),
    ],
  );
  File(args.single).writeAsStringSync(
    await renderDocument(ThorApp(child: SingleChildScrollView(child: body))),
  );
}
