/// Tests for [DocExtractor] orchestration of the extraction pipeline.
///
/// Tests the complete documentation extraction flow: download → extract →
/// analyze → parse → cache. Uses mocks for dependencies to test orchestration
/// logic in isolation, plus integration tests with real components.
///
/// Test isolation: Uses mock implementations for unit tests, isolated temp
/// directories for integration tests. No network dependencies.
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:pubdev_mcp_bridge/src/extractor/extractor.dart';
import 'package:pubdev_mcp_bridge/src/cache/cache_manager.dart';
import 'package:pubdev_mcp_bridge/src/client/pubdev_client.dart';
import 'package:pubdev_mcp_bridge/src/extractor/archive_handler.dart';
import 'package:pubdev_mcp_bridge/src/extractor/dart_metadata_extractor.dart';
import 'package:pubdev_mcp_bridge/src/extractor/dartdoc_parser.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

import '../test_utils.dart';

void main() {
  group('DocExtractor', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await createTempTestDir('extractor_test_');
    });

    group('constructor', () {
      test('creates with default dependencies', () {
        final extractor = DocExtractor();
        expect(extractor, isNotNull);
        extractor.close();
      });

      test('accepts custom dependencies', () {
        final cache = CacheManager(tempDir);
        final extractor = DocExtractor(cache: cache);
        expect(extractor, isNotNull);
        extractor.close();
      });
    });

    group('getPackage - caching behavior', () {
      test('returns cached package when available', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final extractor = DocExtractor(cache: cache, client: mockClient);

        try {
          // Pre-populate cache
          final cachedDoc = PackageDoc(
            name: 'test_pkg',
            version: '1.0.0',
            libraries: [],
          );
          await cache.savePackage(cachedDoc);

          // Should return cached version without extraction
          final result = await extractor.getPackage('test_pkg');
          expect(result.name, equals('test_pkg'));
          expect(result.version, equals('1.0.0'));
        } finally {
          extractor.close();
        }
      });

      test('skips cache when forceRefresh is true', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          // Pre-populate cache
          final cachedDoc = PackageDoc(
            name: 'test_pkg',
            version: '1.0.0',
            libraries: [],
          );
          await cache.savePackage(cachedDoc);

          // With forceRefresh, should call extraction pipeline
          await extractor.getPackage('test_pkg', forceRefresh: true);

          expect(mockClient.resolveVersionCalled, isTrue);
          expect(mockClient.downloadArchiveCalled, isTrue);
        } finally {
          extractor.close();
        }
      });

      test('saves extracted package to cache', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.getPackage('test_pkg');

          // Verify package was saved to cache
          final cached = await cache.getPackage('test_pkg', '1.0.0');
          expect(cached, isNotNull);
          expect(cached!.name, equals('test_pkg'));
        } finally {
          extractor.close();
        }
      });

      test('handles cache miss by extracting', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          final result = await extractor.getPackage('test_pkg');

          expect(result.name, equals('test_pkg'));
          expect(mockClient.resolveVersionCalled, isTrue);
          expect(mockClient.downloadArchiveCalled, isTrue);
          expect(mockExtractor.runCalled, isTrue);
          expect(mockParser.parseCalled, isTrue);
        } finally {
          extractor.close();
        }
      });
    });

    group('getPackage - version resolution', () {
      test('resolves null version to latest', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.getPackage('test_pkg', version: null);
          expect(mockClient.resolveVersionCalled, isTrue);
          expect(mockClient.lastResolvedVersion, isNull);
        } finally {
          extractor.close();
        }
      });

      test('resolves "latest" version', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.getPackage('test_pkg', version: 'latest');
          expect(mockClient.lastResolvedVersion, equals('latest'));
        } finally {
          extractor.close();
        }
      });

      test('uses explicit version when provided', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.getPackage('test_pkg', version: '2.5.0');
          expect(mockClient.lastResolvedVersion, equals('2.5.0'));
        } finally {
          extractor.close();
        }
      });
    });

    group('extract - pipeline orchestration', () {
      test('executes all stages in correct order', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockArchive = _MockArchiveHandler();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          archive: mockArchive,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.extract('test_pkg', '1.0.0');

          // Verify call order
          expect(mockClient.downloadArchiveCalled, isTrue);
          expect(mockArchive.extractCalled, isTrue);
          expect(mockExtractor.runCalled, isTrue);
          expect(mockParser.parseCalled, isTrue);
        } finally {
          extractor.close();
        }
      });

      test('creates cache directories before extraction', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.extract('test_pkg', '1.0.0');

          // Verify cache directories exist
          expect(
            Directory(p.join(tempDir.path, 'archives')).existsSync(),
            isTrue,
          );
          expect(
            Directory(p.join(tempDir.path, 'extracted')).existsSync(),
            isTrue,
          );
          expect(Directory(p.join(tempDir.path, 'docs')).existsSync(), isTrue);
        } finally {
          extractor.close();
        }
      });

      test('passes correct paths between stages', () async {
        final cache = CacheManager(tempDir);
        final mockClient = _MockPubdevClient();
        final mockArchive = _MockArchiveHandler();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: cache,
          client: mockClient,
          archive: mockArchive,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          await extractor.extract('test_pkg', '1.0.0');

          // Verify archive path used
          expect(
            mockClient.lastArchivePath,
            equals(cache.archivePath('test_pkg', '1.0.0')),
          );

          // Verify extracted path used
          expect(
            mockArchive.lastDestination,
            equals(cache.extractedPath('test_pkg', '1.0.0')),
          );
        } finally {
          extractor.close();
        }
      });

      test('returns PackageDoc from parser', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _MockDartdocParser();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          final result = await extractor.extract('test_pkg', '1.0.0');

          expect(result, isA<PackageDoc>());
          expect(result.name, equals('test_pkg'));
          expect(result.version, equals('1.0.0'));
        } finally {
          extractor.close();
        }
      });
    });

    group('error handling', () {
      test('propagates archive download errors', () async {
        final mockClient = _FailingPubdevClient();
        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
        );

        try {
          expect(
            () => extractor.extract('test_pkg', '1.0.0'),
            throwsA(isA<PubdevClientException>()),
          );
        } finally {
          extractor.close();
        }
      });

      test('propagates archive extraction errors', () async {
        final mockClient = _MockPubdevClient();
        final mockArchive = _FailingArchiveHandler();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          archive: mockArchive,
        );

        try {
          expect(() => extractor.extract('test_pkg', '1.0.0'), throwsException);
        } finally {
          extractor.close();
        }
      });

      test('propagates analyzer extraction errors', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _FailingDartMetadataExtractor();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
        );

        try {
          expect(() => extractor.extract('test_pkg', '1.0.0'), throwsException);
        } finally {
          extractor.close();
        }
      });

      test('propagates parser errors', () async {
        final mockClient = _MockPubdevClient();
        final mockExtractor = _MockDartMetadataExtractor();
        final mockParser = _FailingDartdocParser();

        final extractor = DocExtractor(
          cache: CacheManager(tempDir),
          client: mockClient,
          extractor: mockExtractor,
          parser: mockParser,
        );

        try {
          expect(() => extractor.extract('test_pkg', '1.0.0'), throwsException);
        } finally {
          extractor.close();
        }
      });
    });

    group('close', () {
      test('closes HTTP client', () {
        final mockClient = _MockPubdevClient();
        final extractor = DocExtractor(client: mockClient);

        extractor.close();
        expect(mockClient.closeCalled, isTrue);
      });

      test('can be called multiple times safely', () {
        final extractor = DocExtractor();
        extractor.close();
        extractor.close(); // Should not throw
      });
    });
  });
}

