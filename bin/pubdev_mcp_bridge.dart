/// Entry point for the pubdev_mcp_bridge CLI tool.
library;

import 'dart:io';

import 'package:pubdev_mcp_bridge/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  final runner = PubdevMcpBridgeRunner();
  final exitCode = await runner.run(args);
  exit(exitCode);
}
