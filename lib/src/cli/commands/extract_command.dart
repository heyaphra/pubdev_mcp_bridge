/// Extract command - extracts documentation without starting server.
library;

import 'dart:async';

import 'package:args/command_runner.dart';

import '../../extractor/extractor.dart';

/// Command to extract and cache package documentation.
class ExtractCommand extends Command<int> {
  @override
  final String name = 'extract';

  @override
  final String description =
      'Extract and cache documentation for a pub.dev package.';

  ExtractCommand() {
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

    final extractor = DocExtractor();
    try {
      print('Extracting documentation for $packageName...');
      final package = await extractor.getPackage(
        packageName,
        version: version,
        forceRefresh: forceRefresh,
      );

      print('Extracted ${package.name}@${package.version}');
      print('  Libraries: ${package.libraries.length}');
      print('  Classes: ${package.allClasses.length}');
      print('  Functions: ${package.allFunctions.length}');
      print('  Enums: ${package.allEnums.length}');

      return 0;
    } finally {
      extractor.close();
    }
  }
}
