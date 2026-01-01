/// Orchestrates the complete documentation extraction pipeline.
///
/// The extraction pipeline consists of five stages:
/// 1. **Download**: Fetch package archive from pub.dev
/// 2. **Extract**: Unpack .tar.gz to local cache
/// 3. **Analyze**: Use `package:analyzer` to parse Dart source code
/// 4. **Parse**: Convert analysis results to [PackageDoc] model
/// 5. **Cache**: Save JSON documentation for future use
///
/// ## Usage
///
/// ```dart
/// final extractor = DocExtractor();
/// try {
///   // Get package (from cache or by extraction)
///   final doc = await extractor.getPackage('dio');
///   print('${doc.name}@${doc.version}');
///   print('${doc.allClasses.length} classes');
///
///   // Force refresh (ignore cache)
///   final fresh = await extractor.getPackage('dio', forceRefresh: true);
/// } finally {
///   extractor.close();
/// }
/// ```
library;

import '../cache/cache_manager.dart';
import '../client/pubdev_client.dart';
import '../models/package_doc.dart';
import 'archive_handler.dart';
import 'dart_metadata_extractor.dart';
import 'dartdoc_parser.dart';

/// Orchestrates the full documentation extraction pipeline.
///
/// The [DocExtractor] coordinates multiple components to download,
/// extract, analyze, and cache Dart package documentation.
///
/// Key features:
/// - Smart caching to avoid redundant work
/// - Support for experimental Dart language features
/// - Automatic version resolution
/// - Error handling at each stage
class DocExtractor {
  final PubdevClient _client;
  final CacheManager _cache;
  final ArchiveHandler _archive;
  final DartMetadataExtractor _extractor;
  final DartdocParser _parser;

  /// Creates a new documentation extractor.
  ///
  /// All dependencies are optional and will use defaults if not provided:
  /// - [client]: pub.dev HTTP client (defaults to [PubdevClient])
  /// - [cache]: Cache manager (defaults to [CacheManager.defaultLocation])
  /// - [archive]: Archive handler (defaults to [ArchiveHandler])
  /// - [extractor]: Metadata extractor (defaults to [DartMetadataExtractor])
  /// - [parser]: Documentation parser (defaults to [DartdocParser])
  ///
  /// Custom dependencies are primarily useful for testing.
  DocExtractor({
    PubdevClient? client,
    CacheManager? cache,
    ArchiveHandler? archive,
    DartMetadataExtractor? extractor,
    DartdocParser? parser,
  })  : _client = client ?? PubdevClient(),
        _cache = cache ?? CacheManager.defaultLocation(),
        _archive = archive ?? ArchiveHandler(),
        _extractor = extractor ?? DartMetadataExtractor(),
        _parser = parser ?? DartdocParser();

  /// Retrieves package documentation, from cache if available.
  ///
  /// Returns cached [PackageDoc] if available, otherwise downloads,
  /// extracts, and analyzes the package from pub.dev.
  ///
  /// Parameters:
  /// - [packageName]: The pub.dev package name
  /// - [version]: Specific version or null/`'latest'` for latest version
  /// - [forceRefresh]: If true, ignores cache and re-extracts documentation
  ///
  /// Throws:
  /// - [PackageNotFoundException]: If package doesn't exist
  /// - [PubdevClientException]: On HTTP/network errors
  /// - [StateError]: If extraction or analysis fails
  ///
  /// Example:
  /// ```dart
  /// // Get latest version (from cache if available)
  /// final doc1 = await extractor.getPackage('dio');
  ///
  /// // Get specific version
  /// final doc2 = await extractor.getPackage('dio', version: '5.4.0');
  ///
  /// // Force refresh (bypass cache)
  /// final doc3 = await extractor.getPackage('dio', forceRefresh: true);
  /// ```
  Future<PackageDoc> getPackage(
    String packageName, {
    String? version,
    bool forceRefresh = false,
  }) async {
    // Resolve version
    final resolvedVersion = await _client.resolveVersion(packageName, version);

    // Check cache first
    if (!forceRefresh) {
      final cached = await _cache.getPackage(packageName, resolvedVersion);
      if (cached != null) return cached;
    }

    // Extract documentation
    final package = await extract(packageName, resolvedVersion);

    // Cache the result
    await _cache.savePackage(package);

    return package;
  }

  /// Extracts documentation for [packageName] at [version] without using cache.
  ///
  /// This method performs the complete extraction pipeline:
  /// 1. Downloads the .tar.gz archive from pub.dev
  /// 2. Extracts the archive to local cache
  /// 3. Runs Dart analyzer to extract API documentation
  /// 4. Parses the analyzer output into [PackageDoc]
  ///
  /// Returns the extracted [PackageDoc] without saving to cache.
  /// Use [getPackage] instead if you want automatic caching.
  ///
  /// This method is primarily used internally by [getPackage].
  Future<PackageDoc> extract(String packageName, String version) async {
    await _cache.ensureDirectories();

    // Download archive
    final archivePath = _cache.archivePath(packageName, version);
    await _client.downloadArchive(packageName, version, archivePath);

    // Extract archive
    final extractedPath = _cache.extractedPath(packageName, version);
    await _archive.extract(archivePath, extractedPath);

    // Extract API documentation using analyzer
    final jsonPath = await _extractor.run(extractedPath);

    // Parse documentation
    return _parser.parse(jsonPath, packageName, version);
  }

  /// Closes the HTTP client and releases resources.
  ///
  /// Call this when done with the extractor to free resources.
  /// After calling [close], no further extractions can be performed.
  ///
  /// Example:
  /// ```dart
  /// final extractor = DocExtractor();
  /// try {
  ///   await extractor.getPackage('dio');
  /// } finally {
  ///   extractor.close();
  /// }
  /// ```
  void close() => _client.close();
}
