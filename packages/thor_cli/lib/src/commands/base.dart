import 'package:args/command_runner.dart';

import '../run.dart';
import '../workspace.dart';

/// A command on one project: named (`thor dev shop`, `thor dev ../shop`)
/// or the one the current folder is in.
mixin ProjectCommand<T> on Command<T> {
  /// The project the command acts on.
  Project resolveProject() {
    final rest = argResults!.rest;
    final project = Project.find(rest.isEmpty ? null : rest.first);
    if (project == null) {
      throw ThorException(
        rest.isEmpty
            ? 'Not inside a thor project (a pubspec that depends on '
                  'thor_ui). Create one with `thor create <name>`, or name '
                  'it: ${invocation.replaceAll('[project]', '<project>')}'
            : 'No thor project at "${rest.first}".',
      );
    }
    return project;
  }
}
