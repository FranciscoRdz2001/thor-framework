import 'dart:io';

/// The signals that stop a long-running command (`thor dev`, `thor preview`).
///
/// POSIX: Ctrl-C, `kill` and the terminal closing. Windows: only
/// [ProcessSignal.sigint] (Ctrl-C and Ctrl-Break); Dart's `ProcessSignal`
/// docs list `sigterm` and `sighup` as unsupported there, and watching them
/// fails.
// web: Windows closing the console window is not a signal Dart delivers, so
// the children are only stopped by Ctrl-C there. Not verified on Windows.
List<ProcessSignal> stopSignals({bool? windows}) => [
  ProcessSignal.sigint,
  if (!(windows ?? Platform.isWindows)) ...[
    ProcessSignal.sigterm,
    ProcessSignal.sighup,
  ],
];
