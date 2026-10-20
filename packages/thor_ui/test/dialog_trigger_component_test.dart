@TestOn('vm')
library;

// `DialogTrigger(dialog:)` takes a component that builds the dialog.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _body(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(initializeThorTests);

  group('DialogTrigger(dialog:) with a component (29)', () {
    test('the component that builds the dialog takes the id', () async {
      final body = _body(
        await _page(
          const DialogTrigger(
            dialog: _ConfirmDialog(),
            child: FilledButton(child: Text('Open')),
          ),
        ),
      );
      final target = RegExp(r'commandfor="([^"]+)"').firstMatch(body)![1];
      expect(body, contains('<dialog'));
      expect(body, contains('id="$target"'));
      expect(body, contains('command="show-modal"'));
    });

    test('a rebuilt component still gives its dialog the id, once', () async {
      // The build walks its ancestors, so the preview is not reused: the
      // dialog built in place is another instance, matched by its type.
      final body = _body(
        await _page(
          const Column(
            children: [
              Dialog(child: Text('Other')),
              DialogTrigger(
                dialog: _WalkingDialog('component'),
                child: FilledButton(child: Text('Open')),
              ),
            ],
          ),
        ),
      );
      final target = RegExp(r'commandfor="([^"]+)"').firstMatch(body)![1];
      // The outer dialog has it; the one nested in it (another scope) not.
      expect(RegExp('id="$target"').allMatches(body), hasLength(1));
      expect(
        body,
        matches(RegExp('<dialog id="$target"[^>]*data-thor="AlertDialog"')),
      );
      // The titled one is the outer dialog.
      expect(body, contains('aria-labelledby="$target-title"'));
      expect(body, contains('Nested'));
    });

    test('a component that builds no dialog says so', () async {
      expect(
        () => _page(
          const DialogTrigger(
            dialog: _NotADialog(),
            child: FilledButton(child: Text('Open')),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('or a component that builds one'),
          ),
        ),
      );
    });
  });
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) => const AlertDialog(
    title: Text('Sure?'),
    actions: [DialogClose(child: TextButton(child: Text('No')))],
  );
}

class _NotADialog extends StatelessWidget {
  const _NotADialog();

  @override
  Widget build(BuildContext context) => const Text('no');
}

class _WalkingDialog extends StatelessWidget {
  const _WalkingDialog(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    context.visitAncestorElements((_) => false);
    return AlertDialog(
      title: Text('Create $name'),
      content: const AlertDialog(content: Text('Nested')),
    );
  }
}
