/// Example demonstrating direct use of the PubdevClient.
///
/// This example shows how to:
/// - Query package versions from pub.dev
/// - Download package archives
/// - Resolve version strings (latest, specific versions)
///
/// Run with: `dart run example/client_example.dart`
library;

import 'dart:io';

import 'package:pubdev_mcp_bridge/pubdev_mcp_bridge.dart';

Future<void> main() async {
  print('=== PubdevClient Example ===\n');

  final client = PubdevClient();

  try {
    // Get latest version of a package
    print('--- Querying Latest Version ---');
    final latestPath = await client.getLatestVersion('path');
    print('Latest version of "path": $latestPath');
    final latestDio = await client.getLatestVersion('dio');
    print('Latest version of "dio": $latestDio');
    print('');

    // Resolve version strings
    print('--- Version Resolution ---');
    final resolvedLatest = await client.resolveVersion('path', 'latest');
    print('"latest" resolves to: $resolvedLatest');

    final resolvedNull = await client.resolveVersion('path', null);
    print('null (default) resolves to: $resolvedNull');

    final resolvedSpecific = await client.resolveVersion('path', '1.8.0');
    print('"1.8.0" resolves to: $resolvedSpecific');
    print('');

    // Download a package archive (demonstration)
    print('--- Package Download (demonstration) ---');
    print('To download a package archive:');
    print('  await client.downloadArchive(');
    print('    "path",');
    print('    "$latestPath",');
    print('    "/tmp/path-$latestPath.tar.gz",');
    print('  );');
    print('');

    // Actually download to a temporary location to demonstrate
    final tempDir = Directory.systemTemp.createTempSync('pubdev_example_');
    try {
      final archivePath = '${tempDir.path}/path-$latestPath.tar.gz';
      print('Downloading path@$latestPath to temporary location...');
      await client.downloadArchive('path', latestPath, archivePath);

      final file = File(archivePath);
      if (file.existsSync()) {
        final size = file.lengthSync();
        final sizeKb = (size / 1024).toStringAsFixed(2);
        print('✓ Downloaded ${file.path}');
        print('  Size: $sizeKb KB');
      }
    } finally {
      // Clean up temporary directory
      tempDir.deleteSync(recursive: true);
    }
    print('');

    // Show how the client is typically used with DocExtractor
    print('--- Integration with DocExtractor ---');
    print('The PubdevClient is typically used internally by DocExtractor:');
    print('');
    print('  final extractor = DocExtractor();');
    print('  // The extractor uses PubdevClient internally');
    print('  final package = await extractor.getPackage("path");');
    print('  extractor.close();');
    print('');
    print(
      'For most use cases, use DocExtractor instead of PubdevClient directly.',
    );
  } catch (e) {
    print('Error: $e');
    rethrow;
  } finally {
    // Always close the client to free resources
    client.close();
    print('\n=== Complete ===');
  }
}
