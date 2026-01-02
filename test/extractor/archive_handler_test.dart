/// Tests for [ArchiveHandler] tar.gz extraction functionality.
///
/// Creates temporary test archives in memory and verifies extraction
/// to isolated temporary directories. Tests cover basic extraction,
/// nested directories, file content preservation, binary files,
/// error handling, and real-world Dart package structures.
///
/// Test isolation: All archives are created in-memory per test and extracted
/// to temporary directories that are cleaned up after each test.
import 'dart:io';
import 'package:test/test.dart';
import 'package:archive/archive.dart';
import 'package:pubdev_mcp_bridge/src/extractor/archive_handler.dart';

void main() {
  late Directory tempDir;
  late ArchiveHandler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive_test_');
    handler = ArchiveHandler();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a test .tar.gz archive with specified files and directories.
  ///
  /// The archive is created in memory using the archive package, then written
  /// to a temporary file. This ensures test isolation and avoids file system
  /// dependencies.
  ///
  /// Parameters:
  ///   - [name]: Base name for the archive file (without .tar.gz extension)
  ///   - [files]: Map of file paths to content strings
  ///   - [directories]: List of directory paths to create as empty directories
  ///
  /// Returns the absolute path to the created archive file.
  ///
  /// Example:
  /// ```dart
  /// final archivePath = await createTestArchive(
  ///   name: 'test',
  ///   files: {'lib/main.dart': 'void main() {}'},
  ///   directories: ['bin/', 'test/'],
  /// );
  /// ```
  Future<String> createTestArchive({
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
    final archivePath = '${tempDir.path}/$name.tar.gz';
    await File(archivePath).writeAsBytes(compressedBytes);

    return archivePath;
  }

  group('ArchiveHandler - Basic Extraction', () {
    test('extracts simple archive with single file', () async {
      final archivePath = await createTestArchive(
        name: 'simple',
        files: {'test.txt': 'Hello, World!'},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      final extractedFile = File('$outputDir/test.txt');
      expect(extractedFile.existsSync(), isTrue);
      expect(await extractedFile.readAsString(), equals('Hello, World!'));
    });

    test('extracts archive with multiple files', () async {
      final archivePath = await createTestArchive(
        name: 'multiple',
        files: {
          'file1.txt': 'Content 1',
          'file2.txt': 'Content 2',
          'file3.txt': 'Content 3',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(File('$outputDir/file1.txt').existsSync(), isTrue);
      expect(File('$outputDir/file2.txt').existsSync(), isTrue);
      expect(File('$outputDir/file3.txt').existsSync(), isTrue);

      expect(
        await File('$outputDir/file1.txt').readAsString(),
        equals('Content 1'),
      );
    });

    test('extracts archive with nested directories', () async {
      final archivePath = await createTestArchive(
        name: 'nested',
        files: {
          'root.txt': 'Root file',
          'dir1/file1.txt': 'File in dir1',
          'dir1/subdir/file2.txt': 'File in subdir',
          'dir2/file3.txt': 'File in dir2',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(File('$outputDir/root.txt').existsSync(), isTrue);
      expect(File('$outputDir/dir1/file1.txt').existsSync(), isTrue);
      expect(File('$outputDir/dir1/subdir/file2.txt').existsSync(), isTrue);
      expect(File('$outputDir/dir2/file3.txt').existsSync(), isTrue);
    });

    test('creates output directory if it does not exist', () async {
      final archivePath = await createTestArchive(
        name: 'test',
        files: {'file.txt': 'content'},
      );

      final outputDir = '${tempDir.path}/new/nested/dir';
      expect(Directory(outputDir).existsSync(), isFalse);

      await handler.extract(archivePath, outputDir);

      expect(Directory(outputDir).existsSync(), isTrue);
      expect(File('$outputDir/file.txt').existsSync(), isTrue);
    });

    test('extracts empty archive', () async {
      final archivePath = await createTestArchive(name: 'empty', files: {});

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(Directory(outputDir).existsSync(), isTrue);
    });
  });

  group('ArchiveHandler - Directory Handling', () {
    test('creates directory entries', () async {
      final archivePath = await createTestArchive(
        name: 'with_dirs',
        files: {
          'lib/main.dart': 'void main() {}',
          'bin/app.dart': 'void main() {}',
          'test/test_file.dart': '// test file',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(Directory('$outputDir/lib').existsSync(), isTrue);
      expect(Directory('$outputDir/bin').existsSync(), isTrue);
      expect(Directory('$outputDir/test').existsSync(), isTrue);
    });

    test('overwrites existing directory', () async {
      final outputDir = '${tempDir.path}/extracted';

      // Create initial extraction
      final archive1 = await createTestArchive(
        name: 'version1',
        files: {'file1.txt': 'Version 1', 'file2.txt': 'Old file'},
      );
      await handler.extract(archive1, outputDir);

      expect(
        await File('$outputDir/file1.txt').readAsString(),
        equals('Version 1'),
      );
      expect(File('$outputDir/file2.txt').existsSync(), isTrue);

      // Extract new archive to same location
      final archive2 = await createTestArchive(
        name: 'version2',
        files: {'file1.txt': 'Version 2', 'file3.txt': 'New file'},
      );
      await handler.extract(archive2, outputDir);

      // Old content replaced
      expect(
        await File('$outputDir/file1.txt').readAsString(),
        equals('Version 2'),
      );
      expect(File('$outputDir/file2.txt').existsSync(), isFalse); // Removed
      expect(File('$outputDir/file3.txt').existsSync(), isTrue); // New
    });

    test('handles deeply nested directories', () async {
      final archivePath = await createTestArchive(
        name: 'deep',
        files: {'a/b/c/d/e/f/deep_file.txt': 'Deep content'},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      final deepFile = File('$outputDir/a/b/c/d/e/f/deep_file.txt');
      expect(deepFile.existsSync(), isTrue);
      expect(await deepFile.readAsString(), equals('Deep content'));
    });
  });

  group('ArchiveHandler - File Content', () {
    test('preserves file content exactly', () async {
      final content =
          'Line 1\nLine 2\nLine 3\n\nLine 5 with special chars: !@#\$%^&*()';
      final archivePath = await createTestArchive(
        name: 'content',
        files: {'test.txt': content},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(await File('$outputDir/test.txt').readAsString(), equals(content));
    });

    test('handles binary content', () async {
      final binaryContent = List.generate(256, (i) => i);
      final archive = Archive();
      archive.addFile(
        ArchiveFile('binary.bin', binaryContent.length, binaryContent),
      );

      final tarBytes = TarEncoder().encode(archive);
      final compressedBytes = GZipEncoder().encode(tarBytes);

      final archivePath = '${tempDir.path}/binary.tar.gz';
      await File(archivePath).writeAsBytes(compressedBytes);

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      final extractedBytes = await File('$outputDir/binary.bin').readAsBytes();
      expect(extractedBytes, equals(binaryContent));
    });

    test('handles large files', () async {
      // Create a ~1MB file
      final largeContent = 'x' * (1024 * 1024);
      final archivePath = await createTestArchive(
        name: 'large',
        files: {'large.txt': largeContent},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      final extractedFile = File('$outputDir/large.txt');
      expect(extractedFile.lengthSync(), equals(1024 * 1024));
    });

    test('handles empty files', () async {
      final archivePath = await createTestArchive(
        name: 'empty_file',
        files: {'empty.txt': ''},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      final emptyFile = File('$outputDir/empty.txt');
      expect(emptyFile.existsSync(), isTrue);
      expect(emptyFile.lengthSync(), equals(0));
    });
  });

  group('ArchiveHandler - Error Handling', () {
    test('throws StateError when archive does not exist', () async {
      final outputDir = '${tempDir.path}/extracted';

      expect(
        () => handler.extract('${tempDir.path}/nonexistent.tar.gz', outputDir),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Archive not found'),
          ),
        ),
      );
    });

    test('throws on corrupted archive', () async {
      // Create a corrupted (not actually gzipped) file
      final corruptedPath = '${tempDir.path}/corrupted.tar.gz';
      await File(corruptedPath).writeAsString('This is not a valid archive');

      final outputDir = '${tempDir.path}/extracted';

      expect(
        () => handler.extract(corruptedPath, outputDir),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles archive with invalid file paths', () async {
      // Some archives may have unusual paths
      final archivePath = await createTestArchive(
        name: 'unusual_paths',
        files: {'./relative.txt': 'Relative path', 'normal.txt': 'Normal path'},
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      // Should extract without error
      expect(Directory(outputDir).existsSync(), isTrue);
    });
  });

  group('ArchiveHandler - Real-world Scenarios', () {
    test('extracts typical Dart package structure', () async {
      final archivePath = await createTestArchive(
        name: 'dart_package',
        files: {
          'pubspec.yaml': 'name: test_package\nversion: 1.0.0',
          'README.md': '# Test Package',
          'CHANGELOG.md': '## 1.0.0\n- Initial release',
          'lib/test_package.dart': 'library test_package;',
          'lib/src/core.dart': 'class Core {}',
          'test/test_package_test.dart': 'void main() {}',
          'example/example.dart': 'void main() {}',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(File('$outputDir/pubspec.yaml').existsSync(), isTrue);
      expect(File('$outputDir/README.md').existsSync(), isTrue);
      expect(File('$outputDir/lib/test_package.dart').existsSync(), isTrue);
      expect(File('$outputDir/lib/src/core.dart').existsSync(), isTrue);
      expect(
        File('$outputDir/test/test_package_test.dart').existsSync(),
        isTrue,
      );
      expect(File('$outputDir/example/example.dart').existsSync(), isTrue);

      // Verify content
      final pubspec = await File('$outputDir/pubspec.yaml').readAsString();
      expect(pubspec, contains('test_package'));
    });

    test('extracts package with common file types', () async {
      final archivePath = await createTestArchive(
        name: 'mixed_files',
        files: {
          'code.dart': 'void main() {}',
          'data.json': '{"key": "value"}',
          'config.yaml': 'setting: true',
          'doc.md': '# Documentation',
          'LICENSE': 'MIT License',
          '.gitignore': '*.log',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(File('$outputDir/code.dart').existsSync(), isTrue);
      expect(File('$outputDir/data.json').existsSync(), isTrue);
      expect(File('$outputDir/config.yaml').existsSync(), isTrue);
      expect(File('$outputDir/doc.md').existsSync(), isTrue);
      expect(File('$outputDir/LICENSE').existsSync(), isTrue);
      expect(File('$outputDir/.gitignore').existsSync(), isTrue);
    });

    test('handles package with many files efficiently', () async {
      // Create archive with 100 files
      final files = <String, String>{};
      for (var i = 0; i < 100; i++) {
        files['lib/file_$i.dart'] = 'class Class$i {}';
      }

      final archivePath = await createTestArchive(
        name: 'many_files',
        files: files,
      );

      final outputDir = '${tempDir.path}/extracted';
      final stopwatch = Stopwatch()..start();

      await handler.extract(archivePath, outputDir);

      stopwatch.stop();

      // Verify all files extracted
      for (var i = 0; i < 100; i++) {
        expect(File('$outputDir/lib/file_$i.dart').existsSync(), isTrue);
      }

      // Should complete in reasonable time (< 5 seconds for 100 files)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('ArchiveHandler - Edge Cases', () {
    test('handles files with special characters in names', () async {
      final archivePath = await createTestArchive(
        name: 'special_chars',
        files: {
          'file with spaces.txt': 'Spaces',
          'file-with-dashes.txt': 'Dashes',
          'file_with_underscores.txt': 'Underscores',
          'file.multiple.dots.txt': 'Dots',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(File('$outputDir/file with spaces.txt').existsSync(), isTrue);
      expect(File('$outputDir/file-with-dashes.txt').existsSync(), isTrue);
      expect(File('$outputDir/file_with_underscores.txt').existsSync(), isTrue);
      expect(File('$outputDir/file.multiple.dots.txt').existsSync(), isTrue);
    });

    test('handles archive with root directory prefix', () async {
      // Many pub.dev packages extract with a root directory
      final archivePath = await createTestArchive(
        name: 'with_root',
        files: {
          'package-1.0.0/lib/main.dart': 'void main() {}',
          'package-1.0.0/pubspec.yaml': 'name: package',
        },
      );

      final outputDir = '${tempDir.path}/extracted';
      await handler.extract(archivePath, outputDir);

      expect(
        File('$outputDir/package-1.0.0/lib/main.dart').existsSync(),
        isTrue,
      );
      expect(
        File('$outputDir/package-1.0.0/pubspec.yaml').existsSync(),
        isTrue,
      );
    });

    test('extracts to directory with existing unrelated files', () async {
      final outputDir = '${tempDir.path}/extracted';
      await Directory(outputDir).create();
      await File('$outputDir/unrelated.txt').writeAsString('Unrelated');

      final archivePath = await createTestArchive(
        name: 'new',
        files: {'new_file.txt': 'New content'},
      );

      await handler.extract(archivePath, outputDir);

      // Old file should be removed (directory is deleted and recreated)
      expect(File('$outputDir/unrelated.txt').existsSync(), isFalse);
      expect(File('$outputDir/new_file.txt').existsSync(), isTrue);
    });
  });
}
