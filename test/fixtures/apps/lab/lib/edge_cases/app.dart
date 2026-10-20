// Every case is tagged with a `case-*` class (via Styled) so the browser
// audit can find it.
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import 'autocomplete_cases.dart';
import 'color_cycler.dart';
import 'dropdown_menus.dart';
import 'feedback_cases.dart';
import 'focus_edge.dart';
import 'focus_swap.dart';
import 'pending_tiles.dart';

const _long = 'Supercalifragilisticoespialidoso_sin_espacios_1234567890';

Widget _case(String name, Widget child) => Styled(
  classes: ['case-$name'],
  child: Container(padding: const EdgeInsets.all(8), child: child),
);

Widget _box(String label, Color color) => Container(
  width: 60,
  height: 40,
  alignment: Alignment.center,
  color: color,
  child: Text(label, style: const TextStyle(color: Colors.white)),
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(),
      darkData: ThemeData.dark(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _case(
            'flex',
            Column(
              spacing: 8,
              children: [
                _box('1', Colors.blue),
                _box('2', Colors.green),
                _box('3', Colors.red),
              ],
              layout: const FlexLayout().when(
                medium: const FlexLayout(
                  direction: Axis.horizontal,
                  spacing: 24,
                ),
              ),
            ),
          ),
          _case(
            'layout',
            ResponsiveLayout(
              mobile: Row(children: [_box('M', Colors.teal)]),
              tablet: _box('T', Colors.orange),
              desktop: Column(children: [_box('D', Colors.purple)]),
            ),
          ),
          _case(
            'container',
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                SizedBox(width: 260, child: LayoutScope(child: _grid('side'))),
                Expanded(child: LayoutScope(child: _grid('main'))),
              ],
            ),
          ),
          // Non-happy: a LayoutScope that sizes to its content collapses.
          _case(
            'collapse',
            const Row(children: [LayoutScope(child: Text('collapsed?'))]),
          ),
          _case(
            'dark',
            const Container(
              padding: EdgeInsets.all(8),
              color: Color.variable(CssVariable('--t-surface')),
              child: Text('themed'),
            ),
          ),
          _case(
            'rtl',
            html.div(
              attributes: const {'dir': 'rtl'},
              [
                Row(
                  children: [_box('A', Colors.blue), _box('B', Colors.green)],
                ),
                const Container(
                  width: 200,
                  height: 50,
                  color: Colors.black12,
                  alignment: Alignment.centerLeft,
                  child: Text('L'),
                ),
              ],
            ),
          ),
          _case('longword', const SizedBox(width: 120, child: Text(_long))),
          _case(
            'ellipsis',
            const SizedBox(
              width: 200,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      _long,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('!'),
                ],
              ),
            ),
          ),
          _case(
            'overflow',
            const SizedBox(width: 200, child: Row(children: [Text('$_long!')])),
          ),
          // Negative padding / opacity > 1 now assert at build time (like
          // Flutter); these are invalid values the browser must drop.
          _case(
            'invalid',
            const Container(
              color: Color.css('not-a-color'),
              child: Text(
                'invalid values',
                style: TextStyle(fontFamily: '###'),
              ),
            ),
          ),
          _case(
            'orphan',
            const Container(child: Expanded(child: Text('orphan Expanded'))),
          ),
          _case(
            'hover',
            Container(
              width: 100,
              height: 40,
              color: Colors.blue.when(hover: Colors.red),
            ),
          ),
          _case('unicode', const Text('Café ☕ 𝄞 日本語 🇲🇽 <b>not bold</b>')),
          _case(
            'empty',
            const Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal),
                ),
                GridView.count(crossAxisCount: 3),
                Wrap(),
              ],
            ),
          ),
          _case('island', const ColorCycler()),
          _case('dropdown-menu', const DropdownMenus()),
          _case('autocomplete', const AutocompleteCases()),
          _case('autocomplete-rows', const AutocompleteRows()),
          _case('tile-secondary', const PendingTiles()),
          _case('focus-swap', const FocusSwap()),
          _case('focus-edge', const FocusEdge()),
          _case('feedback', const FeedbackCases()),
        ],
      ),
    );
  }

  static Widget _grid(String name) => GridView.count(
    crossAxisCount: 1,
    layout: const GridLayout().when(
      container: {
        400: const GridLayout(columns: 2),
        700: const GridLayout(columns: 4),
      },
    ),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 2,
    children: [for (var i = 0; i < 4; i++) _box('$name$i', Colors.blueGrey)],
  );
}
