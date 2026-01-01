/// Cache management for package documentation.
///
/// Stores extracted documentation as JSON files in a local cache directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/package_doc.dart';

/// Manages local caching of package documentation.
class CacheManager {
  /// The base cache directory.
  final Directory cacheDir;

  /// Creates a cache manager with the given cache directory.
  CacheManager(this.cacheDir);

  /// Creates a cache manager using the default cache location.
  ///
  /// Default locations:
  /// - Linux/macOS: ~/.pubdev_mcp_cache/
  /// - Windows: %LOCALAPPDATA%/pubdev_mcp_cache/
  factory CacheManager.defaultLocation() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final cachePath = Platform.isWindows
        ? p.join(
            Platform.environment['LOCALAPPDATA'] ?? home, 'pubdev_mcp_cache')
        : p.join(home, '.pubdev_mcp_cache');
    return CacheManager(Directory(cachePath));
  }

  /// Directory for downloaded archives.
  Directory get archivesDir => Directory(p.join(cacheDir.path, 'archives'));

  /// Directory for extracted package sources.
  Directory get extractedDir => Directory(p.join(cacheDir.path, 'extracted'));

  /// Directory for cached documentation JSON.
  Directory get docsDir => Directory(p.join(cacheDir.path, 'docs'));

  /// Ensures all cache directories exist.
  Future<void> ensureDirectories() async {
    await cacheDir.create(recursive: true);
    await archivesDir.create(recursive: true);
    await extractedDir.create(recursive: true);
    await docsDir.create(recursive: true);
  }

  /// Gets the path to a package's archive file.
  String archivePath(String packageName, String version) =>
      p.join(archivesDir.path, '$packageName-$version.tar.gz');

  /// Gets the path to a package's extracted source directory.
  String extractedPath(String packageName, String version) =>
      p.join(extractedDir.path, '$packageName-$version');

  /// Gets the path to a package's documentation JSON file.
  String docsPath(String packageName, String version) =>
      p.join(docsDir.path, '$packageName-$version.json');

  /// Checks if a package's documentation is cached.
  bool hasPackage(String packageName, String version) =>
      File(docsPath(packageName, version)).existsSync();

  /// Loads cached documentation for a package.
  ///
  /// Returns null if not cached.
  Future<PackageDoc?> getPackage(String packageName, String version) async {
    final file = File(docsPath(packageName, version));
    if (!file.existsSync()) return null;

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PackageDoc.fromJson(json);
  }

  /// Saves package documentation to the cache.
  Future<void> savePackage(PackageDoc package) async {
    await ensureDirectories();
    final file = File(docsPath(package.name, package.version));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(package.toJson()),
    );
  }

  /// Lists all cached packages.
  Future<List<({String name, String version})>> listCached() async {
    if (!docsDir.existsSync()) return [];

    final packages = <({String name, String version})>[];
    await for (final entity in docsDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = p.basenameWithoutExtension(entity.path);
        final lastDash = filename.lastIndexOf('-');
        if (lastDash > 0) {
          packages.add((
            name: filename.substring(0, lastDash),
            version: filename.substring(lastDash + 1),
          ));
        }
      }
    }
    return packages;
  }

  /// Clears cache for a specific package.
  Future<void> clearPackage(String packageName, String version) async {
    final archive = File(archivePath(packageName, version));
    final extracted = Directory(extractedPath(packageName, version));
    final docs = File(docsPath(packageName, version));

    if (archive.existsSync()) await archive.delete();
    if (extracted.existsSync()) await extracted.delete(recursive: true);
    if (docs.existsSync()) await docs.delete();
  }

  /// Clears all cached data.
  Future<void> clearAll() async {
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
