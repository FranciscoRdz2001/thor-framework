## What and why

<!-- The change and the case that needs it. Link the issue it closes. -->

## How it was tested

<!-- The tests you added or ran, and the pages you checked in a browser. -->

## Checklist

- [ ] `tool/thor check` passes (format, analyze, tests). See CONTRIBUTING.md.
- [ ] New behavior has a test; a change to the render core has a test in
      `core_test.dart` and `tool/golden.sh check` passes.
- [ ] Public API: nothing exported was removed or renamed without
      `@Deprecated('Use X')` for one minor version, `tool/thor docs` and a
      line in the package's `CHANGELOG.md`.
- [ ] Each unavoidable difference from Flutter has a `// web:` comment.
