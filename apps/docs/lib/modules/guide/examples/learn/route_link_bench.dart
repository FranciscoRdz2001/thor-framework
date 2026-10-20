/// `:::bench bench-route-link`: the URL a `ThorRoute` builds. A Level sets the
/// `:id:int` param, a Switch the `status` of the query string; the address
/// bar and the `link(...)` call follow.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';

/// The values of the query Switch.
enum OrderFilter {
  /// No query string.
  none,

  /// `?status=open`.
  open,

  /// `?status=closed`.
  closed,
}

/// What the panel controls and the stage reads.
class RouteLinkViewModel extends ThorState {
  /// The `:id` of the path.
  final id = state(42);

  /// The `status` of the query.
  final filter = state(OrderFilter.none);

  /// The URL `link` returns.
  String urlText() {
    final path = '/sales/orders/${id.value}';
    return filter.value == OrderFilter.none
        ? path
        : '$path?status=${filter.value.name}';
  }

  /// The `link(...)` call of the Code view.
  String linkCode() => filter.value == OrderFilter.none
      ? "orderRoute.link({'id': ${id.value}})"
      : "orderRoute.link({'id': ${id.value}}, {'status': '${filter.value.name}'})";

  /// The `href` line of the Code view.
  String hrefCode() => 'href: ${linkCode()},';

  /// The number next to the Level.
  String idText() => '${id.value}';

  /// What the Level calls.
  void setId(double value) => id.value = value.round();

  /// What the Switch calls.
  void setFilter(Set<OrderFilter> value) => filter.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final routeLink = RouteLinkViewModel();

/// The example.
final routeLinkBench = BenchExample(
  title: (t) => t.exRoutesLinkTitle,
  description: (t) => t.exRoutesLinkDescription,
  stage: const RouteLinkStage(),
  code: BenchCode([
    const BenchCodeLine(
      "final orderRoute = ThorRoute('/sales/orders/:id:int', const OrderPage());",
    ),
    const BenchCodeLine(' '),
    const BenchCodeLine('Link('),
    BenchCodeLine.live(routeLink.hrefCode, indent: 1),
    const BenchCodeLine("child: Text('Order'),", indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<OrderFilter>(
      label: (t) => t.exRoutesLinkQuery,
      value: routeLink.filter.value,
      onChanged: routeLink.setFilter,
      segments: [
        BenchSegment(OrderFilter.none, label: (t) => t.exRoutesLinkNone),
        BenchSegment(OrderFilter.open, label: (t) => t.exRoutesLinkOpen),
        BenchSegment(OrderFilter.closed, label: (t) => t.exRoutesLinkClosed),
      ],
    ),
    BenchLevel(
      label: (t) => t.exRoutesLinkId,
      value: routeLink.id.value,
      min: 1,
      max: 99,
      divisions: 98,
      onChanged: routeLink.setId,
      valueText: routeLink.idText,
    ),
  ],
);

/// The stage: an address bar with the URL the route builds.
class RouteLinkStage extends StatelessWidget {
  /// The stage of the example.
  const RouteLinkStage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: ThemeColor.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Watch(
              routeLink.urlText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                color: ThemeColor.onSurface,
              ),
            ),
          ),
          Row(
            spacing: 6,
            children: [
              const Text(
                'Order',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              ),
              Watch(
                routeLink.idText,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
