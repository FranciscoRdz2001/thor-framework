import 'dart:io';

import 'package:args/command_runner.dart';

import '../render/mcp.dart';

/// `thor mcp`: an MCP server (stdio) with `render` and `error_code`, for
/// AI agents. Register it once in your MCP client, e.g.
/// `<client> mcp add thor -- thor mcp --app .`.
class McpCommand extends Command<int> {
  /// The command.
  McpCommand() {
    argParser.addOption(
      'app',
      abbr: 'a',
      help: 'The app tools use when a call names none; default: this folder.',
    );
  }

  @override
  String get name => 'mcp';

  @override
  String get description =>
      'MCP server (stdio) for AI agents: render a route or widget, explain '
      'a THOR error code.';

  @override
  Future<int> run() async {
    await serveMcp(
      input: stdin,
      output: stdout,
      defaultApp: argResults!['app'] as String?,
    );
    return 0;
  }
}
