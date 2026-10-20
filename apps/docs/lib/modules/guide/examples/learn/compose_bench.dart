/// `:::bench bench-compose`: a widget is a class made of other widgets. A
/// Switch lays the same `UserTile` out as a row or as a column, a Level says
/// how many of them the list shows. The class never changes.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _people = ['Ana', 'Luis', 'Marta'];

/// How the tiles are laid out.
enum ComposeAxis {
  /// A `Column` of tiles.
  column,

  /// A `Row` of tiles.
  row,
}

/// What the panel controls and the stage reads.
class ComposeViewModel extends ThorState {
  /// How many tiles, minus one.
  final count = state(2);

  /// Row or column.
  final axis = state(ComposeAxis.column);

  /// The container's line of the Code view.
  String containerCode() =>
      '${axis.value == ComposeAxis.row ? 'Row' : 'Column'}(';

  /// The tiles' lines of the Code view.
  String tilesCode() => [
    for (var i = 0; i <= count.value; i++) "UserTile(name: '${_people[i]}'),",
  ].join(' ');

  /// The number next to the Level.
  String countText() => '${count.value + 1}';

  /// What the Switch calls.
  void setAxis(Set<ComposeAxis> value) => axis.value = value.first;

  /// What the Level calls.
  void setCount(double value) => count.value = value.round() - 1;
}

/// One instance, at the top level: the browser boots with it.
final composeDemo = ComposeViewModel();

/// The example.
final composeBench = BenchExample(
  title: (t) => t.exWidgetsComposeTitle,
  description: (t) => t.exWidgetsComposeDescription,
  stage: const ComposeStage(),
  code: BenchCode([
    const BenchCodeLine('class UserTile extends StatelessWidget {'),
    const BenchCodeLine(
      'const UserTile({super.key, required this.name});',
      indent: 1,
    ),
    const BenchCodeLine('final String name;', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('@override', indent: 1),
    const BenchCodeLine(
      'Widget build(BuildContext context) => Row(',
      indent: 1,
    ),
    const BenchCodeLine('children: [Avatar(name), Text(name)],', indent: 2),
    const BenchCodeLine(');', indent: 1),
    const BenchCodeLine('}'),
    const BenchCodeLine(' '),
    BenchCodeLine.live(composeDemo.containerCode),
    BenchCodeLine.live(composeDemo.tilesCode, indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<ComposeAxis>(
      label: (t) => t.exWidgetsComposeAxis,
      value: composeDemo.axis.value,
      onChanged: composeDemo.setAxis,
      segments: [
        BenchSegment(
          ComposeAxis.column,
          label: (t) => t.exWidgetsComposeColumn,
        ),
        BenchSegment(ComposeAxis.row, label: (t) => t.exWidgetsComposeRow),
      ],
    ),
    BenchLevel(
      label: (t) => t.exWidgetsComposeCount,
      value: composeDemo.count.value + 1,
      min: 1,
      max: 3,
      divisions: 2,
      onChanged: composeDemo.setCount,
      valueText: composeDemo.countText,
    ),
  ],
);

/// The stage: the tiles, made by the same widget.
class ComposeStage extends StatelessWidget {
  /// The stage of the example.
  const ComposeStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    composeDemo.axis,
    builder: (axis) => Watch.field(
      composeDemo.count,
      count: _people.length,
      builder: (count) => LearnFrame(
        width: 480,
        height: 256,
        child: Flex(
          direction: axis == ComposeAxis.row ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: axis == ComposeAxis.row ? 8 : 12,
          children: [
            for (var i = 0; i <= count; i++)
              UserTile(name: _people[i], compact: axis == ComposeAxis.row),
          ],
        ),
      ),
    ),
  );
}

/// The widget of the example: an avatar and a name, two widgets that
/// already exist, joined in one class.
class UserTile extends StatelessWidget {
  /// A tile for [name].
  const UserTile({super.key, required this.name, this.compact = false});

  /// The person's name.
  final String name;

  /// A smaller tile, for when the tiles sit side by side.
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    spacing: compact ? 6 : 8,
    children: [
      LearnTile(
        label: name.substring(0, 1),
        width: compact ? 44 : 64,
        height: compact ? 44 : 64,
      ),
      Text(
        name,
        style: TextStyle(
          fontSize: compact ? 16 : 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
