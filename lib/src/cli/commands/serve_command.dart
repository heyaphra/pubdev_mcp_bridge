/// Serve command - starts the MCP server for a package.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../extractor/extractor.dart';
import '../../server/mcp_server.dart';

/// Command to start the MCP server for a package.
class ServeCommand extends Command<int> {
  @override
  final String name = 'serve';

  @override
  final String description = 'Start an MCP server for a pub.dev package.';

  ServeCommand() {
    argParser
      ..addOption(
        'version',
        abbr: 'v',
        help: 'Package version (defaults to latest)',
      )
      ..addFlag(
        'refresh',
        abbr: 'r',
        help: 'Force refresh of cached documentation',
        negatable: false,
      );
  }

  @override
  Future<int> run() async {
    final args = argResults!;

    if (args.rest.isEmpty) {
      throw UsageException('Package name required', usage);
    }

    final packageName = args.rest.first;
    final version = args['version'] as String?;
    final forceRefresh = args['refresh'] as bool;

    // Extract or load package documentation
    final extractor = DocExtractor();
    try {
      stderr.writeln('Loading documentation for $packageName...');
      final package = await extractor.getPackage(
        packageName,
        version: version,
        forceRefresh: forceRefresh,
      );
      stderr.writeln('Loaded ${package.name}@${package.version}');
      stderr.writeln('Starting MCP server...');

      // Create stdio channel for MCP
      final channel = StreamChannel<String>(
        stdin.transform(utf8.decoder).transform(const LineSplitter()),
        StreamController<String>()
          ..stream.listen((line) => stdout.writeln(line)),
      );

      // Create and start server
      final server = PubdevMcpServer(
        channel: channel,
        package: package,
      );

      // The server runs until the channel is closed
      await server.done;

      return 0;
    } finally {
      extractor.close();
    }
  }
}
