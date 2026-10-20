import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:thor_cli/thor_cli.dart';

Future<void> main(List<String> args) async {
  final runner = thorRunner();
  try {
    exitCode = await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    exitCode = 64;
  } on ThorException catch (e) {
    Say.error(e.message);
    exitCode = e.exitCode;
  }
}
