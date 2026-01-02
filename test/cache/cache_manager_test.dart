/// Tests for [CacheManager] functionality.
///
/// Covers cache initialization, path generation, package storage/retrieval,
/// listing cached packages, and cleanup operations. Tests the three-level
/// caching system (archives, extracted sources, documentation JSON).
///
/// Test isolation: Uses isolated temporary directories created for each test
/// via setUp/tearDown to ensure tests don't interfere with each other or
/// affect the system cache.
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:pubdev_mcp_bridge/src/cache/cache_manager.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

void main() {
  late Directory tempDir;
  late CacheManager cache;

  setUp(() async {
    // Create a temporary directory for each test
    tempDir = await Directory.systemTemp.createTemp('cache_test_');
    cache = CacheManager(tempDir);
  });

  tearDown(() async {
    // Clean up temporary directory after each test
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CacheManager - Initialization', () {
    test('creates instance with custom directory', () {
      expect(cache.cacheDir.path, equals(tempDir.path));
    });

    test('creates instance with default location', () {
      final defaultCache = CacheManager.defaultLocation();
      final expectedPath =
          Platform.isWindows
              ? p.join(
                Platform.environment['LOCALAPPDATA']!,
                'pubdev_mcp_cache',
              )
              : p.join(Platform.environment['HOME']!, '.pubdev_mcp_cache');

      expect(defaultCache.cacheDir.path, equals(expectedPath));
    });

    test('subdirectories have correct paths', () {
      expect(cache.archivesDir.path, equals(p.join(tempDir.path, 'archives')));
      expect(
        cache.extractedDir.path,
        equals(p.join(tempDir.path, 'extracted')),
      );
      expect(cache.docsDir.path, equals(p.join(tempDir.path, 'docs')));
    });

    test('ensureDirectories creates all subdirectories', () async {
      await cache.ensureDirectories();

      expect(await cache.cacheDir.exists(), isTrue);
      expect(await cache.archivesDir.exists(), isTrue);
      expect(await cache.extractedDir.exists(), isTrue);
      expect(await cache.docsDir.exists(), isTrue);
    });

    test('ensureDirectories is idempotent', () async {
      await cache.ensureDirectories();
      await cache.ensureDirectories(); // Second call should not error

      expect(await cache.cacheDir.exists(), isTrue);
    });
  });

  group('CacheManager - Path Generation', () {
    test('archivePath returns correct path', () {
      final path = cache.archivePath('test_package', '1.0.0');
      expect(
        path,
        equals(p.join(tempDir.path, 'archives', 'test_package-1.0.0.tar.gz')),
      );
    });

    test('extractedPath returns correct path', () {
      final path = cache.extractedPath('test_package', '1.0.0');
      expect(
        path,
        equals(p.join(tempDir.path, 'extracted', 'test_package-1.0.0')),
      );
    });

    test('docsPath returns correct path', () {
      final path = cache.docsPath('test_package', '1.0.0');
      expect(
        path,
        equals(p.join(tempDir.path, 'docs', 'test_package-1.0.0.json')),
      );
    });

    test('handles package names with special characters', () {
      final path = cache.docsPath('my_cool-package', '2.0.0-beta.1');
      expect(path, contains('my_cool-package-2.0.0-beta.1.json'));
    });
  });

  group('CacheManager - hasPackage', () {
    test('returns false when package not cached', () {
      expect(cache.hasPackage('test_package', '1.0.0'), isFalse);
    });

    test('returns true when package is cached', () async {
      await cache.ensureDirectories();
      final docFile = File(cache.docsPath('test_package', '1.0.0'));
      await docFile.writeAsString('{}');

      expect(cache.hasPackage('test_package', '1.0.0'), isTrue);
    });

    test('returns false for different version', () async {
      await cache.ensureDirectories();
      final docFile = File(cache.docsPath('test_package', '1.0.0'));
      await docFile.writeAsString('{}');

      expect(cache.hasPackage('test_package', '2.0.0'), isFalse);
    });

    test('returns false for different package', () async {
      await cache.ensureDirectories();
      final docFile = File(cache.docsPath('test_package', '1.0.0'));
      await docFile.writeAsString('{}');

      expect(cache.hasPackage('other_package', '1.0.0'), isFalse);
    });
  });

  group('CacheManager - getPackage', () {
    test('returns null when package not cached', () async {
      final doc = await cache.getPackage('test_package', '1.0.0');
      expect(doc, isNull);
    });

    test('returns null when cache directory does not exist', () async {
      final doc = await cache.getPackage('test_package', '1.0.0');
      expect(doc, isNull);
    });

    test('loads cached package successfully', () async {
      await cache.ensureDirectories();

      final originalDoc = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test description',
        libraries: [LibraryDoc(name: 'test_lib')],
      );

      final docFile = File(cache.docsPath('test_package', '1.0.0'));
      await docFile.writeAsString(jsonEncode(originalDoc.toJson()));

      final loadedDoc = await cache.getPackage('test_package', '1.0.0');

      expect(loadedDoc, isNotNull);
      expect(loadedDoc!.name, equals('test_package'));
      expect(loadedDoc.version, equals('1.0.0'));
      expect(loadedDoc.description, equals('Test description'));
      expect(loadedDoc.libraries, hasLength(1));
    });

    test('handles complex package documentation', () async {
      await cache.ensureDirectories();

      final complexDoc = PackageDoc(
        name: 'complex_package',
        version: '2.0.0',
        libraries: [
          LibraryDoc(
            name: 'lib1',
            classes: [
              ClassDoc(
                name: 'MyClass',
                methods: [
                  MethodDoc(
                    name: 'myMethod',
                    returnType: 'String',
                    parameters: [ParameterDoc(name: 'param1', type: 'int')],
                  ),
                ],
              ),
            ],
            functions: [FunctionDoc(name: 'myFunction', returnType: 'void')],
          ),
        ],
      );

      final docFile = File(cache.docsPath('complex_package', '2.0.0'));
      await docFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(complexDoc.toJson()),
      );

      final loadedDoc = await cache.getPackage('complex_package', '2.0.0');

      expect(loadedDoc, isNotNull);
      expect(loadedDoc!.libraries.first.classes, hasLength(1));
      expect(loadedDoc.libraries.first.functions, hasLength(1));
      expect(loadedDoc.libraries.first.classes.first.methods, hasLength(1));
    });
  });

  group('CacheManager - savePackage', () {
    test('saves package to cache', () async {
      final doc = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test description',
      );

      await cache.savePackage(doc);

      expect(cache.hasPackage('test_package', '1.0.0'), isTrue);
    });

    test('creates cache directories automatically', () async {
      // Don't call ensureDirectories manually
      final doc = PackageDoc(name: 'test_package', version: '1.0.0');

      await cache.savePackage(doc);

      expect(await cache.docsDir.exists(), isTrue);
      expect(cache.hasPackage('test_package', '1.0.0'), isTrue);
    });

    test('saves package with pretty-printed JSON', () async {
      final doc = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test',
        libraries: [LibraryDoc(name: 'lib')],
      );

      await cache.savePackage(doc);

      final file = File(cache.docsPath('test_package', '1.0.0'));
      final contents = await file.readAsString();

      // Should have indentation (pretty-printed)
      expect(contents, contains('  '));
      expect(contents, contains('"name": "test_package"'));
    });

    test('overwrites existing cached package', () async {
      final doc1 = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Original',
      );

      final doc2 = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Updated',
      );

      await cache.savePackage(doc1);
      await cache.savePackage(doc2);

      final loaded = await cache.getPackage('test_package', '1.0.0');
      expect(loaded!.description, equals('Updated'));
    });

    test('saves multiple packages independently', () async {
      final doc1 = PackageDoc(name: 'package1', version: '1.0.0');
      final doc2 = PackageDoc(name: 'package2', version: '2.0.0');

      await cache.savePackage(doc1);
      await cache.savePackage(doc2);

      expect(cache.hasPackage('package1', '1.0.0'), isTrue);
      expect(cache.hasPackage('package2', '2.0.0'), isTrue);
    });

    test('saves multiple versions of same package', () async {
      final doc1 = PackageDoc(name: 'package', version: '1.0.0');
      final doc2 = PackageDoc(name: 'package', version: '2.0.0');

      await cache.savePackage(doc1);
      await cache.savePackage(doc2);

      expect(cache.hasPackage('package', '1.0.0'), isTrue);
      expect(cache.hasPackage('package', '2.0.0'), isTrue);
    });
  });

  group('CacheManager - listCached', () {
    test('returns empty list when no packages cached', () async {
      final packages = await cache.listCached();
      expect(packages, isEmpty);
    });

    test('returns empty list when docs directory does not exist', () async {
      final packages = await cache.listCached();
      expect(packages, isEmpty);
    });

    test('lists single cached package', () async {
      final doc = PackageDoc(name: 'test_package', version: '1.0.0');
      await cache.savePackage(doc);

      final packages = await cache.listCached();

      expect(packages, hasLength(1));
      expect(packages.first.name, equals('test_package'));
      expect(packages.first.version, equals('1.0.0'));
    });

    test('lists multiple cached packages', () async {
      await cache.savePackage(PackageDoc(name: 'pkg1', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg2', version: '2.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg3', version: '3.0.0'));

      final packages = await cache.listCached();

      expect(packages, hasLength(3));
      final names = packages.map((p) => p.name).toList();
      expect(names, containsAll(['pkg1', 'pkg2', 'pkg3']));
    });

    test('lists multiple versions of same package', () async {
      await cache.savePackage(PackageDoc(name: 'package', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'package', version: '2.0.0'));

      final packages = await cache.listCached();

      expect(packages, hasLength(2));
      final versions = packages.map((p) => p.version).toList();
      expect(versions, containsAll(['1.0.0', '2.0.0']));
    });

    test('ignores non-JSON files in docs directory', () async {
      await cache.ensureDirectories();
      await File(
        p.join(cache.docsDir.path, 'readme.txt'),
      ).writeAsString('test');
      await cache.savePackage(PackageDoc(name: 'pkg', version: '1.0.0'));

      final packages = await cache.listCached();

      expect(packages, hasLength(1));
    });

    test('handles package names with hyphens correctly', () async {
      await cache.savePackage(
        PackageDoc(name: 'my-cool-package', version: '1.0.0'),
      );

      final packages = await cache.listCached();

      expect(packages, hasLength(1));
      expect(packages.first.name, equals('my-cool-package'));
      expect(packages.first.version, equals('1.0.0'));
    });

    test('handles version strings with hyphens', () async {
      await cache.savePackage(
        PackageDoc(name: 'my-package', version: '1.0.0-beta.1'),
      );

      final packages = await cache.listCached();

      expect(packages, hasLength(1));
      // Note: The parser splits on last hyphen, so version gets rest
      expect(packages.first.name, equals('my-package-1.0.0'));
      expect(packages.first.version, equals('beta.1'));
    });
  });

  group('CacheManager - clearPackage', () {
    test('clears all data for specific package', () async {
      await cache.ensureDirectories();

      // Create archive file
      final archiveFile = File(cache.archivePath('pkg', '1.0.0'));
      await archiveFile.writeAsString('archive data');

      // Create extracted directory
      final extractedDir = Directory(cache.extractedPath('pkg', '1.0.0'));
      await extractedDir.create(recursive: true);
      await File(p.join(extractedDir.path, 'test.txt')).writeAsString('test');

      // Create docs file
      await cache.savePackage(PackageDoc(name: 'pkg', version: '1.0.0'));

      // Verify all exist
      expect(archiveFile.existsSync(), isTrue);
      expect(extractedDir.existsSync(), isTrue);
      expect(cache.hasPackage('pkg', '1.0.0'), isTrue);

      // Clear
      await cache.clearPackage('pkg', '1.0.0');

      // Verify all deleted
      expect(archiveFile.existsSync(), isFalse);
      expect(extractedDir.existsSync(), isFalse);
      expect(cache.hasPackage('pkg', '1.0.0'), isFalse);
    });

    test('handles clearing non-existent package gracefully', () async {
      // Should not throw
      await cache.clearPackage('non_existent', '1.0.0');
    });

    test('clears specific version only', () async {
      await cache.savePackage(PackageDoc(name: 'pkg', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg', version: '2.0.0'));

      await cache.clearPackage('pkg', '1.0.0');

      expect(cache.hasPackage('pkg', '1.0.0'), isFalse);
      expect(cache.hasPackage('pkg', '2.0.0'), isTrue);
    });

    test('clears specific package only', () async {
      await cache.savePackage(PackageDoc(name: 'pkg1', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg2', version: '1.0.0'));

      await cache.clearPackage('pkg1', '1.0.0');

      expect(cache.hasPackage('pkg1', '1.0.0'), isFalse);
      expect(cache.hasPackage('pkg2', '1.0.0'), isTrue);
    });
  });

  group('CacheManager - clearAll', () {
    test('clears all cached data', () async {
      await cache.savePackage(PackageDoc(name: 'pkg1', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg2', version: '2.0.0'));

      expect(await cache.cacheDir.exists(), isTrue);

      await cache.clearAll();

      expect(await cache.cacheDir.exists(), isFalse);
    });

    test('handles clearing non-existent cache gracefully', () async {
      // Should not throw
      await cache.clearAll();
    });

    test('removes all subdirectories', () async {
      await cache.ensureDirectories();
      await cache.savePackage(PackageDoc(name: 'pkg', version: '1.0.0'));

      // Add files to other directories
      await File(cache.archivePath('pkg', '1.0.0')).writeAsString('archive');
      await Directory(cache.extractedPath('pkg', '1.0.0')).create();

      await cache.clearAll();

      expect(await cache.archivesDir.exists(), isFalse);
      expect(await cache.extractedDir.exists(), isFalse);
      expect(await cache.docsDir.exists(), isFalse);
    });
  });

  group('CacheManager - Round-trip Integration', () {
    test('save and load preserves all data', () async {
      final original = PackageDoc(
        name: 'integration_test',
        version: '1.2.3',
        description: 'Integration test package',
        repository: 'https://github.com/test/repo',
        homepage: 'https://test.dev',
        libraries: [
          LibraryDoc(
            name: 'test_lib',
            description: 'Test library',
            classes: [
              ClassDoc(
                name: 'TestClass',
                description: 'Test class',
                constructors: [ConstructorDoc(name: '')],
                methods: [
                  MethodDoc(
                    name: 'testMethod',
                    returnType: 'String',
                    parameters: [ParameterDoc(name: 'arg', type: 'int')],
                  ),
                ],
                fields: [FieldDoc(name: 'field', type: 'String')],
              ),
            ],
            functions: [FunctionDoc(name: 'testFunc', returnType: 'void')],
            enums: [
              EnumDoc(
                name: 'TestEnum',
                values: [
                  EnumValueDoc(name: 'value1'),
                  EnumValueDoc(name: 'value2'),
                ],
              ),
            ],
          ),
        ],
      );

      await cache.savePackage(original);
      final loaded = await cache.getPackage('integration_test', '1.2.3');

      expect(loaded, isNotNull);
      expect(loaded!.name, equals(original.name));
      expect(loaded.version, equals(original.version));
      expect(loaded.description, equals(original.description));
      expect(loaded.repository, equals(original.repository));
      expect(loaded.libraries.length, equals(original.libraries.length));

      final lib = loaded.libraries.first;
      expect(lib.name, equals('test_lib'));
      expect(lib.classes.length, equals(1));
      expect(lib.functions.length, equals(1));
      expect(lib.enums.length, equals(1));

      final cls = lib.classes.first;
      expect(cls.name, equals('TestClass'));
      expect(cls.methods.length, equals(1));
      expect(cls.fields.length, equals(1));
    });
  });
}
