/// Example demonstrating cache management with pubdev_mcp_bridge.
///
/// This example shows how to:
/// - Check if packages are cached
/// - Load packages from cache
/// - List all cached packages
/// - Save and clear cache
///
/// Run with: `dart run example/cache_example.dart`
library;

import 'package:pubdev_mcp_bridge/pubdev_mcp_bridge.dart';

Future<void> main() async {
  print('=== Cache Management Example ===\n');

  // Create a cache manager using the default location
  final cache = CacheManager.defaultLocation();

  print('--- Cache Location ---');
  print('Cache directory: ${cache.cacheDir.path}');
  print('Archives: ${cache.archivesDir.path}');
  print('Extracted: ${cache.extractedDir.path}');
  print('Docs: ${cache.docsDir.path}');
  print('');

  // Ensure cache directories exist
  await cache.ensureDirectories();
  print('✓ Cache directories initialized\n');

  // List currently cached packages
  print('--- Currently Cached Packages ---');
  final cachedPackages = await cache.listCached();
  if (cachedPackages.isEmpty) {
    print('No packages cached yet');
  } else {
    for (final pkg in cachedPackages) {
      print('${pkg.name}@${pkg.version}');
    }
  }
  print('');

  // Check if a specific package is cached
  print('--- Checking Cache for "path" ---');
  // We'll use the extractor to get the latest version
  final client = PubdevClient();
  try {
    final latestVersion = await client.getLatestVersion('path');
    final isCached = cache.hasPackage('path', latestVersion);
    print('path@$latestVersion cached: $isCached');

    if (isCached) {
      // Load from cache
      print('\nLoading from cache...');
      final package = await cache.getPackage('path', latestVersion);
      if (package != null) {
        print('✓ Loaded ${package.name}@${package.version}');
        print('  Libraries: ${package.libraries.length}');
        print('  Classes: ${package.allClasses.length}');
      }
    } else {
      // Extract and cache the package
      print('\nNot cached. Extracting...');
      final extractor = DocExtractor();
      try {
        final package = await extractor.getPackage('path');
        print('✓ Extracted and cached ${package.name}@${package.version}');
      } finally {
        extractor.close();
      }
    }
    print('');

    // Demonstrate cache paths
    print('--- Cache Paths for path@$latestVersion ---');
    print('Archive: ${cache.archivePath('path', latestVersion)}');
    print('Extracted: ${cache.extractedPath('path', latestVersion)}');
    print('Docs: ${cache.docsPath('path', latestVersion)}');
    print('');

    // List cached packages again
    print('--- Updated Cache Contents ---');
    final updatedCache = await cache.listCached();
    for (final pkg in updatedCache) {
      print('${pkg.name}@${pkg.version}');
    }
    print('Total packages cached: ${updatedCache.length}');
    print('');

    // Demonstrate clearing cache (optional - commented out to avoid data loss)
    print('--- Cache Clearing (demonstration) ---');
    print('To clear a specific package:');
    print('  await cache.clearPackage("path", "$latestVersion");');
    print('To clear all packages:');
    print('  await cache.clearAll();');
    print('');
    print('(Cache clearing is not executed in this example)');
  } catch (e) {
    print('Error: $e');
    rethrow;
  } finally {
    client.close();
    print('\n=== Complete ===');
  }
}
