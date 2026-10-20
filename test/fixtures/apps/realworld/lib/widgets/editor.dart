import 'package:thor_engine/thor_engine.dart' show keyToken;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../editor_state.dart';
import '../router.dart';
import '../session.dart';
import '../ui.dart';
import 'auth.dart' show FormFailure;
import 'fields.dart';
import 'nav.dart' show ConduitIcons, ionIcon;

/// The editor's action methods, shared by the new and the edit page:
/// `publish` (create or update, then open the article) and, for the no-JS
/// path, `addTag` / `removeTag`, which render the editor again with the
/// tags changed (with JS the engine does both).
mixin EditorActions<T> on ThorPage<T> {
  /// Whether the page edits an existing article (`/editor/:slug`).
  bool get updates;

  /// Creates or updates the article, then opens it.
  Future<ActionResult?> publish(PageRequest request) async {
    final user = request.signedIn;
    final (form, tags) = await _read(request);
    final article = {
      'title': form['title'] ?? '',
      'description': form['description'] ?? '',
      'body': form['body'] ?? '',
      'tagList': tags,
    };
    try {
      final slug = updates
          ? await api.updateArticle(
              user.token,
              request.pathParameters['slug']!,
              article,
            )
          : await api.createArticle(user.token, article);
      return Redirect(articleRoute.link({'slug': slug}));
    } on ApiErrors catch (e) {
      return ActionResult.fail(
        422,
        FormFailure(e.messages, _values(form, tags)),
      );
    }
  }

  /// The editor again with the typed tag added (no JS).
  Future<ActionResult?> addTag(PageRequest request) async {
    final (form, tags) = await _read(request);
    return ActionResult.success(FormFailure(const [], _values(form, tags)));
  }

  /// The editor again without the `?tag=` of the pill's button (no JS).
  Future<ActionResult?> removeTag(PageRequest request) async {
    final (form, tags) = await _read(request);
    final gone = request.queryParameters['tag'];
    return ActionResult.success(
      FormFailure(
        const [],
        _values(form, [
          for (final t in tags)
            if (t != gone) t,
        ]),
      ),
    );
  }
}

/// The form and its tags: the hidden `tag` fields (one per pill) plus the
/// tag field's text (comma or space separated), deduplicated.
Future<(FormData, List<String>)> _read(PageRequest request) async {
  final form = await request.form();
  final typed = (form['tagInput'] ?? '')
      .split(RegExp(r'[,\s]+'))
      .where((t) => t.isNotEmpty);
  return (form, {...form.all('tag'), ...typed}.toList());
}

Map<String, String> _values(FormData form, List<String> tags) => {
  for (final k in const ['title', 'description', 'body']) k: form[k] ?? '',
  'tags': tags.join(','),
};

/// The editor form.
class EditorView extends StatelessWidget implements ThorElementWidget {
  /// For [article] (`null`: a new one), after a [failure]; [page] owns
  /// the actions.
  const EditorView({super.key, required this.page, this.article, this.failure});

  /// The editor page (its action methods).
  final EditorActions<Object?> page;

  /// The article being edited.
  final Article? article;

  /// A failed submit (its values win).
  final FormFailure? failure;

  @override
  Widget build(BuildContext context) {
    final v = failure?.values;
    String? value(String k, String? fallback) => v?[k] ?? fallback;
    // The tags the page starts with (the browser continues from them).
    tagEditor.tags.value = v != null
        ? [
            for (final t in (v['tags'] ?? '').split(','))
              if (t.isNotEmpty) t,
          ]
        : article?.tagList ?? const [];
    return cls(
      'editor-page',
      PageContainer(
        classes: 'container page',
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: GridRow(
            children: [
              Col(
                xs: 12,
                md: 10,
                offset: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErrorMessages(failure?.messages ?? const []),
                    Form(
                      onPost: page.publish,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          formField(
                            name: 'title',
                            hint: 'Article Title',
                            large: true,
                            initialValue: value('title', article?.title),
                          ),
                          formField(
                            name: 'description',
                            hint: "What's this article about?",
                            initialValue: value(
                              'description',
                              article?.description,
                            ),
                          ),
                          formField(
                            name: 'body',
                            hint: 'Write your article (in markdown)',
                            lines: 8,
                            initialValue: value('body', article?.body),
                          ),
                          // Without JS, Enter in the tag field "clicks" the
                          // form's first submit button: this one, which adds
                          // the tag (the engine handles Enter otherwise).
                          _AddTagButton(page.addTag),
                          cls(
                            'form-group',
                            TextField(
                              name: 'tagInput',
                              onSubmitted: tagEditor.add,
                              clearOnSubmitted: true,
                              inputAttributes: HtmlAttributes.custom({
                                'class': 'form-control',
                              }),
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.25,
                                color: Color(0xFF55595C),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter tags',
                                hintStyle: const TextStyle(color: muted),
                                filled: true,
                                fillColor: white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: hairline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: brand),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Watch.list(
                              tagEditor.tags,
                              itemKey: tagEditor.tagKey,
                              container: (rows) =>
                                  cls('tag-list', Wrap(children: rows)),
                              each: (row) => cls(
                                'tag-default tag-pill',
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      buttonType: ButtonType.submit,
                                      // The tag travels in the query.
                                      formAction:
                                          '${formActionUrl(page.removeTag)}&tag=${row.key == keyToken ? row.key : Uri.encodeQueryComponent(row.key)}',
                                      onPressed: tagEditor.remove.withArg(
                                        row.key,
                                      ),
                                      style: const ButtonStyle(
                                        padding: WidgetStatePropertyAll(
                                          EdgeInsets.only(right: 5),
                                        ),
                                        minimumSize: WidgetStatePropertyAll(
                                          Size(0, 0),
                                        ),
                                      ),
                                      child: ionIcon(
                                        'ion-close-round',
                                        ConduitIcons.close,
                                        size: 10,
                                      ),
                                    ),
                                    row.text(tagEditor.tagName),
                                    row.field('tag', tagEditor.tagName),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: submitButton(
                              'Publish Article',
                              ButtonKind.primary,
                              size: ButtonSize.large,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton(this.addTag);

  final PagePost addTag;

  @override
  Widget build(BuildContext context) => html.button(
    attributes: {
      'type': 'submit',
      'formaction': formActionUrl(addTag),
      'tabindex': '-1',
      'aria-hidden': 'true',
      // Visually hidden, but still the form's default button.
      'style':
          'position:absolute;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip:rect(0,0,0,0);border:0',
    },
    const [Widget.text('Add tag')],
  );
}
