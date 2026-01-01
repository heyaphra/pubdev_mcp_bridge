/// List command - lists cached packages.
library;

import 'dart:async';

import 'package:args/command_runner.dart';

import '../../cache/cache_manager.dart';

/// Command to list cached packages.
class ListCommand extends Command<int> {
  @override
  final String name = 'list';

  @override
  final String description = 'List all cached packages.';

  @override
  Future<int> run() async {
    final cache = CacheManager.defaultLocation();
    final packages = await cache.listCached();

    if (packages.isEmpty) {
      print('No cached packages.');
      return 0;
    }

    print('Cached packages:');
    for (final pkg in packages) {
      print('  ${pkg.name}@${pkg.version}');
    }

    return 0;
  }
}
