/// Shared test utilities for all test files.
///
/// Provides reusable helpers for common test patterns including:
/// - Temporary directory creation and cleanup
/// - JSON fixture loading
/// - Package assertion helpers
/// - Archive creation utilities
library test_utils;

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

/// Creates a temporary directory for testing with automatic cleanup.
///
/// The directory is automatically deleted when the test completes,
/// even if the test fails. Uses [addTearDown] to ensure cleanup.
///
/// Example:
/// ```dart
/// test('my test', () async {
///   final tempDir = await createTempTestDir('my_test_');
///   // Use tempDir for test...
///   // Cleanup happens automatically
/// });
/// ```
Future<Directory> createTempTestDir(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        // Log but don't fail - OS will clean up temp dirs
        print('Warning: Failed to clean up temp dir ${dir.path}: $e');
      }
    }
  });
  return dir;
}

/// Loads a JSON fixture file from the test/fixtures directory.
///
/// Returns the parsed JSON as a Map. Throws if the fixture file
/// is not found or contains invalid JSON.
///
/// Example:
/// ```dart
/// final json = await loadJsonFixture('sample_package_doc');
/// final doc = PackageDoc.fromJson(json);
/// ```
Future<Map<String, dynamic>> loadJsonFixture(String name) async {
  final fixturePath = 'test/fixtures/$name.json';
  final file = File(fixturePath);

  if (!file.existsSync()) {
    fail('Fixture file not found: $fixturePath');
  }

  final content = await file.readAsString();
  return jsonDecode(content) as Map<String, dynamic>;
}

/// Asserts that a [PackageDoc] has the expected field values.
///
/// Provides a concise way to verify multiple fields at once.
///
/// Example:
/// ```dart
/// expectPackageDoc(doc,
///   name: 'my_package',
///   version: '1.0.0',
///   libraryCount: 2,
/// );
/// ```
void expectPackageDoc(
  PackageDoc doc, {
  required String name,
  required String version,
  String? description,
  String? repository,
  String? homepage,
  required int libraryCount,
}) {
  expect(doc.name, equals(name), reason: 'package name mismatch');
  expect(doc.version, equals(version), reason: 'package version mismatch');

  if (description != null) {
    expect(
      doc.description,
      equals(description),
      reason: 'description mismatch',
    );
  }

  if (repository != null) {
    expect(doc.repository, equals(repository), reason: 'repository mismatch');
  }

  if (homepage != null) {
    expect(doc.homepage, equals(homepage), reason: 'homepage mismatch');
  }

  expect(
    doc.libraries,
    hasLength(libraryCount),
    reason: 'library count mismatch',
  );
}

/// Creates a test .tar.gz archive with specified files and directories.
///
/// The archive is created in memory using the archive package, then written
/// to a temporary file in the provided [tempDir]. This ensures test isolation
/// and avoids file system dependencies.
///
/// Parameters:
///   - [tempDir]: Directory where the archive file will be created
///   - [name]: Base name for the archive file (without .tar.gz extension)
///   - [files]: Map of file paths to content strings
///   - [directories]: List of directory paths to create as empty directories
///
/// Returns the absolute path to the created archive file.
///
/// Example:
/// ```dart
/// final archivePath = await createTestArchive(
///   tempDir: tempDir,
///   name: 'test',
///   files: {
///     'lib/main.dart': 'void main() {}',
///     'pubspec.yaml': 'name: test_package',
///   },
///   directories: ['bin/', 'test/'],
/// );
/// ```
Future<String> createTestArchive({
  required Directory tempDir,
  required String name,
  Map<String, String> files = const {},
  List<String> directories = const [],
}) async {
  final archive = Archive();

  // Add directories
  for (final dir in directories) {
    archive.addFile(ArchiveFile('$dir/', 0, []));
  }

  // Add files
  files.forEach((path, content) {
    final bytes = content.codeUnits;
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });

  // Encode as tar
  final tarEncoder = TarEncoder();
  final tarBytes = tarEncoder.encode(archive);

  // Compress with gzip
  final gzipEncoder = GZipEncoder();
  final compressedBytes = gzipEncoder.encode(tarBytes);

  // Write to file
  final archivePath = p.join(tempDir.path, '$name.tar.gz');
  await File(archivePath).writeAsBytes(compressedBytes);

  return archivePath;
}

/// Creates analyzer-formatted JSON for testing DartdocParser.
///
/// The JSON format matches the output from DartMetadataExtractor's
/// analyzer-based extraction process.
///
/// Parameters:
///   - [tempDir]: Directory where the JSON file will be created
///   - [libraries]: List of library maps with 'source' and 'declarations' keys
///
/// Returns the absolute path to the created JSON file.
///
/// Example:
/// ```dart
/// final jsonPath = await createAnalyzerJson(
///   tempDir: tempDir,
///   libraries: [
///     {
///       'source': 'lib/main.dart',
///       'declarations': [
///         {'kind': 'class', 'name': 'MyClass'},
///       ],
///     },
///   ],
/// );
/// ```
Future<String> createAnalyzerJson({
  required Directory tempDir,
  required List<Map<String, dynamic>> libraries,
}) async {
  final jsonPath = p.join(tempDir.path, 'analyzer_output.json');
  await File(jsonPath).writeAsString(jsonEncode(libraries));
  return jsonPath;
}
