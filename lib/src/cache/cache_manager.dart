/// Three-level cache management for package archives, sources, and documentation.
///
/// The [CacheManager] maintains three separate cache directories:
/// - **archives/**: Downloaded .tar.gz package files from pub.dev
/// - **extracted/**: Unpacked package source code
/// - **docs/**: Parsed API documentation as JSON files
///
/// This three-level approach enables:
/// - Avoiding redundant downloads from pub.dev
/// - Reusing extracted source code for debugging
/// - Fast documentation loading without re-parsing
///
/// ## Usage
///
/// ```dart
/// final cache = CacheManager.defaultLocation();
///
/// // Check if cached
/// if (cache.hasPackage('dio', '5.4.0')) {
///   final doc = await cache.getPackage('dio', '5.4.0');
///   print('Loaded from cache: ${doc!.name}');
/// }
///
/// // Save to cache
/// await cache.savePackage(packageDoc);
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/package_doc.dart';

/// Manages local caching of package documentation across three storage layers.
///
/// The cache manager provides a persistent storage system for downloaded packages,
/// extracted source code, and parsed documentation. This significantly improves
/// performance by avoiding redundant network requests and parsing operations.
class CacheManager {
  /// The base cache directory containing all cache subdirectories.
  ///
  /// This directory contains three subdirectories:
  /// - `archives/`: Package .tar.gz files
  /// - `extracted/`: Unpacked source code
  /// - `docs/`: JSON documentation files
  final Directory cacheDir;

  /// Creates a cache manager with the given [cacheDir].
  ///
  /// The directory will be created automatically when needed by
  /// [ensureDirectories] or during save operations.
  CacheManager(this.cacheDir);

  /// Creates a cache manager using the platform-specific default cache location.
  ///
  /// Default cache locations by platform:
  /// - **macOS/Linux**: `~/.pubdev_mcp_cache/`
  /// - **Windows**: `%LOCALAPPDATA%\pubdev_mcp_cache\`
  ///
  /// Example:
  /// ```dart
  /// final cache = CacheManager.defaultLocation();
  /// print('Cache at: ${cache.cacheDir.path}');
  /// ```
  factory CacheManager.defaultLocation() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final cachePath =
        Platform.isWindows
            ? p.join(
              Platform.environment['LOCALAPPDATA'] ?? home,
              'pubdev_mcp_cache',
            )
            : p.join(home, '.pubdev_mcp_cache');
    return CacheManager(Directory(cachePath));
  }

  /// Directory for downloaded .tar.gz archives from pub.dev.
  ///
  /// Archives are stored as `{package}-{version}.tar.gz`.
  Directory get archivesDir => Directory(p.join(cacheDir.path, 'archives'));

  /// Directory for extracted package source code.
  ///
  /// Each package is extracted to `{package}-{version}/` subdirectory.
  Directory get extractedDir => Directory(p.join(cacheDir.path, 'extracted'));

  /// Directory for parsed documentation JSON files.
  ///
  /// Documentation is stored as `{package}-{version}.json`.
  Directory get docsDir => Directory(p.join(cacheDir.path, 'docs'));

  /// Creates all cache subdirectories if they don't exist.
  ///
  /// This is called automatically by save operations, but can be
  /// called manually to initialize the cache structure.
  Future<void> ensureDirectories() async {
    await cacheDir.create(recursive: true);
    await archivesDir.create(recursive: true);
    await extractedDir.create(recursive: true);
    await docsDir.create(recursive: true);
  }

  /// Returns the file path for a package's archive.
  ///
  /// Returns `archives/{packageName}-{version}.tar.gz`.
  String archivePath(String packageName, String version) =>
      p.join(archivesDir.path, '$packageName-$version.tar.gz');

  /// Returns the directory path for a package's extracted source.
  ///
  /// Returns `extracted/{packageName}-{version}/`.
  String extractedPath(String packageName, String version) =>
      p.join(extractedDir.path, '$packageName-$version');

  /// Returns the file path for a package's documentation JSON.
  ///
  /// Returns `docs/{packageName}-{version}.json`.
  String docsPath(String packageName, String version) =>
      p.join(docsDir.path, '$packageName-$version.json');

  /// Checks if documentation for [packageName] at [version] is cached.
  ///
  /// Returns `true` if the documentation JSON file exists, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (cache.hasPackage('dio', '5.4.0')) {
  ///   print('Documentation is cached');
  /// }
  /// ```
  bool hasPackage(String packageName, String version) =>
      File(docsPath(packageName, version)).existsSync();

  /// Loads cached documentation for [packageName] at [version].
  ///
  /// Returns the [PackageDoc] if found in cache, or `null` if not cached.
  ///
  /// This is a fast operation that only reads and deserializes JSON,
  /// without any network requests or parsing operations.
  ///
  /// Example:
  /// ```dart
  /// final doc = await cache.getPackage('dio', '5.4.0');
  /// if (doc != null) {
  ///   print('Loaded ${doc.libraries.length} libraries');
  /// }
  /// ```
  Future<PackageDoc?> getPackage(String packageName, String version) async {
    final file = File(docsPath(packageName, version));
    if (!file.existsSync()) return null;

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PackageDoc.fromJson(json);
  }

  /// Saves [package] documentation to the cache.
  ///
  /// The documentation is serialized to JSON with pretty-printing
  /// (2-space indentation) and saved to the docs directory.
  ///
  /// This automatically creates cache directories if they don't exist.
  ///
  /// Example:
  /// ```dart
  /// await cache.savePackage(packageDoc);
  /// print('Cached: ${packageDoc.name}@${packageDoc.version}');
  /// ```
  Future<void> savePackage(PackageDoc package) async {
    await ensureDirectories();
    final file = File(docsPath(package.name, package.version));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(package.toJson()),
    );
  }

  /// Lists all packages with cached documentation.
  ///
  /// Returns a list of records containing package name and version
  /// for each cached documentation file found in the docs directory.
  ///
  /// Example:
  /// ```dart
  /// final packages = await cache.listCached();
  /// for (final pkg in packages) {
  ///   print('${pkg.name}@${pkg.version}');
  /// }
  /// ```
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

  /// Removes all cached data for [packageName] at [version].
  ///
  /// This deletes:
  /// - The downloaded archive (.tar.gz)
  /// - The extracted source directory
  /// - The parsed documentation JSON
  ///
  /// Example:
  /// ```dart
  /// await cache.clearPackage('dio', '5.4.0');
  /// print('Cleared dio@5.4.0 from cache');
  /// ```
  Future<void> clearPackage(String packageName, String version) async {
    final archive = File(archivePath(packageName, version));
    final extracted = Directory(extractedPath(packageName, version));
    final docs = File(docsPath(packageName, version));

    if (archive.existsSync()) await archive.delete();
    if (extracted.existsSync()) await extracted.delete(recursive: true);
    if (docs.existsSync()) await docs.delete();
  }

  /// Removes all cached data for all packages.
  ///
  /// This deletes the entire cache directory and all its contents,
  /// including archives, extracted sources, and documentation JSON files.
  ///
  /// Use with caution as this operation cannot be undone.
  ///
  /// Example:
  /// ```dart
  /// await cache.clearAll();
  /// print('All cache data cleared');
  /// ```
  Future<void> clearAll() async {
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
