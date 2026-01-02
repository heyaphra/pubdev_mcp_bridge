/// CLI runner for pubdev_mcp_bridge.
library;

import 'package:args/command_runner.dart';

import '../version.dart';
import 'commands/clean_command.dart';
import 'commands/extract_command.dart';
import 'commands/list_command.dart';
import 'commands/serve_command.dart';

/// CLI runner for pubdev_mcp_bridge commands.
class PubdevMcpBridgeRunner extends CommandRunner<int> {
  PubdevMcpBridgeRunner()
    : super(
        'pubdev_mcp_bridge',
        'Generate MCP servers from pub.dev package documentation.',
      ) {
    argParser.addFlag('version', negatable: false, help: 'Print the version.');

    addCommand(ServeCommand());
    addCommand(ExtractCommand());
    addCommand(ListCommand());
    addCommand(CleanCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final results = parse(args);

      if (results['version'] as bool) {
        print('pubdev_mcp_bridge version $packageVersion');
        return 0;
      }

      return await runCommand(results) ?? 0;
    } on UsageException catch (e) {
      print(e);
      return 64; // EX_USAGE
    }
  }
}