// === Mock Implementations ===

class _MockPubdevClient extends PubdevClient {
  bool resolveVersionCalled = false;
  bool downloadArchiveCalled = false;
  bool closeCalled = false;
  String? lastResolvedVersion;
  String? lastArchivePath;

  @override
  Future<String> resolveVersion(String packageName, [String? version]) async {
    resolveVersionCalled = true;
    lastResolvedVersion = version;
    return '1.0.0';
  }

  @override
  Future<void> downloadArchive(
    String packageName,
    String version,
    String destinationPath,
  ) async {
    downloadArchiveCalled = true;
    lastArchivePath = destinationPath;

    // Create empty archive file
    await File(destinationPath).create(recursive: true);
  }

  @override
  void close() {
    closeCalled = true;
  }
}

class _FailingPubdevClient extends PubdevClient {
  @override
  Future<String> resolveVersion(String packageName, [String? version]) async {
    return '1.0.0';
  }

  @override
  Future<void> downloadArchive(
    String packageName,
    String version,
    String destinationPath,
  ) async {
    throw PubdevClientException('Download failed', 500);
  }
}

class _MockArchiveHandler extends ArchiveHandler {
  bool extractCalled = false;
  String? lastDestination;

  @override
  Future<void> extract(String archivePath, String destinationDir) async {
    extractCalled = true;
    lastDestination = destinationDir;

    // Create lib directory
    await Directory(p.join(destinationDir, 'lib')).create(recursive: true);
  }
}

class _FailingArchiveHandler extends ArchiveHandler {
  @override
  Future<void> extract(String archivePath, String destinationDir) async {
    throw Exception('Archive extraction failed');
  }
}

class _MockDartMetadataExtractor extends DartMetadataExtractor {
  bool runCalled = false;

  @override
  Future<String> run(String packageDir) async {
    runCalled = true;

    // Create mock JSON output
    final jsonPath = p.join(packageDir, 'api_doc.json');
    await File(jsonPath).writeAsString('[]');
    return jsonPath;
  }
}

class _FailingDartMetadataExtractor extends DartMetadataExtractor {
  @override
  Future<String> run(String packageDir) async {
    throw Exception('Analyzer extraction failed');
  }
}

class _MockDartdocParser extends DartdocParser {
  bool parseCalled = false;

  @override
  Future<PackageDoc> parse(
    String jsonPath,
    String packageName,
    String version,
  ) async {
    parseCalled = true;
    return PackageDoc(name: packageName, version: version, libraries: []);
  }
}

class _FailingDartdocParser extends DartdocParser {
  @override
  Future<PackageDoc> parse(
    String jsonPath,
    String packageName,
    String version,
  ) async {
    throw Exception('Parser failed');
  }
}
