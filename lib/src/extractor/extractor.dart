/// Main documentation extraction pipeline.
library;

import '../cache/cache_manager.dart';
import '../client/pubdev_client.dart';
import '../models/package_doc.dart';
import 'archive_handler.dart';
import 'dart_metadata_extractor.dart';
import 'dartdoc_parser.dart';

/// Orchestrates the full documentation extraction pipeline.
class DocExtractor {
  final PubdevClient _client;
  final CacheManager _cache;
  final ArchiveHandler _archive;
  final DartMetadataExtractor _extractor;
  final DartdocParser _parser;

  /// Creates a new documentation extractor.
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

  /// Gets package documentation, from cache if available.
  ///
  /// If [forceRefresh] is true, ignores cache and re-extracts.
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

  /// Extracts documentation for a package without caching.
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

  /// Closes resources.
  void close() => _client.close();
}
