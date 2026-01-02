/// Clean command - removes cached packages.
library;

import 'dart:async';

import 'package:args/command_runner.dart';

import '../../cache/cache_manager.dart';

/// Command to remove cached packages.
class CleanCommand extends Command<int> {
  @override
  final String name = 'clean';

  @override
  final String description = 'Remove cached packages.';

  CleanCommand() {
    argParser
      ..addOption('version', abbr: 'v', help: 'Specific version to remove')
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Remove all cached packages',
        negatable: false,
      );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    final cache = CacheManager.defaultLocation();

    if (args['all'] as bool) {
      await cache.clearAll();
      print('Cleared all cached packages.');
      return 0;
    }

    if (args.rest.isEmpty) {
      throw UsageException('Package name required (or use --all)', usage);
    }

    final packageName = args.rest.first;
    final version = args['version'] as String?;

    if (version != null) {
      await cache.clearPackage(packageName, version);
      print('Cleared $packageName@$version');
    } else {
      // Clear all versions of the package
      final packages = await cache.listCached();
      final matching = packages.where((p) => p.name == packageName);
      for (final pkg in matching) {
        await cache.clearPackage(pkg.name, pkg.version);
      }
      print('Cleared all versions of $packageName');
    }

    return 0;
  }
}
